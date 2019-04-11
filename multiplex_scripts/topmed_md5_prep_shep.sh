batch_name="$1"
samples="$2"
batch_type="$3"
if  ((`find . -name '*.out' -size 0 | xargs ls | wc -l` == $samples)); then
	echo "$samples MD5_s were generated"
	echo `find . -name '*.out' -size 0 | xargs rm`
	fi
	if (( `(find . -name '*.out' | wc -l )`  == 0 )); then
	        echo "All outs have been erased will ensure Manifest contains correct number of samples"
	fi
	if  (( `cat *md5 | tee Manifest.txt | wc -l `  == $samples)); then
			echo "Manifest has been created succeffully, will now copy to designated area"
			echo `cat *md5 | tee Manifest.txt | wc -l - ../${batch_name}_md5`
			#echo `cp -p Manifest.txt  /stornext/snfs1/submissions/topmed/topmed-shared/batches/globus/$batch_name `
			echo cp Manifest.txt ../
			echo `scp Manifest.txt christis@hgsc-aspera1.hgsc.bcm.edu:/share/share/globusupload/submissions/$batch_type/$batch_name/`
			echo "Manifest has been copied, have a good day"
        else
	echo " ERROR. There are below 100 MD5s..."

        fi
  #error is that it is making the Manifest script but is not making the copy in the spot it is supposed to be made
