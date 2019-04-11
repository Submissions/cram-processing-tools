cd /stornext/snfs1/submissions/topmed

# batch_name=$(
#     basename $(ls -d topmed-shared/batches/*_batch??_????-??-?? | tail -n 1)
# )
batch_name=$(ls -t topmed-shared/batches/globus/ | grep '_batch.._....-..-..' | head -n1)
echo $batch_name

mkdir -p validation-batches/${batch_name}/input
cat topmed-shared/batches/globus/${batch_name}/${batch_name}_md5 |
   sed 's/^msub-md5/msub-val/' |
   tee validation-batches/${batch_name}/${batch_name}_val |
   tail

pushd validation-batches/${batch_name}/input/

#creates symlinks to all the bams in the input directory
    ECHO=echo
    msub-val() { $ECHO ln -s "$2" "$1"; }
    . ../${batch_name}_val
    unset ECHO
    . ../${batch_name}_val

    cd ..
    ls input/NWD* | head -n5 | xargs -n1 echo submit-cram-validation  run_a
    # ls input/NWD* | head -n5 | xargs -n1 submit-validation run_a
    # ls input/NWD* | tail -n+6 | xargs -n1 submit-validation run_b
    ls input/NWD* | xargs -n1 submit-cram-validation  run_a proj-dm0019

popd
