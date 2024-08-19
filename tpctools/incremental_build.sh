#!/usr/bin/env bash

raw_file_dir="/data/textpresso/raw_files_new"
raw_file_past_week_dir="/data/textpresso/raw_files_past_week"
cas1_dir="/data/textpresso/tpcas-1_new"
cas2_dir="/data/textpresso/tpcas-2_new"
index_dir="/data/textpresso/luceneindex_new"

rm -rf "${raw_file_dir}"
rm -rf "${cas1_dir}"
rm -rf "${cas2_dir}"
rm -rf "${index_dir}"

## downloading pdfs and generating bib files

mv "${raw_file_past_week_dir}"/* "${raw_file_dir}/"

conda run -n agr_textpresso python3 /data/textpresso/tpctools/getPdfBiblio/download_pdfs_bib_files.py -m "${MOD}" -d 6 -p "${raw_file_dir}"

echo "DONE downloading PDFs and generating bib files!"

echo -n "Total new PDF file(s): "
find "${raw_file_dir}/pdf" -maxdepth 3 -name "*.pdf" | wc -l

# Count the total number of PDF files in raw_file_dir
total_pdfs=$(find "${raw_file_dir}/pdf" -maxdepth 3 -name "*.pdf" | wc -l)

# Check if the total number of PDFs is less than 10
if [ "$total_pdfs" -lt 10 ]; then
    # Move raw_file_dir to raw_file_past_week_dir and exit
    # wait for next week to process them
    mv "${raw_file_dir}"/* "${raw_file_past_week_dir}/"
    echo "Less than 10 PDFs found. Moved files to raw_file_past_week_dir and exiting."
    rm -rf "${raw_file_dir}"
    exit 0
else
    # Remove all files in raw_file_past_week_dir
    rm -r "${raw_file_past_week_dir}"/*
    echo "10 or more PDFs found. Cleared raw_file_past_week_dir."
fi

# convert pdf2txt
convert_text "${raw_file_dir}"

## generating CAS-1 files

tokenize -P 4 -p "${raw_file_dir}/pdf" -c ${cas1_dir}

echo "DONE generating cas-1 files!" 

echo -n "Total new CAS-1 file(s): "
find "${cas1_dir}" -maxdepth 3 -name "*.tpcas*" | wc -l

echo -n "Empty CAS-1 file(s): "
find "${cas1_dir}"  -maxdepth 3 -type f -name "*.tpcas.gz" -exec ls -l {} \; | grep " 0 " | wc -l

## generating CAS-2 files

annotate -P 2 -c ${cas1_dir} -C ${cas2_dir}

echo "DONE cas-2 files generation!"

echo -n "Total new CAS-2 file(s): "                                                                                                                               
find "${cas2_dir}" -maxdepth 3 -name "*.tpcas*" | wc -l 
find "${cas2_dir}" -maxdepth 3 -name "*.tpcas*"
 
echo -n "Empty CAS-2 file(s): "                                                                                                                                    
find "${cas2_dir}"  -maxdepth 3 -type f -name "*.tpcas.gz" -exec ls -l {} \; | grep " 48 " | wc -l

## syncing bib files
     
rsync -av "${raw_file_dir}/bib/" "${cas2_dir}/"

echo "DONE transferring bib files over to tpcas-2 folder!"

# copy files to main dirs
rsync -av "${raw_file_dir}/" "/data/textpresso/raw_files/"
rsync -av "${cas1_dir}/" "/data/textpresso/tpcas-1/"
rsync -av "${cas2_dir}/" "/data/textpresso/tpcas-2/"

if [[ ${MOD} == 'WB' ]]; then
   # indexing all papers to avoid duplicates
   index
else
   # indexing the new papers only
   /data/textpresso/tpctools/incremental_index.sh -C "${cas2_dir}"
fi
echo "DONE indexing!"

conda run -n agr_textpresso python3 /data/textpresso/tpctools/send_report.py

# remove temp files
rm -rf "${raw_file_dir}"
rm -rf "${cas1_dir}"
rm -rf "${cas2_dir}"
rm -rf "${index_dir}"
