# ICA → Emedgene Automation Pipeline

![Nextflow](https://img.shields.io/badge/Built%20With-Nextflow-brightgreen)
![Python](https://img.shields.io/badge/Python-3.8%2B-blue)
![Bash](https://img.shields.io/badge/Bash-Automation-lightgrey)
![Status](https://img.shields.io/badge/Status-Production%20Ready-success)

---

## 🚀 Overview

This repository hosts a **Nextflow-based pipeline** that automates genomic analysis and reporting across three connected systems:

1. **Illumina BaseSpace / BSSH** – monitors for new sequencing analyses.  
2. **Illumina Connected Analytics (ICA)** – runs the Hemline enrichment secondary analysis workflow.  
3. **Emedgene** – uploads resulting variant data through the API for tertiary interpretation.

All orchestration, scheduling, and error handling are handled by **Nextflow**, ensuring reproducibility and traceability across runs.

---

## 🔄 Workflow Summary

### Text Diagram

         ┌────────────────────────┐
         │   Illumina BaseSpace   │
         │ (BSSH-managed project) │
         └──────────┬─────────────┘
                    │ Detect new analyses
                    ▼
          ┌───────────────────────┐
          │ autolaunch_monitor.sh │
          │  (runs every hour)    │
          └──────────┬────────────┘
                    │ Launch ICA job
                    ▼
          ┌───────────────────────┐
          │ autolaunch_process.sh │
          │  (link & run ICA)     │
          └──────────┬────────────┘
                    │ ICA results ready
                    ▼
         ┌────────────────────────┐
         │   batchuploademg.py    │
         │ (Upload to Emedgene)   │
         └──────────┬─────────────┘
                    │
                    ▼
          ┌───────────────────────┐
          │   Emedgene Platform   │
          │ (Case ingestion API)  │
          └───────────────────────┘


### Mermaid Diagram (renders on GitHub)

```mermaid
flowchart TD
    A[Illumina BaseSpace (BSSH)] --> B[autolaunch_monitor.sh<br/>Detect new analyses]
    B --> C[autolaunch_process.sh<br/>Launch ICA secondary workflow]
    C --> D[ICA Output Results]
    D --> E[batchuploademg.py<br/>Upload to Emedgene]
    E --> F[Emedgene Platform<br/>(Case ingestion & interpretation)]

📁 Repository Structure
ica-emedgene-automation/
├── main.nf               # Nextflow pipeline definition
├── nextflow.config       # Default configuration
├── configs/              # Dev/Prod configuration profiles
│   ├── dev.config
│   └── prod.config
├── scripts/              # Automation scripts
│   ├── autolaunch_monitor.sh
│   ├── autolaunch_process.sh
│   ├── batchuploademg.py
│   └── CLI_root/
│       ├── GermlineEnrichment.CLI_root.txt
│       └── ...
├── results/              # Pipeline outputs & logs
└── data/                 # Optional sample/test data

🧩 Workflow Components

Step	Script	Description
1. Monitor BaseSpace	autolaunch_monitor.sh	Detects new BSSH analyses and downloads manifests.
2. Run ICA Pipeline	autolaunch_process.sh	Links FASTQs and launches the Hemline enrichment workflow on ICA.
3. Upload to Emedgene	batchuploademg.py	Builds and uploads batch cases to Emedgene using API authentication.

⚙️ Configuration
Environment Variables

Before running, export the following environment variables:
export ICA_API_KEY="your_ica_api_key"
export BSSH_ACCESS_TOKEN="your_bssh_token"
export EMG_USERNAME="your_email@example.com"
export EMG_PASSWORD="your_password"

nextflow.config

Default parameters and runtime options are defined in nextflow.config:
params {
  bssh_project_id   = 'a7208a06-2a83-4ae8-90bc-6997889754f0'
  ica_project_id    = '04c8fc29-089c-4571-b002-c81ccdce49d9'
  poll_interval_sec = 3600
  output_dir        = './results'
}

process {
  executor = 'local'
  cpus = 4
  memory = '8 GB'
  errorStrategy = 'retry'
  maxRetries = 2
}

Override with a specific environment config if needed:
nextflow run main.nf -c configs/prod.config -resume

🧠 Usage
Run Once
nextflow run main.nf -resume

Run Continuously (via cron)

To check BaseSpace every hour:
*/60 * * * * cd /path/to/ica-emedgene-automation && nextflow run main.nf -resume

Switch Profiles
nextflow run main.nf -c configs/dev.config -resume

📊 Outputs
Directory	Description
results/logs/	Monitoring and ICA job logs
results/ica_outputs/	ICA secondary analysis results
results/emedgene_uploads/	Upload confirmations & logs
results/report.html	Nextflow execution summary
results/timeline.html	Interactive process timeline

🧱 Requirements
Tool	Minimum Version	Purpose
Nextflow	≥ 23.04	Workflow orchestration
Python	≥ 3.8	Emedgene upload logic
Node.js	≥ 16	Runs BatchCasesCreator.js
jq	any	JSON parsing in bash
ICA CLI (icav2)	latest	Interface to ICA platform

Install Nextflow:
curl -s https://get.nextflow.io | bash
mv nextflow /usr/local/bin/

🔐 Authentication Flow

1. autolaunch_monitor.sh & autolaunch_process.sh use ICA API keys and BSSH tokens for ICA access.

2. batchuploademg.py authenticates to Emedgene, retrieves a bearer token, and pushes case data.

3. Credentials are read securely from environment variables, not stored in the repository.

⚡ Error Handling

- Automatic retries for transient errors (maxRetries = 2)
- Resume partial executions with:

	nextflow run main.nf -resume

- Detailed logs are saved in:

	- results/logs/

	- nextflow.log

🧑‍💻 Author

Vinisha Venugopal
Bioinformatics Scientist - Clinical Genomics Lab 
📧 contact: vinishavvenugopal@gmail.com

