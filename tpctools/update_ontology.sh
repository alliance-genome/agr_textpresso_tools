#!/usr/bin/env bash

send_report() {
    local subject="$1"
    local message="$2"
    conda run -n agr_textpresso python3 /data/textpresso/tpctools/send_report.py "$subject" "$message"
    exit 1
}

echo "Starting category files generation..."
if ! conda run -n agr_textpresso python3 /data/textpresso/tpctools/getOntologies/get_categories.py -m "${MOD}" -a; then
    send_report "${MOD} Textpresso Category Files Generation" "Failed to generate category files."
fi

echo "Moving category files ..."
if ! mv ./*.obo /data/textpresso/obofiles4production/; then
    send_report "${MOD} Textpresso Getting Category Files Ready" "Failed to move category files."
fi

echo "Generating CAS-2 files..."
if ! annotate -P 2; then
    send_report "${MOD} Textpresso CAS-2 Files Generation" "Failed to generate CAS-2 files."
fi

# echo "Transferring bib files over to tpcas-2 folder..."
# if ! rsync -av /data/textpresso/raw_files/bib/ /data/textpresso/tpcas-2/; then
#    send_report "${MOD} Textpresso Rsyncing Bib Files" "Failed to transfer bib files over to tpcas-2 folder."
# fi

echo "Indexing papers..."
if ! index; then
    send_report "${MOD} Textpresso Indexing" "Failed to index papers."
fi

send_report "${MOD} Textpresso Ontology Update Report" "The ontology/category terms have been successfully updated and the full text papers have been remarked!"
