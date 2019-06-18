#!/bin/bash

PM_PATH=$1
SUB_ROOT=$2
SUB_PATH=$3


# Path to accept_batch script
ACCEPT_BATCH_PATH=/hgsc_software/submissions/bin/accept_batch

## Run accept_batch
$ACCEPT_BATCH_PATH $1
if [ $? != 0 ]; then
    echo "WARNING: accept_batch encountered errors."
    echo "ERROR: Stopping the pipeline."
    exit 1
fi

pushd .

# Change to working directory
cd $SUB_ROOT/$SUB_PATH

# Copy TSV to file groups submissions directory
TSV_FILE=$(find $PM_PATH -name '*.tsv')
cp $TSV_FILE .


# Assign workbook and check that the name is valid
workbook=$(ls -t *_batch???_mplx.tsv | head -n1)
if [[ $workbook =~ ' ' ]]; then
    echo 'ERROR: There is a space in the name of the workbook!!!'
    echo 'These steps will FAIL!'
    exit 1
fi

# Assign batch name
batch_name=$(echo $workbook | sed -e s/_mplx.tsv$//)

# Run scripts to generate the copy script and md5_worklist
stornext_path=/Users/marcelat/Projects/madeup
$stornext_path/generate-topmed-copy-script-tsv $workbook
echo "Generated copy script"
$stornext_path/generate-topmed-md5-worklist-tsv $workbook
echo "Generated md5_worklist script"

# Run validation prep steps
# Create input directory
mkdir validation/input
echo "Created input directory under validation directory"
sed 's/^msub-md5/msub-val/' ${batch_name}_md5 > validation/${batch_name}_val
echo "Created ${batch_name}_val under validation/"

# Create symlinks to all the bams in the input directory
cd validation/input
ECHO=echo
msub-val() { $ECHO ln -s "$2" "$1"; }
. ../${batch_name}_val
unset ECHO
. ../${batch_name}_val
echo "Successfully created symlinks"

popd

# If everything is successful, temporarily create file
touch topmed_status_good