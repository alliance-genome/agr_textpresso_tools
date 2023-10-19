#!/usr/bin/env bash

raw_file_dir="/data/textpresso/raw_files_new"
cas1_dir="/data/textpresso/tpcas-1_new"
cas2_dir="/data/textpresso/tpcas-2_new"
index_dir="/data/textpresso/luceneindex_new"

rm -rf "${raw_file_dir}"
rm -rf "${cas1_dir}"
rm -rf "${cas2_dir}"
rm -rf "${index_dir}"

## downloading pdfs and generating bib files

conda run -n agr_textpresso python3 /data/textpresso/tpctools/getPdfBiblio/download_pdfs_bib_files.py -m "${MOD}" -d 6 -p "${raw_file_dir}"

echo "DONE downloading PDFs and generating bib files!"

echo -n "Total new PDF file(s): "
find "${raw_file_dir}/pdf" -maxdepth 3 -name "*.pdf" | wc -l

# convert pdf2txt
convert_text "${raw_files_new}"

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

## indexing the new papers

/data/textpresso/tpctools/incremental_index.sh -C ${cas2_dir}

echo "DONE indexing!"

# copy files to main dirs
rsync -av "${raw_file_dir}" "/data/textpresso/raw_files"
rsync -av "${cas1_dir}" "/data/textpresso/tpcas-1"
rsync -av "${cas2_dir}" "/data/textpresso/tpcas-2"

conda run -n agr_textpresso python3 /data/textpresso/tpctools/send_report.py

# remove temp files
rm -rf "${raw_file_dir}"
rm -rf "${cas1_dir}"
rm -rf "${cas2_dir}"
rm -rf "${index_dir}"