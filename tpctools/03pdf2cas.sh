#!/usr/bin/env bash

function usage {
    echo "this script converts pdfs into cas files."
    echo
    echo "usage: $(basename $0) [-pcPh]"
    echo "  -p --pdf-dir      directory where raw pdf files are"
    echo "  -c --cas1-dir     directory where generated cas1 files will be stored"
    echo "  -P --num-proc     maximum number of parallel processes"
    echo "  -h --help         display help"
    rm ${LOCKFILE}
    exit 1
}

PDF_DIR="/data/textpresso/raw_files/pdf"
CAS1_DIR="/data/textpresso/tpcas-1"
N_PROC=8
LOCKFILE="/data/textpresso/tmp/03pdf2cas.lock"
if [[ -f "${LOCKFILE}" ]]
then
  echo $(basename $0) "is already running."
  exit 1
else
  touch "${LOCKFILE}"
  while [[ $# -gt 0 ]]
  do
    key=$1

	  case $key in
	    -p|--pdf-dir)
		shift
		PDF_DIR="$1"
		shift
		;;
	    -c|--cas1-dir)
		shift
		CAS1_DIR="$1"
	    shift
	    ;;
	    -P|--num-proc)
		shift
		N_PROC=$1
		shift
		;;
	    -h|--help)
		usage
		;;
	    *)
		echo "wrong argument: $key"
		echo
		usage
	  esac
  done
    
  export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib
  export PATH=$PATH:/usr/local/bin
    
  echo "Generating CAS1 files ..."
    
  cd ${PDF_DIR}
  # obtain all the folder names in PDF_DIR then create tpcas1 folders for every corpus
  for folder in */ ;
  do
	  mkdir -p "${CAS1_DIR}/${folder}"
  done
    
  # check for newer files in each pdf folder, make processing list
  for folder in *;
  do
	  echo "${folder}"
	  rm -f /tmp/"${folder}".*.list
    rm -f /tmp/"${folder}".*.processed
	  counter=0
	  for i in "${folder}"/*
	  do
	    if [[ $i -nt "${CAS1_DIR}/$i" ]]
	    then
		    d=${i#"${folder}"/}
		    bin=$(($counter % $N_PROC))
		    echo $d >> "/tmp/${folder}.$bin.list"
		    touch ""/tmp/"${folder}.$bin.processed"
		    counter=$(($counter+1))
	    fi
	  done
  done
  # run article2cas, with CAS1_DIR as CWD
  cd ${CAS1_DIR}
  for folder in *
  do
    while [[ $(ls -l "${folder}" | wc -l) -lt $(ls -l "${PDF_DIR}/${folder}" | wc -l) ]]
	  do
	    for ((j=0; j<${N_PROC}; j++))
	    do
	      grep -v -x -f <(sort "/tmp/${folder}.$j.processed" | uniq) "/tmp/${folder}.$j.list" > "/tmp/${folder}.$j.list.tmp"
        mv "/tmp/${folder}.$j.list.tmp" "/tmp/${folder}.$j.list"
	      if [[ $(cat "/tmp/${folder}.$j.list" | wc -l) -gt 0 ]]
	      then
	        articles2cas -i "${PDF_DIR}/${folder}" -l "/tmp/${folder}.$j.list" -t 1 -o "${folder}" -p | grep -o -e "AGRKB:[0-9]*" > "/tmp/${folder}.$j.processed" &
	      fi
	    done
	    wait
	  done
	  # gzip all tpcas files
	  find "${folder}" -name "*tpcas" -print0 | xargs -0 -n 8 -P 8 pigz 2>/dev/null
	  rm -f /tmp/"${folder}".*.list
  done
  rm ${LOCKFILE}
fi
