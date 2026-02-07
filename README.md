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




---

## 📁 Repository Structure


---

## ⚙️ Configuration

Before running, export these environment variables:

```bash
export ICA_API_KEY="your_ica_api_key"
export BSSH_ACCESS_TOKEN="your_bssh_token"
export EMG_USERNAME="your_email@example.com"
export EMG_PASSWORD="your_password"
```

You can also configure defaults in nextflow.config:

params {
  bssh_project_id   = 'a7208a06-2a83-4ae8-90bc-6997889754f0'
  ica_project_id    = '04c8fc29-089c-4571-b002-c81ccdce49d9'
  poll_interval_sec = 3600
  output_dir        = './results'
}

## 🧠 Usage

Run Once

```bash
nextflow run main.nf -resume
```

Run Continuously (via cron)

To check BaseSpace every hour:

```bash
*/60 * * * * cd /path/to/ica-emedgene-automation && nextflow run main.nf -resume
```

Switch to a Different Environment

```bash
nextflow run main.nf -c configs/prod.config -resume
```

## 📊 Outputs


|Directory | Description |
|------------|-------------|
| `results/logs/` | BaseSpace monitoring and ICA logs |
| `results/ica_outputs/` | ICA secondary analysis outputs |
| `results/emedgene_uploads/` | Upload logs and confirmation files |
| `results/report.html` | Nextflow run summary |
| `results/timeline.html` | Interactive timeline for each process |

## 🧱 Requirements

| Tool | Minimum Version | Purpose |
|------|------------------|---------|
| **Nextflow** | ≥ 23.04 | Workflow orchestration |
| **Python** | ≥ 3.8 | Emedgene upload script |
| **Node.js** | ≥ 16 | Required for `BatchCasesCreator.js` |
| **jq** | any | JSON parsing in bash |
| **ICA CLI (`icav2`)** | latest | Interface to ICA |


To install Nextflow:

```bash
curl -s https://get.nextflow.io | bash
mv nextflow /usr/local/bin/
```

##  Authentication Flow

1. autolaunch_monitor.sh and autolaunch_process.sh use ICA API keys and BSSH tokens to access sequencing data and workflows.

2. batchuploademg.py logs in to Emedgene using environment credentials and receives a bearer token for authenticated uploads.

3. No credentials are stored inside the repository — all are provided at runtime.

##  Error Handling

Each process automatically retries failed steps (maxRetries = 2).

You can resume incomplete workflows using:

```bash
nextflow run main.nf -resume
```

Logs are saved in:

- results/logs/
- nextflow.log

## 🧑‍💻 Author
Vinisha Venugopal
Bioinformatics Scientist - Clinical Genomics Lab 
📧 contact: vinishavvenugopal@gmail.com

