#!/bin/bash

# User needs to manually check space in Aspera before running script.
PM_PATH=$1
# The /topmed/YR3/ portion of the path
SUB_ROOT=/groups/submissions/metadata/v1/topmed/
SUB_PATH=${PM_PATH:35}

# Check if shepherd config exist, if not create 
CONFIG_FILE=~/.config/shepherd.yaml

if [ ! -f $CONFIG_FILE ]; then
    cat << EOF > $CONFIG_FILE
sub_root: /groups/submissions/metadata/v1/topmed/
asp_root: /aspera/share/globusupload/submissions/
EOF
fi

# if '/hgsc_software/submissions/bin' not in path
# temporarily add it
ACCEPT_BATCH_PATH=/hgsc_software/submissions/bin
[[ ":$PATH:" != *":$ACCEPT_BATCH_PATH:"* ]] && PATH="$ACCEPT_BATCH_PATH:${PATH}"


## Run accept_batch
accept_batch $1
if [ $? != 0 ]; then
    echo "WARNING: accept_batch encountered errors."
    echo "ERROR: Stopping the pipeline."
    exit 1
fi

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
fi

# Assign batch name
batch_name=$(echo $workbook | sed -e s/_mplx.tsv$//)

# Run scripts to generate the copy script and md5_worklist
stornext_path=/stornext/snfs1/submissions/topmed/topmed-code/topmed_multiplex_code/
[[ ":$PATH:" != *":$stornext_path:"* ]] && PATH="$stornext_path:${PATH}"
generate-topmed-copy-script-tsv $workbook
echo "Generated copy script"
generate-topmed-md5-worklist-tsv $workbook
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

