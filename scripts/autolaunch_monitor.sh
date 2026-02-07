#!/usr/bin/bash

# Seconds between checks
update_delay_sec=600

bsshprojectID='a7208a06-2a83-4ae8-90bc-6997889754f0'   # BSSH managed project (Workgroup)
icaprojectID='04c8fc29-089c-4571-b002-c81ccdce49d9'    # Clinical WES Project on ICA
apikey=$1          # ICA API key 
BSSHaccessToken='ac341df903eb4d08af3c2ef253ce4a9a' # BSSH token


# Loop until control-C'ed out
while : ; do
  clear

  # Get a list of all the autolaunched demultiplexing in the BSSH managed project
  ILMNANALYSES=$(icav2 projectdata list -k $apikey --project-id $bsshprojectID --parent-folder /ilmn-analyses/ -o json)
  echo "$ILMNANALYSES" > pdata.json
  APPS=($(echo "$ILMNANALYSES" | jq -r '.items[] | "\(.details.timeCreated)_\(.details.name)"' | sort -r))

 
  

    if [[ ${APPS[0]} =~ ^(.{20})_(.+)(_[a-f0-9]{6}_[a-f0-9]{6})(-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})$ ]];
    then 
      RUNNAME=${BASH_REMATCH[2]}
      FULLNAME=${BASH_REMATCH[2]}${BASH_REMATCH[3]}${BASH_REMATCH[4]}
      echo -n $RUNNAME
    else 
	echo "The analysis name doesn't follow the naming convention. Please check the analysis name format if it follows: <20characters>_<any_characters>_<hexadecimal>_<hexadecimal>-<UUID>" 
	continue; fi
    
    # Create the local folder for cached run data
    mkdir -p ./bssh_data/$RUNNAME

    # attempt to download the _manifest.json file
    if [ ! -f ./bssh_data/$RUNNAME/_manifest.json ]; then
      icav2 projectdata download -k $apikey --project-id $bsshprojectID /ilmn-analyses/$FULLNAME/_manifest.json ./bssh_data/$RUNNAME/ >> ./bssh_data/$RUNNAME/log
    fi
    
    # Check if the _manifest.json file was downloaded before proceeding
    if [ ! -f ./bssh_data/$RUNNAME/_manifest.json ]; then
      echo " | Run doesn't contain expected file: _manifest.json"
      continue;
    else
    
      # Get SampleSheet and fastq_list
      # attempt to download SampleSheet.csv file
      if [ ! -f ./bssh_data/$RUNNAME/SampleSheet.csv ]; then
        icav2 projectdata download -k $apikey --project-id $bsshprojectID /ilmn-analyses/$FULLNAME/output/Reports/SampleSheet.csv ./bssh_data/$RUNNAME/ >> ./bssh_data/$RUNNAME/log
      fi
      # attempt to download fastq_list.csv file
      if [ ! -f ./bssh_data/$RUNNAME/fastq_list.csv ]; then
        icav2 projectdata download -k $apikey --project-id $bsshprojectID /ilmn-analyses/$FULLNAME/output/Reports/fastq_list.csv ./bssh_data/$RUNNAME/ >> ./bssh_data/$RUNNAME/log
      fi
      # Check if the SampleSheet.csv file was downloaded before proceeding
      if [ ! -f ./bssh_data/$RUNNAME/SampleSheet.csv ]; then
        echo " | Run doesn't contain expected file: SampleSheet.csv"
        continue;
      fi
      # Check if the fastq_list.csv file was downloaded before proceeding
      if [ ! -f ./bssh_data/$RUNNAME/fastq_list.csv ]; then
        echo " | Run doesn't contain expected file: fastq_list.csv"
        continue;
      fi
    fi

    # Do not proceed further if RUN is marked as processing (avoids duplication)
    if [ -e bssh_data/$RUNNAME/processing ]; then echo ; continue; fi

    # Do not proceed further if RUN is marked as processed already
    # Not performed earlier in order to display the values for each run. Flow logic could be improved.
    if [ -e bssh_data/$RUNNAME/done ]; then echo ; continue; fi

    batchName=$(echo $(TZ='America/New_York' date +"%Y%m%d-%H%M%S"))
    echo " | PROCESSING $batchName"
    touch bssh_data/$RUNNAME/processing

    # Launch the analyses using a separate process with its own log
    {
    bash /env/illumina/autolaunch_process.sh $apikey $RUNNAME $FULLNAME $bsshprojectID $icaprojectID $batchName
    } 2>&1 | tee -a bssh_data/$RUNNAME/$batchName.log
   
    # Extracting anlaysis name
    analysis_name=$(grep '^reference' bssh_data/$RUNNAME/$batchName.log | cut -d' ' -f2- | sed 's/^[ \t]*//')
    
 
    # Mark RUN as processed
    touch bssh_data/$RUNNAME/done
  
  echo $(TZ='America/New_York' date +"%Y-%m-%d %H:%M:%S")
  echo "Waiting $update_delay_sec seconds before next update. Press any key to update immediately or control-C to stop monitoring."
  sleep 600

done
