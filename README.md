# A Docker container to anonymize/recode STS (Society of Thoracic Surgeons) data

## Introduction
The STS docker container is used to strip PHI from STS data file and remove procedures occurring in adult participants who have not been (re-) consented as adults.

After installation, the software runs on a local computer without requiring an internet connection, thus maintaining the security and privacy of the participant information. 

## Requirements
* Operating System:
    + MacOS
    + Windows
* RAM: 8GB
* Disk Space: 20GB (docker container is 10GB)
* administrator privileges (initially only, to install the 'docker' software)

## Step 0: Install Docker

See the [Installing Docker](https://degauss.org/using_degauss.html#Installing_Docker) webpage.
Make sure you have the latest Docker version installed on your computer.

> <font size="3.5"> **_Note about Docker Settings:_** </font> <br> <font size="2.75"> After installing Docker, but before running containers, go to **Docker Settings > Advanced** and change **memory** to greater than 4000 MB (or 4 GiB) <br> 
 <center> <img width=75% src="figs/docker_settings_memory.png"> </center> <br> 
If you are using a Windows computer, also set **CPUs** to 1. <br> 
<center> <img width=75% src="figs/docker_settings_cpu.png">
</center> Click **Apply** and wait for Docker to restart. </font>


## Step 1: Running the STS container

The command to process it through the STS container is:
 
  - macOS:
  
    ```sh
    docker run --rm -v $PWD:/tmp ghcr.io/pcgcid/sts_processor:0.0.1 \
    --input-file <filename.txt> --key-file <keyfile.txt>
    ```
  
  - Windows (CMD):
  
    ```sh
    docker run --rm -v "%cd%":/tmp ghcr.io/pcgcid/sts_processor:0.0.1 ^
    --input-file <filename.txt> --key-file <keyfile.txt>
    ```
    
For example, the following command can be used to trip PHI from STS data file and remove procedures occurring in unconsented participants > 18 years of age an STS data stored in 'STS_dummy_data.txt' and remove unwanted columns (e.g., those with PHI or other sensitive data) for a list of cases stored in 'STS_map_file.txt':
  
  - macOS:
  
    ```sh
    docker run --rm -v $PWD:/tmp ghcr.io/pcgcid/sts_processor:0.0.1 \
    --input-file "STS_dummy_data.txt" --key-file "STS_map_file.txt"
    ```
    
  
  - Windows (CMD):
  
    ```sh
    docker run --rm -v "%cd%":/tmp ghcr.io/pcgcid/sts_processor:0.0.1 ^
    --input-file "STS_dummy_data.txt" --key-file "STS_map_file.txt"
    ```

The container will output 'STS_file_for_ACC.tsv' that contains de-identified STS data, which is safe for uploading to the ACC. The container will also output 'unmapped_mrns.csv' and 'unmapped_sts_ids.csv' files that contain the MRNs and STS IDs that were not found in the key file.

**_Notes:_**

- program assumes sts file is a tab-delimited txt file, that all sites will have the same set of column headers, and that the headers/column names are case sensitive
- program assumes a key file is provided that contains the column headers MRN, STS_ID, PCGC_ID, adult_consent. Please use the provided sample file as a guideline.
- program assumes MRNs and STS IDs in key file map to the format in the STS dataset. For example, if your STS file contains MRNs (found in column MedRecN) submitted with various formats such as "MR123456", "mr123456", "123456" then your key should contain MRNs in these various formats. STS_IDs are found in column PatID in the STS data.
        
The output files will be stored in the current directory. 


## Parameters

Command line parameters to show help:

- `-h` or `--help`: Show available parameters. For example, users can use this command:

  ```sh
  docker run  ghcr.io/pcgcid/sts_processor:0.0.1 -h
  ```
or 

  ```sh
  docker run  ghcr.io/pcgcid/sts_processor:0.0.1 --help
  ```

This container __requires__ both of the following arguments:

- `--input-file` to specify an tab delimited text (.txt) or a .tsv file with STS data containing STS data. The program assumes that all sites will have the same set of column headers, and that the headers/column names are case sensitive
- `--key-file` to specify an tab delimited text (.txt) or a .tsv key file that contains the columns MRN, STS_ID, PCGC_ID, adult_consent


# Details on the processing steps contained in the software
- program will first try to match MRNs in the key file to the MRNs in the STS data file (column MedRecN). If an MRN is missing in the key file (e.g., left blank) then the program will try to match record on the STS ID (column PatID in STS data file).
- program assumes that all patients that were consented or reconsented at >= 18 years of age will be identified by a numeric value of 1 in the adult_consent  column in the key file. For patients < 18 years of age or those that have not yet reconsented after turning 18y this column can either be left blank or a value of 0 provided.
- 
## Questions?

Please contact help-pcgcdatahub@bmi.cchmc.org for any questions or technical challenges with this process.

