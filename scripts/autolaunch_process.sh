#!/usr/bin/bash

# Requires the CLI_root folder with the .CLI_root.txt files in the same directory as this script
# .CLI_root scripts should not include "icav2" because it need to be used with specific APIkey in order to work outside of Bench
# Custom sections are called [PCH_customN], where N is optionally used to specify parallelization
# ARGS  1: apikey, 2: runname, 3: fullname, 4: bsshPID, 5: icaPID, 6: batchname

apikey=$1
runname=$2
fullname=$3
bsshprojectID=$4
icaprojectID=$5
batchName=$6

# echo $1 $2 $3 $4 $5 $6   #debug
# echo apikey=$apikey runname=$runname fullname=$fullname bsshPID=$bsshprojectID icaPID=$icaprojectID batch=$batchName   #debug

myfile="bssh_data/$runname/SampleSheet.csv"


# Loop over the number of custom pipeline sections in the SampleSheet
while read myline ; do
  SAMPLE=(); CLIROOT=();
  # Parse the sampleID and CLI_root values in the section
  while read LINE; do
    IFS=","; splitLINE=($LINE); unset IFS;
    SAMPLE+=(${splitLINE[0]})
    CLIROOT+=(${splitLINE[1]})
  done < <(tail --lines=+$myline $myfile | sed -n '/^\[PCH_custom/,/^\[/p' | grep -v "\[")
  unset SAMPLE[0]; unset CLIROOT[0];
  CLICALLS=($(for C in "${CLIROOT[@]}"; do echo "${C}"; done | sort -u))
  # assign samples to each CLI_root by using an associative array
  declare -A aCLISAMPLES
  aCLISAMPLES=()
  for i in "${!SAMPLE[@]}"; do
    # Opprotunity to list results of the parsing
    echo "   $i ${SAMPLE[$i]} ${CLIROOT[$i] ${DESC[$i]}}"
    aCLISAMPLES[${CLIROOT[$i]}]+="${SAMPLE[$i]} "
  done
  for x in "${!aCLISAMPLES[@]}"; do printf "[%s]=%s\n" "$x" "${aCLISAMPLES[$x]}" ; done
done < <(grep -n "\[PCH_custom" $myfile | cut -d':' -f1)

# Parse the FASTQ List
SAMPLE=(); FQR1=(); FQR2=();
{
read  # skips the header
while read LINE; do
  # split line by comma
  IFS=","; splitLINE=($LINE); unset IFS;
  SAMPLE+=(${splitLINE[1]})
  FQR1+=($(basename ${splitLINE[4]}))
  FQR2+=($(basename ${splitLINE[5]}))
done
} < bssh_data/$runname/fastq_list.csv

# Store FASTQ data in associative array
declare -A aSAMPLEFQ
aSAMPLEFQ=()
for i in "${!SAMPLE[@]}"; do
  aSAMPLEFQ[${SAMPLE[$i]}]+="${FQR1[$i]} ${FQR2[$i]} "
done
for x in "${!aSAMPLEFQ[@]}"; do printf "[%s]=%s\n" "$x" "${aSAMPLEFQ[$x]}" ; done

# Get FASTQ IDs
declare -A aFQIDs
aFQIDs=()
while read line ; do
  aFQIDs[$(echo ${line%$'\t'*} | xargs)]=$(echo ${line#*$'\t'} | xargs)
done < <(icav2 -k $apikey projectdata list --project-id $bsshprojectID /ilmn-analyses/$fullname/output/Samples/* | grep fastq.gz | grep -v Undetermined | sort | cut -d$'\t' -f1,4)
for x in "${!aFQIDs[@]}"; do printf "[%s]=%s\n" "$x" "${aFQIDs[$x]}" ; done

#Get samplesheet ID
while read line; do   if [[ "$line" == *"SampleSheet.csv"* ]]; then     sampleSheetID=$(echo "$line" | grep -o 'fil\.[a-z0-9]*');   fi; done < <(icav2 -k $apikey projectdata list --project-id $bsshprojectID /ilmn-analyses/$fullname/logs/Reports/SampleSheet.csv |  cut -d$'\t' -f1,4)

#Link samplesheet file
icav2 -k $apikey projectdata link --source-project-id $bsshprojectID --project-id $icaprojectID $sampleSheetID
echo "Linking samplesheet complete"

sleep 60

# Link files
for x in "${!aFQIDs[@]}"; do
  echo "linking $x using ${aFQIDs[$x]}"
  icav2 -k $apikey projectdata link --source-project-id $bsshprojectID --project-id $icaprojectID ${aFQIDs[$x]}
done
echo "Linking complete"

sleep 300

# Loop over CLI_root values
for CLIr in "${!aCLISAMPLES[@]}"; do
  printf "[%s]=%s\n" "$CLIr" "${aCLISAMPLES[$CLIr]}"
  fqids=""  # initialize file ID string
  # Loop over Samples to process
  SAMPs=( ${aCLISAMPLES[$CLIr]} )
  for SAMP in "${SAMPs[@]}"; do
    FQs=( ${aSAMPLEFQ[$SAMP]} )
    echo "  ${FQs[@]}"
    # Loop over FASTQs to generate ID string
    for FQ in "${FQs[@]}"; do
      echo "    $FQ: ${aFQIDs[$FQ]}"
      fqids+=" ${aFQIDs[$FQ]}"
    done
  done
  # Read the CLI root command
  cliroot=$(< CLI_root/$CLIr.CLI_root.txt)
  # format the fastqid list
  fqstring=$(echo $fqids | xargs | tr -s ' ' ',')
  # generate the command
  #get runname from samplesheet
  RunName=$(grep "RunName" "$myfile" | cut -d',' -f2)

  printf -v user_ref "%s-%s\n" $RunName $batchName 

  cliCMD="$cliroot$fqstring --input sample_sheet:$sampleSheetID --user-reference $user_ref"
  #cliCMD="$cliroot$fqstring --user-reference $user_ref --input sample_sheet:fil.c7050cdd4f1e42d7f6da08dcf91cc2ee"
  echo "icav2 -k <apikey> $cliCMD"
  # CLI launch
  eval "icav2 -k '$apikey' $cliCMD"
  sleep 5  # wait between individual launches of the pipelines
  echo
  echo
done
