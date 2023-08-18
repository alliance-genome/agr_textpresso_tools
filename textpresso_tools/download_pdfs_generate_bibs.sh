#!/usr/bin/env bash

# Define a function for displaying usage information
function usage {
    echo "This script downloads articles from tazendra (C. elegans pdfs)."
    echo
    echo "Usage: $(basename "$0") [-m -p -b -h]"
    echo "  -m --mod_abbreviation      SGD or WB or other mod"
    echo "  -p --pdf-dir               directory where raw pdf files will be stored"
    echo "  -b --bib-dir               directory where bib files will be stored"
    echo "  -h --help                  display help"
    exit 1
}

function get_from_reference_id_from_log_file() {
    local logfile="$1"

    # Get the second to last line of the file
    local second_to_last_line
    second_to_last_line=$(tail -n 2 "$logfile" | head -n 1)

    # Extract the desired pattern using awk                                                                                                           
    local from_reference_id
    from_reference_id=$(echo "$second_to_last_line" | awk '{print $2}')

    echo "from_reference_id: " $from_reference_id
}


# Check for arguments using getopts
while getopts "m:p:b:h" opt; do
    case $opt in
        m)
            mod="$OPTARG"
            ;;
        p)
            pdf_dir="$OPTARG"
            ;;
        b)
            bib_dir="$OPTARG"
            ;;
        h)
            usage
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            usage
            ;;
    esac
done

# Check if the required arguments are provided
if [ -z "$mod" ] || [ -z "$pdf_dir" ] || [ -z "$bib_dir" ]; then
    echo "Usage: $(basename "$0") -m mod_abbreviation -p pdf_dir -b bib_dir"
    exit 1
fi

echo "mod = " $mod
echo "pdf_dir = " $pdf_dir
echo "bib_dir = " $bib_dir

# PDF_DIR="/data/textpresso/raw_files/pdf"
# LOCKFILE="/data/textpresso/tmp/01downloadpdfs.lock"
LOCKFILE="./download_pdfs_generate_bibs.lock"

if [[ -f "${LOCKFILE}" ]]
then
    echo $(basename $0) "is already running."
    echo "lockfile = " ${LOCKFILE}
    exit 1
else
    touch "${LOCKFILE}"
    export PATH=$PATH:/usr/local/bin
    # temp files
    logfile=$(mktemp)
    echo "logfile = " $logfile    
    echo "Downloading pdfs and generating bib files..."
    mkdir -p ${pdf_dir}
    mkdir -p ${bib_dir}

    start_program() {
	local from_reference_id="$1"
	python3 ./getPdfBiblio/download_pdfs_bib_files.py -m ${mod} -p ${pdf_dir} -b ${bib_dir} -f ${from_reference_id} >& ${logfile}
    }

    start_program 0

    while true; do
	if pgrep -f "./getPdfBiblio/download_pdfs_bib_files.py" >/dev/null; then
            echo "Program is running."
	else
            exit_status=$?
            if [ $exit_status -ne 0 ]; then
		
		## read from_reference_id from log_file
		from_reference_id=$(get_from_reference_id_from_log_file "$logfile")
		
		if [[ "$from_reference_id" =~ ^[0-9]+$ ]]; then
		    echo "Program exited with an error: $exit_status. Restarting...from_reference_id = " ${from_reference_id}
		    start_program "$from_reference_id"
		else
		    echo "The 'from_reference_id' returned is not a number. Exiting..."
		    break
		fi
	    else
		break
            fi
	fi
	sleep 10
    done
    # rm ${logfile}
    rm ${LOCKFILE}
fi
