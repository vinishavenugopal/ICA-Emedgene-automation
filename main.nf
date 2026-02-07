#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

// -------------------------
// PARAMETERS
// -------------------------
params.poll_interval_sec = 3600  // how often to check BaseSpace
params.bssh_project_id   = 'a7208a06-2a83-4ae8-90bc-6997889754f0'
params.ica_project_id    = '04c8fc29-089c-4571-b002-c81ccdce49d9'
params.script_dir        = './scripts'
params.output_dir        = './results'

// -------------------------
// ENVIRONMENT VARIABLES
// -------------------------
env.ICA_API_KEY       = "${System.getenv('ICA_API_KEY')}"
env.BSSH_ACCESS_TOKEN = "${System.getenv('BSSH_ACCESS_TOKEN')}"
env.EMG_USERNAME      = "${System.getenv('EMG_USERNAME')}"
env.EMG_PASSWORD      = "${System.getenv('EMG_PASSWORD')}"

// -------------------------
// PROCESS: Monitor BaseSpace for new runs
// -------------------------
process MonitorBaseSpace {
    publishDir "${params.output_dir}/logs", mode: 'copy'

    output:
    path "new_runs.txt" into new_runs_ch

    script:
    """
    echo "Monitoring BaseSpace for new runs..."
    bash ${params.script_dir}/autolaunch_monitor.sh \$ICA_API_KEY > new_runs.txt
    """
}

// -------------------------
// PROCESS: Launch ICA workflows
// -------------------------
process RunICA {
    publishDir "${params.output_dir}/ica_outputs", mode: 'copy'

    input:
    path run_info from new_runs_ch

    output:
    path "ica_results.txt" into ica_results_ch

    script:
    """
    while read RUNNAME FULLNAME; do
      echo "Launching ICA workflow for \$RUNNAME"
      bash ${params.script_dir}/autolaunch_process.sh \
        \$ICA_API_KEY \$RUNNAME \$FULLNAME \
        ${params.bssh_project_id} ${params.ica_project_id} \$(date +%Y%m%d-%H%M%S)
    done < \$run_info
    echo "ICA processing complete" > ica_results.txt
    """
}

// -------------------------
// PROCESS: Push results to Emedgene
// -------------------------
process PushToEmedgene {
    publishDir "${params.output_dir}/emedgene_uploads", mode: 'copy'

    input:
    path ica_output from ica_results_ch

    script:
    """
    echo "Uploading ICA results to Emedgene..."
    python3 ${params.script_dir}/batchuploademg.py \
        -s /path/to/SampleSheet.csv \
        -r /path/to/ICA_run_folder
    echo "Emedgene upload complete" > upload_status.txt
    """
}

// Workflow definition
workflow {
    MonitorBaseSpace | RunICA | PushToEmedgene
}

