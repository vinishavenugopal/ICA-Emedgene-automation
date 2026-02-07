from argparse import ArgumentParser
from pandas import DataFrame, read_excel
from tempfile import NamedTemporaryFile
import subprocess
import requests
import os
import stat

route_login_platform = 'https://pch-testing.emg.illumina.com/api/auth/v2/api_login/'

username = os.environ.get('EMG_USERNAME')
password = os.environ.get('EMG_PASSWORD')

payload = {"username": username, "password": password}
response = requests.post(route_login_platform, json=payload)
access_token = response.json().get('access_token')
token_type = response.json().get('token_type')

EMG_AUTH_TOKEN = f'{token_type.capitalize()} {access_token}'
# EMG_AUTH_TOKEN = "Bearer cGNoLXRlc3RpbmcsOWRiZDQwYmEtZDc4Mi0zZWFlLTllNDMtMjMxMGViZTlkMzJj"

# Method for specifying the arguements
def create_parser():
    parser = ArgumentParser(description="Create the batch upload for loading data from ICA to EMG.")
    parser.add_argument("-s", "--sample_sheet", type=str, required=True,
                        help="An Illumina V2 sample sheet with the panel bed information in the \"Description\" column of the Cloud Data.")
    parser.add_argument("-r", "--analysis_id", type=str, required=True,
                        help="The ICA root folder for an analysis that produces secondary analysis results")
    return parser

# Function to parse the description and samples of an Illumina V2 sample sheet
def parseSampleSheet(sampleSheetName):
    sampleSheetDF = DataFrame(columns=["sample", "panel(s)"])
    with open(sampleSheetName) as fh:
        line = fh.readline()
        while "Cloud_Data" not in line: line = fh.readline()
        headerCols = fh.readline().strip('\n').strip(',').split(',')
        assert(headerCols[-1] == "Description")  # The Illumina V2 sample sheet doesn't have a column named Description as the last column in the [Cloud_Data] section
        for i, line in enumerate(fh):
            if line.strip('\n').strip(',') == '': break  # Reached the end of the cloud data when nothing there but commas
            rec = line.strip('\n').strip(',').split(',')
            if rec[0].startswith("PC"):continue
            sampleSheetDF.loc[i] = [rec[0], rec[-1]]
    return sampleSheetDF

def build_sample(sample, runFolder, panelCount=0):
    sampleID = sample["sample"]
    multi=False
    if "_" in sample["panel(s)"]:
        multi = True
    elif sample["panel(s)"] not in bedIDs or sample["panel(s)"] not in geneLists:
        raise Exception("The panel %s is not listed in the master panel bed ids. Update the master list with this panel to run." % (sample["panel(s)"]))
       
    if multi:
        print("\nMulti is True")
        panels = sample["panel(s)"].split('_')
        panelList = []
        for panel in panels:
            if "CGL" not in panel: panelList.append("CGL"+str(panel))
            else: panelList.append(panel)
        panelID = panelList[panelCount]
        if panelID not in bedIDs or panelID not in geneLists:
            raise Exception("The panel %s is not listed in the master panel bed ids. Update the master list with this panel to run." % (panelID))
        
        geneListID = geneLists[panelID]
        intersectBed = bedIDs[panelID]
        multi = (panelCount != (len(panelList)-1))
    else:
        panelID = sample["panel(s)"]
        geneListID = geneLists[panelID]
        intersectBed = bedIDs[panelID]

    row = {
        "Family Id": sampleID+"_"+panelID, 
        "Case Type": "Exome",
        "Files Names": f"/{runFolder}/{sampleID}/{sampleID}.hard-filtered.vcf.gz;/{runFolder}/{sampleID}/{sampleID}.cnv.vcf.gz;/{runFolder}/{sampleID}/{sampleID}.sv.vcf.gz",
        "Sample Type": "VCF", "BioSample Name": sampleID,
        "Visualization Files": f"/{runFolder}/{sampleID}/{sampleID}.bam;/{runFolder}/{sampleID}/{sampleID}.tn.bw;/{runFolder}/{sampleID}/{sampleID}.roh.bed",
        "Storage Provider Id": "765", 
        "Default Project": "", 
        "Execute Now": "true", 
        "Relation": "proband", 
        "Sex": 'U', 
        "Phenotypes": "no-hpo", 
        "Phenotypes Id": "", 
        "Date Of Birth": "",
        "Boost Genes": "", 
        "Gene List Id": geneListID,
        "Kit Id": '', 
        "Intersect Bed Id": intersectBed, 
        "Selected Preset": "PANELS_v1", 
        "Label Id": "", 
        "Clinical Notes": "", 
        "Due Date": "", 
        "Opt In": "false"
    }
    return row, multi

def add_write_permissions_to_all(file_path):
    """
    Adds write permissions to all users for the given file.
    """
    try:
        # Get the current permissions
        current_permissions = os.stat(file_path).st_mode

        # Add write permissions for all users (owner, group, others)
        new_permissions = current_permissions | stat.S_IRUSR | stat.S_IRGRP | stat.S_IROTH

        # Apply the new permissions
        os.chmod(file_path, new_permissions)

        print(f"Write permissions added to {file_path} for all users.")

    except OSError as e:
        print(f"Error: Could not change permissions for {file_path}: {e}")

def batch_case_upload(temp_file):
    """
    Uploads cases to Emedgene Analyze using the batchCasesCreator CLI.
    """
    add_write_permissions_to_all(temp_file.name)
    
    # Construct the command
    command = [
        "node",
        "/env/illumina/BatchCasesCreator.js",
        "create",
        "-h",
        "https://pch-testing.emg.illumina.com",
        "-c", temp_file.name,
        "-t", EMG_AUTH_TOKEN
    ]

    # Execute the command
    try:
        print(" ".join(command))
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error executing batchCasesCreator: {e}")
        return e.stderr

bedIDsDF = read_excel("/mnt/genomics/R_and_D/wes/refFiles/TestingBED_IDs.xlsx", header=None, names=["CGL", "bed_id"])
bedIDs = {}
for i, row in bedIDsDF.iterrows():
    bedIDs[row["CGL"]] = str(int(row["bed_id"]))
bedIDs[''] = ''

geneListIDs = read_excel("/mnt/genomics/R_and_D/wes/refFiles/TestingGeneIDs.xlsx", header=None, names=["CGL",  "gene_id"])
geneLists = {}
for i, row in geneListIDs.iterrows():
    geneLists[row["CGL"]] = str(int(row["gene_id"]))
geneLists[''] = ''

if __name__ == "__main__":
    parser = create_parser()
    args = parser.parse_args()
    print("*******************")  # 0. Inputs

    sampleSheet = args.sample_sheet  # "/mnt/genomics/SampTest.csv"
    runFolder = args.analysis_id  # "VS-Val-T1R-Samples-PCH_GermlineEnrichment_4-3-6_1-fcd27445-6f55-4fcb-b925-34ecc9221567"
    print(username)
    # 1. Read SampleSheet
    samps = parseSampleSheet(sampleSheet)
    print(samps)

    # 2. Generate the batch csv file
    csv_header = """[Data],,,,,,,,,,,,,,,,,,,,,,
Family Id,Case Type,Files Names,Sample Type,BioSample Name,Visualization Files,Storage Provider Id,Default Project,Execute Now,Relation,Sex,Phenotypes,Phenotypes Id,Date Of Birth,Boost Genes,Gene List Id,Kit Id,Intersect Bed Id,Selected Preset,Label Id,Clinical Notes,Due Date,Opt In,
"""

    with NamedTemporaryFile(mode="w", delete=False) as temp_file:
        # write header to the temporary file
        temp_file.write(csv_header)
        
        # write each sample to the temp file
        columns = [
            "Family Id", "Case Type", "Files Names", "Sample Type", "BioSample Name", "Visualization Files", "Storage Provider Id", 
            "Default Project", "Execute Now", "Relation", "Sex", "Phenotypes", "Phenotypes Id", "Date Of Birth", "Boost Genes", 
            "Gene List Id", "Kit Id", "Intersect Bed Id", "Selected Preset", "Label Id", "Clinical Notes", "Due Date"
        ]
        for i, sample in samps.iterrows():
            row, multi = build_sample(sample,runFolder)
            pCount = 0
            while multi:
                pCount+=1
                row2, multi = build_sample(sample,runFolder,pCount)
                for col in columns: temp_file.write(row2[col]+',')
                temp_file.write("FALSE\n") #Opt In Value
            
            for col in columns: temp_file.write(row[col]+',')
            temp_file.write("FALSE\n") #Opt In Value
        
        temp_file.flush()  # Ensure data is written to the file
        
        # batch upload the cases in the sample sheet
        print(batch_case_upload(temp_file))

