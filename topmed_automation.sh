#!/bin/bash

PM_CODE=$1
PM_PATH=$2

SUB_ROOT=/groups/submissions/metadata/v1/topmed
SUB_PATH=${PM_PATH:35}

ASP_ROOT=/aspera/share/globusupload/submissions
###############
# Function(s) #
###############
tmux_session_exist () {
    if [ $? != 0 ]; then
        echo "ERROR: tmux session already exist."
        echo "Make sure to exit previous sessions before continuing"
        exit 1
    fi
}


#########
# Setup #
#########

# TODO: Aspera space issue.
# Remind user?

# Check if shepherd config file exist

CONFIG_FILE=/users/$USER/.config/shepherd.yaml

if [ ! -f $CONFIG_FILE ]; then
    cat << EOF > $CONFIG_FILE
sub_root: $SUB_ROOT
asp_root: $ASP_ROOT
EOF
fi

# Check if tmux sessions exist
tmux new -s topmed-copy -d
tmux_session_exist
tmux new -s topmed-login -d
tmux_session_exist


#########################################
# Run accept_batch script from Shepherd #
#########################################

ACCEPT_BATCH_PATH=/hgsc_software/submissions/bin/accept_batch

$ACCEPT_BATCH_PATH $PM_PATH
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