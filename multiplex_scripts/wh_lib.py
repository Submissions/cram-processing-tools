import collections
import csv
import glob
import itertools
import locale
import operator
import os
import pprint
import re
import sys

try:
    import openpyxl
except ImportError:
    pass  # optional dependency, only used when parsing .xlsx files
try:
    import xlrd
except ImportError:
    pass  # optional dependency, only used when parsing .xls files
import yaml


locale.setlocale(locale.LC_ALL, 'en_US.UTF-8')


def select(collection, *items):
    return operator.itemgetter(*items)(collection)


def print_table(iterable):
    """Print out the finite input as a table. Each item in iterable must be an
    iterable with roughly the same number of items."""
    # Slurp the entire iterable.
    rows = list(iterable)
    # Compute column widths.
    col_widths = []
    for row in rows:
        for col_num, col_val in enumerate(row):
            col_len = len(str(col_val))
            if col_num < len(col_widths):
                col_widths[col_num] = max(col_widths[col_num], col_len)
            else:
                col_widths.append(col_len)
    # Format output.
    for row in rows:
        # Output all but last column in padded format.
        for col_val, col_width in list(zip(row, col_widths))[:-1]:
            col_str = str(col_val)
            if isinstance(col_val, int) and not isinstance(col_val, bool):
                sys.stdout.write(col_str.rjust(col_width))
            else:
                sys.stdout.write(col_str.ljust(col_width))
            sys.stdout.write(' | ')
        # Output the last column as-is.
        sys.stdout.write(str(row[-1]))
        # Add the newline.
        sys.stdout.write('\n')


def yp(data, stream=sys.stdout):
    """Pretty print as YAML."""
    yd(data, stream)


def yf(data):
    """Format as pretty YAML"""
    return yd(data)


def yd(data, stream=None):
    return yaml.safe_dump(devolve(data), stream, default_flow_style=False)
    # TODO: devolve is not self-referential safe


def fetch_tsv_header(file_path):
    with open(file_path) as fin:
        reader = csv.Reader(fin, delimiter='\t')
        return next(reader)


def parse_tsv_file(file_path, cls_or_fcn=None, fieldnames=None):
    """cls_or_fcn must construct an object from a dict."""
    return list(iterate_tsv_file(file_path, cls_or_fcn, fieldnames))


def iterate_tsv_file(file_path, cls_or_fcn=None, fieldnames=None):
    """cls_or_fcn must construct an object from a dict."""
    with open(file_path) as fin:
        for r in iterate_tsv_stream(fin, cls_or_fcn, fieldnames):
            yield r


def iterate_tsv_stream(stream, cls_or_fcn=None, fieldnames=None):
    """cls_or_fcn must construct an object from a dict."""
    cls_or_fcn = cls_or_fcn or Record
    reader = csv.DictReader(stream, fieldnames=fieldnames, delimiter='\t')
    for it in reader:
        yield cls_or_fcn(it)


def default_filter(record):
    return any(record.values())


def parse_excel_records(file_path,
                        cls_or_fcn=None,
                        sheet_name=None,
                        filter=default_filter):
    extension = os.path.splitext(file_path)[1]
    if extension == '.xlsx':
        parse_result = parse_xlsx_records(file_path, cls_or_fcn, sheet_name)
    elif extension == '.xls':
        parse_result = parse_xls_records(file_path, cls_or_fcn, sheet_name)
    #elif extension == '.tsv':
    #    parse_result = parse_tsv_file(file_path, cls_or_fcn,fieldnames)
    else:
        raise NotImplementedError(file_path)
    return [record for record in parse_result if filter(record)]


def parse_xlsx_records(file_path, cls_or_fcn, sheet_name):
    fcn = get_pair_constructor(cls_or_fcn)
    wb = openpyxl.load_workbook(file_path, data_only=True)
    if sheet_name:
        ws = wb.get_sheet_by_name(sheet_name)
    else:
        ws = wb.worksheets[0]
    rows = iter(ws.rows)
    header = tuple(normalize_field_name(c.value) for c in next(rows))
    return [fcn(header, (c.value for c in row)) for row in rows]


def parse_xls_records(file_path, cls_or_fcn, sheet_name):
    # TODO: use sheet_name
    fcn = get_pair_constructor(cls_or_fcn)
    wb = xlrd.open_workbook(file_path)
    ws = wb.sheet_by_index(0)
    header = tuple(normalize_field_name(c) for c in ws.row_values(0))
    return [fcn(header, ws.row_values(i)) for i in range(1, ws.nrows)]


def get_pair_constructor(cls_or_fcn):
    """Return a callable that constructs an object from a header, data pair."""
    if not cls_or_fcn:
        return Record.from_pair
    elif isinstance(cls_or_fcn, type):
        return cls_or_fcn.from_pair
    else:
        return cls_or_fcn


class Record(collections.MutableMapping):
    def __init__(self, mapping=None, **kwds):
        if mapping:
            if isinstance(mapping, collections.Mapping):
                gen = mapping.items()
            else:
                gen = mapping
            for k, v in gen:
                self.__dict__[normalize_field_name(k)] = normalize_value(v)
        for k, v in kwds.items():
            self.__dict__[normalize_field_name(k)] = normalize_value(v)

    @classmethod
    def from_pair(cls, header, data):
        """Alternate constructor"""
        return cls(zip(header, data))

    def __repr__(self):
        return '%s(%r)' % (self.__class__.__name__, self.__dict__)
        # TODO: Should I use self.mapping here?

    def __getitem__(self, key):
        return self.mapping[key]

    def __setitem__(self, key, value):
        self.mapping[key] = value

    def __delitem__(self, key):
        del self.mapping[key]

    # TODO: Is this inherited from collections.MutableMapping?
    def __iter__(self):
        return iter(self.mapping)

    # TODO: Is this inherited from collections.MutableMapping?
    def __len__(self):
        return len(self.mapping)

    @property
    def mapping(self):
        return self.__dict__

    @property
    def attributes(self):
        return self.mapping.keys()

    def pp(self):
        pprint.pprint(self.to_dict())

    def to_dict(self):
        return devolve(self)


def normalize_field_name(field_name):
    """lowercase with underscores, etc"""
    result = field_name
    if result.endswith('?'):
        result = result[:-1]
        if not result.startswith('is_'):
            result = 'is_' + result
    result = result.strip().lower().replace(' ', '_').replace(
        '-', '_').replace('/', '_').replace('?', '_').replace('%', 'pct')
    return result


def normalize_value(value):
    """Convert empty string to None"""
    if value == '':
        value = None
    return value


def devolve(data):
    """Recursively convert to just JSON-compatible types."""
    # TODO: possible infinite recursion
    is_string = isinstance(data, str)
    is_iterable = isinstance(data, collections.Iterable)
    is_mapping = isinstance(data, collections.Mapping)
    is_record = isinstance(data, Record)
    if is_record:
        result = devolve(data.__dict__)
    elif is_mapping:
        result = {k: devolve(v) for k, v in data.items()}
    elif is_iterable and not is_string:
        result = [devolve(it) for it in data]
    elif hasattr(data, '__dict__'):
        result = data.__dict__
    else:
        result = data
    return result


def multiplicities(iterable):
    """Count the number of singletons, the number of duplicates, etc.
    Returns a collections.Counter instance."""
    return collections.Counter(collections.Counter(iterable).values())


def val_or_none_key(getter_fcn):
    """Wraps getter_fcn, returning a key that is a tuple of (0 or 1, val) where
    val=getter_fcn(obj), and the int is 0 if val is None."""
    def result_key_fcn(obj):
        val = getter_fcn(obj)
        n = 0 if val is None else 1
        return n, val
    return result_key_fcn


def count(iterable, n=None,
          primary_reverse=True,
          secondary_reverse=False,
          primary_key=operator.itemgetter(1),
          secondary_key=val_or_none_key(operator.itemgetter(0))
          ):
    """Wraps collections.Counter. Counts, sorts the result, and takes the
    first n. The primary sorting criteria is the count; the secondary sorting
    criteria is the value. The default sort is descending by count and
    ascending by value."""
    result = sorted(collections.Counter(iterable).items(),
                    key=secondary_key, reverse=secondary_reverse)
    result.sort(key=primary_key, reverse=primary_reverse)
    return result[:n]


class MinMax(object):
    def __init__(self, min_start=None, max_start=None, count_start=0):
        self.count = count_start
        self.min = min_start
        self.max = max_start

    def add(self, value):
        self.count += 1
        if self.min is None or self.min > value:
            self.min = value
        if self.max is None or self.max < value:
            self.max = value

    def __repr__(self):
        return '%s(%r, %r)' % (self.__class__.__name__, self.min, self.max)


def slice_by_value(sequence, start=None, end=None, step=1):
    """Returns the earliest slice of the sequence bounded by the
    start and end values. Omitted optional parameters work as expected
    for slicing.

    slice_by_value('hello there world', 'o', 'w', 2) -> 'otee'
    """
    i_start = i_end = None
    if start is not None:
        i_start = sequence.index(start)
    if end is not None:
        i_end = sequence.index(end)
    return sequence[i_start:i_end:step]


def update_subset(record, fields, *source_records, **kwds):
    """Given a destination record, a sequence of fields, and source
    for each field, copy over the first value found in the source records.
    The argument for fields must be an iterable where each item is either a
    string or a pair of strings. If it is a pair of strings, they name
    the destination and source field names. If keyword argument "required"
    is True and any of the fields are  missing from the source records,
    then a KeyError is raised."""
    required = kwds.pop('required', True)
    assert not kwds, 'Only "required" keyword supported'
    for field in fields:
        if isinstance(field, str):
            dst_name = src_name = field
        else:
            dst_name, src_name = field
            assert isinstance(dst_name, str)
            assert isinstance(src_name, str)
        value = fetch(src_name, *source_records, required=required)
        # TODO: assert value?
        if value is not None:
            setattr(record, dst_name, value)


def fetch(field, *source_records, **kwds):
    """Return the value from the first record in the arguments that
    contains the specified field. If no record in the chain contains
    that field, return the default value. The default value is specified
    by the "default" keyword argument or None. If keyword argument
    "required" is True and any of the fields are  missing from the source
    records, then a KeyError is raised."""
    default = kwds.pop('default', None)
    required = kwds.pop('required', False)
    assert not kwds, 'Only "default" and "required" keyword supported'
    for record in source_records:
        if hasattr(record, field):
            return getattr(record, field)
    # Must use default.
    if required:
        raise KeyError(field)
    return default


def replace_fields(field_list, *pairs):
    """Given a list of field names and one or more pairs,
    replace each item named in a pair by the pair.

    fl = 'one two three'.split()
    replace_fields(fl, ('two', 'spam'))
    # ['one', ('two', 'spam'), 'three']
    """
    result = list(field_list)
    for field_name, source in pairs:
        index = field_list.index(field_name)
        result[index] = field_name, source
    return result


def rekey_map(mapping, replacements):
    """Given an iterable of destination/source pairs in replacements,
    create a new dict that is the same as the original except for the
    new key names."""
    result = dict(mapping)
    for dst, src in replacements:
        value = result[src]
        result[dst] = value
        del result[src]
    return result


class TsvDialect(csv.Dialect):
    """Standard Unix-style TSV format.
    Also compatible with MAGE-TAB spec v1.0.
    See MAGE-TABv1.0.pdf section 3.1.6
    http://www.mged.org/mage-tab/MAGE-TABv1.0.pdf
    http://www.mged.org/mage-tab/"""
    delimiter = '\t'
    doublequote = False
    escapechar = '\\'
    lineterminator = '\n'
    quotechar = '"'
    quoting = csv.QUOTE_MINIMAL
    skipinitialspace = False
