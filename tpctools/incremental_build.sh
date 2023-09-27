#!/usr/bin/env bash

raw_file_dir="/data/textpresso/raw_files_new"
cas1_dir="/data/textpresso/tpcas-1_new"
cas2_dir="/data/textpresso/tpcas-2_new"

check_data.sh -i

echo "DONE running check data for ontology files!"

tokenize -P 4 -p "${raw_file_dir}/pdf" -c ${cas1_dir}

echo "DONE generating cas-1 files!"

check_data.sh -1

echo "DONE running check data for cas1 files!"

annotate -P 2 -c ${cas1_dir} -C ${cas2_dir}

echo "DONE cas-2 files generation!"

check_data.sh -2

echo "DONE running check data for cas2 files!"
    
rsync -av "${raw_file_dir}/bib/" "${cas2_dir}/"

echo "DONE transferring bib files over to tpcas-2 folder!"

/data/textpresso/tpctools/incremental_index.sh -C ${cas2_dir}

echo "DONE indexing!"


