cd /stornext/snfs1/submissions/topmed

# basename $(ls -d topmed-shared/batches/*_batch??_????-??-?? | tail -n 1)
batch_name=$(ls -t topmed-shared/batches/globus/ | grep '_batch.._....-..-..' | head -n1)
echo $batch_name
mkdir md5-batches/"$batch_name"
ll md5-batches/
echo submit-md5-jobs topmed-shared/batches/globus/"$batch_name"/"$batch_name"_md5 md5-batches/"$batch_name"
submit-md5-jobs topmed-shared/batches/globus/"$batch_name"/"$batch_name"_md5 md5-batches/"$batch_name"
