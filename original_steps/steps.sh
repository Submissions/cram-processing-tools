sgenerate-topmed-md5-worklist $workbookz# Connect to:
#   cifs://hgsc-naf01-b.hgsc.bcm.edu/tcga/other-submissions/topmed-shared

#make new directorie

# Drag attachment (eg. TOPMed_THRV_batch03_2016-04-04.xlsx) into new created directory.





cd /stornext/snfs1/submissions/topmed
pushd topmed-shared

cd batches/globus/"filename"
 

workbook=$(ls -t TOPMed_*_batch??_????-??-??.xlsx | head -n1)
if [[ $workbook =~ ' ' ]]; then
    echo 'ERROR: There is a space in the name of the workbook!!!'
    echo 'These steps will FAIL!'
fi

batch_name=$(echo $workbook | sed -e s/^TOPMed_// -e s/.xlsx$//)
echo $batch_name
#mkdir batches/$batch_name
# made the directory earlier
#pasted it into the directory earlier
#mv $workbook batches/$batch_name/
#chmod -wx batches/$batch_name/$workbook

pushd batches/globus/$batch_name/
generate-topmed-copy-script $workbook
generate-topmed-md5-worklist $workbook
#chmod -wx $batch_name*

popd
popd

# Upload copy/rename script to ticket.

(
echo 'Update the RT ticket with the following:'
echo
echo "Attached is the copy script. You can also find it here:"
echo "/data/tcga/other-submissions/topmed-shared/batches/globus/$batch_name/$batch_name.sh"
echo "Moving on to MD5 and validation..."
)

# Execute md5-steps.
# need to do this once jobs are complete
#jobs completed
   
pushd md5-batches/$batch_name
#copy to md5
cp /stornext/snfs1/submissions/topmed/topmed-code/topmed_md5_prep.sh .
#then run, but specifiy the batch 
./topmed_md5_prep.sh $batch_name 100 THRV



""" #OLDWAY OF DOING IT#
(
pushd md5-batches/$batch_name
find . -name '*.out' -size 0 | xargs ls
find . -name '*.out' -size 0 | xargs rm
find . -name '*.out'
cat *md5 | tee Manifest.txt | wc -l
cat *md5 | tee Manifest.txt | wc -l - ../../topmed-shared/batches/globus/$batch_name/${batch_name}_md5
# CHECK: the first two numbers generated should match.
chmod -w Manifest.txt

cp -p Manifest.txt ../../topmed-shared/batches/globus/$batch_name/
)
"""


scp Manifest.txt christis@hgsc-aspera1.hgsc.bcm.edu:/share/share/globusupload/submissions/AFIB/$batch_name


# Upload Manifest file to ticket.

(
echo 'Update the RT ticket with the following:'
echo
echo "Attached is the Manifest.txt file. You can also find it here:"
echo "/data/tcga/other-submissions/topmed-shared/batches/globus/$batch_name/Manifest.txt"
echo "Moving on to validation..."
)

# Execute validation-steps.

pushd validation-batches/$batch_name/
(
echo $(ls run*/*.job  | wc -l) job
echo $(ls run*/*.err  | wc -l) err
echo $(ls run*/*.out  | wc -l) out
echo $(ls run*/*.time | wc -l) time
cat run*/*.out | uniq -c
)
# Should all be the same number.
popd
