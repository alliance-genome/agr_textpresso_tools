#!/usr/bin/env bash

function usage {
    echo "this script indexes all papers in the CAS2_DIR."
    echo
    echo "usage: $(basename $0) [-Cih]"
    echo "  -C --cas2-dir     directory where cas2 files are stored"
    echo "  -i --index-dir    directory for the lucene index"
    echo "  -h --help         display help"
    rm ${LOCKFILE}
    exit 1
}

CAS2_DIR="/data/textpresso/tpcas-2"
INDEX_DIR="/data/textpresso/luceneindex"
PAPERS_PER_SUBINDEX=1000000
LOCKFILE="/data/textpresso/tmp/12index.lock"
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
	    -C|--cas2-dir)
		shift
		CAS2_DIR="$1"
		shift
		;;
	    -i|--index-dir)
		shift
		INDEX_DIR="$1"
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
    
    #################################################################################
    #####                     6. INDEX PAPERS                                   #####
    #################################################################################
    
    echo "Updating index ..."
    export INDEX_PATH=${INDEX_DIR}
    INDEX_DIR_CUR="${INDEX_DIR}"
    if [[ -d ${INDEX_DIR} && $(ls ${INDEX_DIR} | grep -v "subindex_0" | wc -l) != "0" ]]
    then
	INDEX_DIR_CUR="${INDEX_DIR}_new"
    fi
    mkdir -p "${INDEX_DIR_CUR}/db"
    create_single_index.sh -m 10000 ${CAS2_DIR} ${INDEX_DIR_CUR}
    cd "${INDEX_DIR_CUR}"
    num_subidx_step=$(echo "${PAPERS_PER_SUBINDEX}/10000" | bc)
    first_idx_in_master=0
    final_counter=0
    last_idx_in_master=${num_subidx_step}
    num_subidx=$(ls | grep "subindex_" | wc -l)
    found="0"
    while [[ ${found} == "0" ]]
    do
	if [[ ${last_idx_in_master} -ge ${num_subidx} ]]
	then
            last_idx_in_master=${num_subidx}
            found="1"
	fi
	for ((i=$((first_idx_in_master + 1)); i<=$((last_idx_in_master-1)); i++))
	do
            indexmerger subindex_${first_idx_in_master} subindex_${i} no
            rm -rf subindex_${i}
	done
	if [[ "subindex_${first_idx_in_master}" != "subindex_${final_counter}" ]]
	then
            mv subindex_${first_idx_in_master} subindex_${final_counter}
	fi
	first_idx_in_master=$((first_idx_in_master + num_subidx_step))
	last_idx_in_master=$((last_idx_in_master + num_subidx_step))
	final_counter=$((final_counter + 1))
    done
    ## merging subindex_0 under /data/textpresso/luceneindex_new to
    ## subindex_0 under /data/textpresso/luceneindex
    ## then saveidstodb -i ${INDEX_DIR}
    cp -fr "${INDEX_DIR_CUR}/subindex_0" "${INDEX_DIR}/subindex_1"
    cd "${INDEX_DIR}"
    indexmerger subindex_0 subindex_1 no
    rm -rf subindex_1
    saveidstodb -i "${INDEX_DIR}"
    chmod -R 777 "${INDEX_DIR}/db"
    
    ## update cc.cfg file
    ccFileCurr="${INDEX_DIR}/cc.cfg"
    ccFileNew="${INDEX_DIR_CUR}/cc.cfg" 
    ccFileCurr_content=$(<"${ccFileCurr}")
    ccFileNew_content=$(<"${ccFileNew}") 
    number1=$(echo "$ccFileCurr_content" | awk '{print $NF}')
    number2=$(echo "$ccFileNew_content" | awk '{print $NF}')
    new_number=$((number1 + number2))
    updated_content=$(echo "$ccFileCurr_content" | sed "s/$number1/$new_number/")
    echo "$updated_content" > "${ccFileCurr}"

    fi
    rm ${LOCKFILE}
fi
