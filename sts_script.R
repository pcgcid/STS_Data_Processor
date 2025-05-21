#!/usr/bin/env Rscript
#####################################################################################
#####################################################################################

#Script to strip PHI from STS data file and remove procedures occurring in unconsented 
#participants > 18 years of age

#notes: 
#.      - program assumes sts file is a tab delimited text file, that all sites will have the same set of column headers, 
#.        and that the headers/column names are case sensitive
#.      - program assumes a key file is provided as a tab delimited text file that contains the columns MRN, STS_ID, PCGC_ID, adult_consent
#.      - program assumes MRNs and STS IDs in key file map to the format in the STS dataset. For example, 
#.        if your STS file contains MRNs submitted with various formats such as "MR123456", "mr123456", "123456" then 
#.        your key should contain MRNs in these various formats
#.      - program will first try to match MRNs in the key file to the MRNs in the sts data file. If a MRN is missing in 
#.        the key file (e.g., left blank) then the program will try to match record on the STS ID
#.      - program assumes that all patients that were consented as adult (reconsented or consented at >= 18 years of age) will be identified by a 
#.        numeric value of 1 in the adult_consent column in the key file. For patients < 18 years of age
#.        or those that have not yet reconsented after turning 18y this column can either be left blank or a value 
#.        of 0 provided. 


#notes to Trang:
#       - I defer to how you want to have sites pass the data to the container (either mounting a folder or 
#.        passing paths to each file directly) 
#.      - the my_cols object that is read in below will need to be made available to the script in the container. I defer
#.        to you as to whether this is easiest by including it in a data folder or via some other approach.
#.      - Ideally, we want all the messages and error below that are written to the R console to be written to the 
#.        terminal when running the container. Please let me know if this will not work. Another option would be to 
#.        write them all to a log file etc.
#.        


#Created by: Nicholas Ollberding
#On: 12/10/24
#R version: 4.1.1
# - tidyverse v1.3.1
# - readr v2.1.4
# - data.table v1.14.8
#####################################################################################
#####################################################################################


#Load libraries 
#library(tidyverse)
suppressWarnings({
  suppressMessages({
    library(readr)
    library(data.table)
    library(docopt)
    library(dplyr)
  })
})


doc <- "
      Usage:
        sts_script.R [-h | --help] [--input-file <filename>] [--key-file <keyfile>]

         
      Options:
        -h --help             Show available parameters.
        --input-file <filename>
                              Specify input tab-separated .txt file or a .tsv sts data file.
        --key-file <keyfile>
                              Specify key tab-separated .txt file or a .tsv file.
                              
      "
opt <- docopt::docopt(doc)


cat("\nRunning version with Commit:", Sys.getenv("GIT_COMMIT"), "of Date:", Sys.getenv("GIT_DATE"), "\n")


# Access the parsed arguments
input_path <- opt[["--input-file"]]
key_file <- opt[["--key-file"]]

# function to check if the file is a tsv or tab-separated text file
check_tsv_file <- function(file_path) {
  # browser()
  if (!grepl("\\.(txt|tsv)$", file_path, ignore.case = TRUE)) 
    stop("Invalid file extension. Please specify a  tab-separated .txt file or a .tsv file")
  lines <- readLines(file_path, n = 10, warn=FALSE)

  # Read the TSV file
  df <- tryCatch({
    suppressWarnings(read_tsv(file_path, show_col_types = FALSE, name_repair = 'minimal'))
  }, error = function(e) {
    stop("Not tab-separated. Please specify a tab-separated input file")
  })
  
  # Check for empty columns
  empty_cols <- names(df)[names(df) == ""]
  
  if (length(empty_cols) > 0) {
    stop(paste("Error: Empty columns were found in ", file_path, ". Please remove the empty columns and try again"))
  }
  
}

#check if the input file is valid
if (is.null(input_path)){
  stop("Input sts data file is missing. Please specify a tab-separated .txt file or a .tsv file")
}
check_tsv_file(input_path)


if (is.null(key_file)){
  stop("Key tab-separated file is missing. Please specify a tab-separated .txt file or a .tsv sts data file")
}
check_tsv_file(key_file)


#notes: - this is serving to "mount a volume" containing the site STS files
#.      - I expect this can get edited out of the final program if the -v /path/to/local/folder:/container/path is
#.        used to mount a folder containing these files when the container is created
#.      - please let me know if you know a better way!


#Read in site STS data in chunks of 1000 rows to limit memory requirements
chunk_list <- list()
process_chunk <- function(data, pos) {
  data
}
callback <- DataFrameCallback$new(process_chunk)

sts_df <- read_tsv_chunked(
  file = input_path,
  callback = callback,
  chunk_size = 1000,    
  col_names = TRUE,
  show_col_types = FALSE)

#sts_df <- rbindlist(chunk_list)


#Verify all column headers in the STS data file are as expected   
sts_cols <- readRDS("/app/sts_col_names.rds")   #this will need to be loaded into the docker image so it can be read in by the R program
my_cols <- colnames(sts_df)

check_vectors <- function(vector1, vector2) {
  if (identical(sort(vector1), sort(vector2))) {
    message("All column headers in the STS data file are as expected. Continuing...\n")
  } else {
    # stop if either "PatID" or "MedRecN" not in the STS file
    if (!("PatID" %in% vector1) | !("MedRecN" %in% vector1)) {
      stop("Error: The STS data file does not contain the expected patient ID ('PatID') or medical record number ('MedRecN') columns. Please contact the ACC for assistance.")
    } else {
      #find missing or extra columns
      extra_cols <- setdiff(vector1, vector2)
      missing_cols <- setdiff(vector2, vector1)
      if (length(missing_cols) > 0) {
        message("The following columns are missing from your STS data file: ", paste(missing_cols, collapse = ", "), 
                ".\nPlease note that the program is case sensitive.")
      }
      if (length(extra_cols) > 0) {
        message("The following columns are present in your STS data file but were not expected: ", paste(extra_cols, collapse = ", "), ".
        \nPlease confirm any extra columns do not contain PHI before sending to the ACC (and if they do contain PHI to manually remove those columns).
                \nNote that the program is case sensitive.")
      }
    }
    
  }
}
check_vectors(my_cols, sts_cols)


#Remove/strip all PHI fields
drop_cols <- c("CHSDID", "ParticID", "VendorID", "AsstSurgeon", "AsstSurgNPI", "BirthCit", "BirthHospName",	"BirthHospTIN", "BirthSta",
               "CnsltAttnd",	"CnsltAttndID", "CRNA",	"CRNAName", "FelRes", "HandoffAnesth",	"HandoffNursing",	"HandoffPhysStaff",
               "HandoffSurg", "HICNumber", "HospName",	"HospNameKnown",	"HospNPI",	"HospStat",	"HospZIP",
               "MatFName",	"MatLName", "MatMInit",	"MatMName",	"MatNameKnown",	"MatSSN",	"MatSSNKnown",
               "NonCVPhys", "PatCountry",	"PatFName", "PatLName",	"PatMInit",	"PatMName",
               "PatPostalCode", "PatRegion", "PrimAnesName", "RefCard",	"RefPhys", "Resident",	"ResidentID",
               "SecAnes",	"SecAnesName", "Surgeon", "SurgNPI", "TIN", "AdmitFromLoc", "BirthCou", "BirthInfoKnown", "BirthLocKnown", 
               "HospCMSCert", "PayorPrim", "PrimMCareFFS", "PayorSecond", "SecondMCareFFS", "MHICNumber", "PrimAnesNPI", "PatAddr", "PatCity", "OperationID")

clean_df <- sts_df %>%
  select(-any_of(drop_cols))

check_no_phi <- function(vector1, vector2) {
  common_items <- intersect(vector1, vector2)
  if (length(common_items) == 0) {
    message("PHI has been removed. Continuing...\n")
  } else {
    stop("Error: Some PHI may have failed to be removed from your STS file. Please contact the ACC for assistance. The fields are: ", paste(common_items, collapse = ", "))
  }
}
check_no_phi(colnames(clean_df), drop_cols)

clean_df <- clean_df %>%
  mutate(PatID = as.character(PatID),
         MedRecN = as.character(MedRecN))

#Replace STS IDs with PCGC blinded IDs
pcgc_ids <- suppressWarnings({read_tsv(key_file,show_col_types = FALSE)})

nrow_orig = nrow(pcgc_ids)
pcgc_ids <- pcgc_ids %>%
  rename_all(tolower) %>%
  rename("PatID" = "sts_id",
         "MedRecN" = "mrn") %>%
  mutate(PatID = as.character(PatID),
         MedRecN = as.character(MedRecN),
         PatID_key = PatID,
         MedRecN_key = MedRecN)

suppressMessages({
  matched_both_mrn_sts.id = pcgc_ids %>%
  inner_join(clean_df) 
})

mrn_ids_df <- pcgc_ids %>%
  select(-PatID) %>%
  inner_join(clean_df, by = "MedRecN") %>%
  filter(is.na(PatID) |is.na(PatID_key)) 

sts_ids_df <- pcgc_ids %>%
  select(-MedRecN) %>%
  inner_join(clean_df, by = "PatID") %>%
  filter(is.na(MedRecN) | is.na(MedRecN_key))


full_df <- rbind(matched_both_mrn_sts.id, mrn_ids_df, sts_ids_df) %>%
  mutate(PatID = ifelse(is.na(PatID), PatID_key, PatID),
         MedRecN = ifelse(is.na(MedRecN), MedRecN_key, MedRecN)) %>%
  select(-PatID_key, -MedRecN_key) %>%
  relocate(PatID, MedRecN)
pcgc_df <- full_df %>%
  select(-MedRecN, -PatID)

nrow_filtered = nrow(pcgc_df)

if (nrow_orig - nrow_filtered > 0) {
  message("Message: The number of rows in the STS data file has been reduced from ", nrow_orig, " to ", nrow_filtered, " after mapping PCGC IDs to the STS data file.
          \n The row(s) were removed because there is no matching MRN or STS ID in the STS data file.")
} 

check_dataframe <- function(df, column_name1, column_name2) {
  if (nrow(df) < 1) {
    stop("Error: The program failed to map your PCGC IDs to the STS data file. Please contact the ACC for assistance.")
  }
  if (column_name1 %in% colnames(df)) {
    stop(paste("Error: The program failed to strip the STS IDs from your dataset. Please contact the ACC for assistance."))
  }
  if (column_name2 %in% colnames(df)) {
    stop(paste("Error: The program failed to strip the MRNs from your dataset. Please contact the ACC for assistance."))
  }
  message("PCGC IDs have been mapped to the STS data file. Continuing...\n")
}
check_dataframe(pcgc_df, "PatID", "MedRecN")
#notes: - code above assumes that PatID and MedRecN will be observed for all rows in STS file and uses this 
#.        information to filter out those included in the key file but not found in the STS data file



#Remove anyone over 18 years of age without re-consent 
minor_df <- pcgc_df %>%
  filter(AgeDays < 18 * 365.25)

adult_df <- pcgc_df %>%
  filter(AgeDays >= 18 * 365.25) %>%
  filter(adult_consent == 1)

acc_df <- rbind(minor_df, adult_df)


check_age_and_consent <- function(df) {
  if (!"AgeDays" %in% colnames(df)) {
    stop("Error: The dataset does not appear to contain the expected age at surgery column. Please contact the ACC for assistance.")
  }
  if (!"adult_consent" %in% colnames(df)) {
    stop("Error: The dataset does not appear to contain the expected reconsented at age 18y column. Please contact the ACC for assistance.")
  }
  valid_rows <- df$AgeDays < 18 * 365.25 | (df$AgeDays >= 18 * 365.25 & df$adult_consent == 1)
  if (!all(valid_rows)) {
    stop("Error: The program may have failed to remove some procedures occurring in unconsented patients >18 years of age. Please contact the ACC for assistance.")
  }
  message("Surgeries after the age of 18 on patients that did not consent or re-consent as adults have been removed. Continuing...\n")
  }
check_age_and_consent(acc_df)

#Exporting de-identified STS data	
write_file <- function(df) {
  result <- try(write_tsv(df, file = "STS_file_for_ACC.tsv", na = ""), silent = TRUE)
  if (inherits(result, "try-error")) {
    stop("Error: Unable to export de-identified STS file. Please contact the ACC for assistance.")
  } else {
    message("Exporting de-identified STS file. Please review file to ensure that there is no remaining PHI and all surgeries from participants who did not (re-) consent as adults have been removed. If you have any questions please contact the ACC.")
  }
}
write_file(acc_df)


#Listing to inform site of any MRNs or STS IDs that failed to be detected in the STS file
not_common_mrn <- setdiff(unique(pcgc_ids$MedRecN), unique(sts_df$MedRecN)) 

not_common_mrn <- not_common_mrn[!is.na(not_common_mrn)]

if (length(not_common_mrn) > 0 ){
  message("Warning: - The following MRNs were provided in your key file but were not found in the STS data file:"," ", paste(not_common_mrn, collapse = ", "), 
           "\n
           - Please double check if the MRNs in the STS file are in the assumed format.  
           - A listing has also been provided in the file unmapped_mrns.csv. 
           - If no MRNs are printed to the screen, then all IDs were matched.\n" )
}

mrn_list_df <- data.frame(
  MRN = not_common_mrn )

write_csv(mrn_list_df, "unmapped_mrns.csv")


not_common_sts <- setdiff(unique(pcgc_ids$PatID), unique(sts_df$PatID))

not_common_sts <- not_common_sts[!is.na(not_common_sts)]

if (length(not_common_sts) > 0 ){
  
  message("Warning: - The following MRNs were provided in your key file but were not found in the STS data file:"," ", paste(not_common_mrn, collapse = ", "), 
          "\n
           - Please double check if the STS IDs in the STS file are in the assumed format.
           - A listing has also been provided in the file unmapped_sts_ids.csv. 
           - If no STS IDs are printed to the screen, then all IDs were matched.\n")
}

sts_list_df <- data.frame(
  STS_ID = not_common_sts)

sts_list_df <- sts_list_df %>%
  filter(!(is.na(STS_ID)))

write_csv(sts_list_df, "unmapped_sts_ids.csv")


#Listing to inform site of total PCGC blind IDs requested and total returned
key_pcgc_ids <- unique(pcgc_ids$pcgc_id)
acc_pcgc_ids <- unique(acc_df$pcgc_id)

message("Message: A total of ", length(key_pcgc_ids), " unique PCGC blind IDs were provided in the key file.")
message("Message: A total of ", length(acc_pcgc_ids), " unique PCGC blind IDs have been returned in the STS_file_for_ACC.tsv file.")
message("Message: If the difference between those requested and returned is large (i.e., more than would have been expected to have turned 18 and not been reconsented) then please double check if the MRNs and STS IDs included in your key file match the format in the STS data file.")

