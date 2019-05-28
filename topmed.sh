TOPMED Steps: Initializing:

under /users/rajendra/.config make shepherd.yaml
cat > 
sub_root: /groups/submissions/metadata/v1/topmed/
asp_root: /aspera/share/globusupload/submissions/


------In the Copy Node (tmux):-------
(in the home directory)
1) Check space on Aspera: df -h /aspera/share/globusupload
2) Run 'accept_batch' and the path jennifer gives you
3) In groups submissions directory (/groups/submissions/metadata/v1/topmed/topmed/YR3/harvard/01/{created directory}), copy the tsv from the project manager location
4) Run the workbook function:

workbook=$(ls -t *_batch???_mplx.tsv | head -n1)
if [[ $workbook =~ ' ' ]]; then
    echo 'ERROR: There is a space in the name of the workbook!!!'
    echo 'These steps will FAIL!'
fi

batch_name=$(echo $workbook | sed -e s/_mplx.tsv$//)
echo $batch_name

5) Run the scripts used to generate: (i) copy script, (ii) md5_worklist
/stornext/snfs1/submissions/topmed/topmed-code/topmed_multiplex_code/generate-topmed-copy-script-tsv $workbook
/stornext/snfs1/submissions/topmed/topmed-code/topmed_multiplex_code/generate-topmed-md5-worklist-tsv $workbook


6) Run the following validation prep steps:
mkdir -p validation/input
cat ${batch_name}_md5 | sed 's/^msub-md5/msub-val/' | tee validation/${batch_name}_val | tail

pushd validation/input/

#creates symlinks to all the bams in the input directory
ECHO=echo
msub-val() { $ECHO ln -s "$2" "$1"; }
. ../${batch_name}_val
unset ECHO
. ../${batch_name}_val

11) Copy the crams
### run the copy script (be sure to include the first part of the destination path)
./{copy_script}.sh /aspera/share/globusupload/submissions

13) Convert the md5s into a manifest and copy to aspera using the copy script ### you may need to copy the script into your working directory
cp /stornext/snfs1/submissions/topmed/topmed-code/topmed_md5_prep_shep.sh .
cd md5/
../topmed_md5_prep_shep.sh $batch_name {no. of samples} {Cohort_name} 


------In the Login Node (tmux):---------
7) cd into working directory (/groups/submissions/metadata/v1/topmed/topmed/YR3/harvard/01/{created directory})
8) 'md5' directory should already exist
### redefine batch name as necessary

9) Submit the md5 jobs to the cluster:
echo submit-md5-jobs "$batch_name"_md5 md5
submit-md5-jobs "$batch_name"_md5 md5/ proj-dm0021

10) Run the validation
cd .. ###into the validation directory, make sure you have a copy of the submit_cram_validation script ### run_a is the directory name
ls input/NWD* | head -n5 | xargs -n1 echo ../submit-cram-validation_phase5 run_a
ls input/NWD* | xargs -n1 submit-cram-validation_phase5 run_a

12) Check the validation, once complete
