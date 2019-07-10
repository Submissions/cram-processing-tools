#!/bin/bash

PM_CODE=$1
PM_PATH=$2

SUB_ROOT=/groups/submissions/metadata/v1/topmed
SUB_PATH=${PM_PATH:56}

ASP_ROOT=/aspera/share/globusupload/submissions

#########
# Usage #
#########
usage() {
   err "usage: $(basename "$0") PM_CODE PM_PATH"
   err "    Run TOPmed automation for validation and copy steps."
   err "    PM_CODE: code provided by the project manager"
   err "    PM_PATH: path provided by the project manager"
   err
   exit 1
} >&2

err() { echo "$@" >&2; }

if [[ $# -ne 2 ]]; then
   usage
fi

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
# tmux new -s topmed-copy -d
# tmux_session_exist
tmux new -s topmed-login -d
tmux_session_exist
echo "Created topmed-login session"


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

# Change to working directory
cd $SUB_ROOT/$SUB_PATH

# Assign workbook
workbook=$(ls -t *_batch???_mplx.tsv | head -n1)

# Assign batch name
batch_name=$(echo $workbook | sed -e s/_mplx.tsv$//)

# Run scripts to generate the copy script and md5_worklist
stornext_path=/stornext/snfs1/submissions/topmed/topmed-code/topmed_multiplex_code
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

##################################
# Submit md5 jobs to the cluster #
##################################

submit_md5_jobs=/hgsc_software/submissions/noarch/apps/topmed-code/submit-md5-jobs
md5_file_path="$batch_name"_md5
tmux send-keys -t topmed-login "ssh sug-login4" C-m
tmux send-keys -t topmed-login "cd $SUB_ROOT/$SUB_PATH" C-m
# This is assuming user doesnt have to enter a password
# Should prob clarify, it's easier
tmux send-keys -t topmed-login "$submit_md5_jobs $md5_file_path md5/ $PM_CODE" C-m

# Run the validation
submit-cram-validation_phase5=/hgsc_software/groups/submissions/metadata/v1/topmed/topmed/YR3/scripts_mr/submit-cram-validation_phase5
tmux send-keys -t topmed-login "cd validation/" C-m
tmux send-keys -t topmed-login "ls input/NWD* | xargs -n1 $submit-cram-validation_phase5 run_a" C-m

echo "Validation is running, check validation in tmux session topmed-login once completed!"