#!/usr/bin/env bash

function usage {
    echo "This script sets up Textpresso Central."
    echo
    echo "usage: $(basename $0) [-tpldwsciah]"
    echo "  -t       Compile Textpresso Central"
    echo "  -p       Start postgres and load www-data database"
    echo "  -l       Create lexica"
    echo "  -d       dump www-data database"
    echo "  -w       Start webserver"
    echo "  -c       Setup cronjobs"
    echo "  -i       stay idle"
    echo "  -a       equivalent to -t -p -l -w -c (do all)"
    echo "  -h       Display help"
    exit 1
}

function make_tpc() {
    if [[ ! -e /usr/local/bin/tpc ]]
    then
	rm -rf /data/textpresso/textpressocentral/build
    fi
    if [[ -d /data/textpresso/textpressocentral ]]
    then
	cd /data/textpresso/textpressocentral
	mkdir -p build; cd build
	cmake -DCMAKE_BUILD_TYPE=Release ..
	make -j 8 && make install
	/usr/local/bin/tpctl.sh activate
	/usr/local/bin/tpctl.sh set_literature_dir /data/textpresso
    fi
    if [[ ! -e /usr/local/bin/articles2cas ]]
    then
	rm -rf /data/textpresso/tpctools/build
    fi
    if [[ -d /data/textpresso/tpctools ]]
    then
	cd /data/textpresso/tpctools
	mkdir -p build; cd build 
	cmake -DCMAKE_BUILD_TYPE=Release ..
	make -j 8 && make install
    fi
    if [[ ! -e /usr/local/bin/textpressoapi ]]
    then
	rm -rf /data/textpresso/textpressoapi/build
    fi
    if [[ -d /data/textpresso/textpressoapi ]]
    then
	mkdir -p /data/textpresso/textpressoapi_data
	cd /data/textpresso/textpressoapi
	mkdir -p build; cd build
	cmake -DCMAKE_BUILD_TYPE=Release ..
	make -j 8 && make install
    fi
}

function set_postgres() {
    service postgresql start
    sudo -u postgres createuser -s root 2>/dev/null
    createuser textpresso
    createuser mueller
    createuser "www-data"
    createdb "www-data"
    RETRIES=5
    until psql -d "www-data" -c "select 1" > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
	echo "Waiting for postgres server, $((RETRIES--)) remaining attempts..."
	sleep 10
    done
    if [ -e /data/textpresso/postgres/www-data.tar.gz ]
    then
	unpigz /data/textpresso/postgres/www-data.tar.gz
	pg_restore -d "www-data" /data/textpresso/postgres/www-data.tar
        pigz /data/textpresso/postgres/www-data.tar
    fi
 }

function create_lexica() {
    RETRIES=5
    until psql -d "www-data" -c "select 1" > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
	echo "Waiting for postgres server, $((RETRIES--)) remaining attempts..."
	sleep 10
    done
    psql -d "www-data" -c "select 1" >/dev/null 2>&1
    if [[ $? == 0 ]]
    then
	CreateLexica.bash
   fi
}

function dump_database() {
    dump.sh
}

function start_webserver() {
    mkdir /usr/wt; touch /usr/wt/socket
    chmod 777 -R /usr/wt;
    ln -s /usr/local/lib/Tpcas2TpCentral.so /usr/lib/.
    service lighttpd start
    nohup textpressoapi -d /data/textpresso/textpressoapi_data/tokens.db &>/data/textpresso/textpressoapi_data/api.log&
    service postfix start
    service rsyslog start
    /root/run.sh -c
}

function setup_cronjobs() {
    cronfile=$(mktemp)
    if [[ -e /usr/local/bin/tpc ]]
    then
	cat /usr/local/etc/cronfile4tpc >> $cronfile
    fi
    # add more cronfile4... here if necessary
    if [[ -s $cronfile ]]
    then
       echo >> $cronfile
       cat $cronfile | crontab -
       cron
    fi
    rm $cronfile
}

function idling() {
    tail -f /dev/null
}

BASE_DIR="/data/textpresso/"
tflag=0
pflag=0
lflag=0
dflag=0
wflag=0
cflag=0
iflag=0
aflag=0

while [[ $# -gt 0 ]]
do
key=$1

case $key in
    -t)
    shift
    tflag=1
    ;;
    -p)
    shift
    pflag=1
    ;;
    -l)
    shift
    lflag=1
    ;;
    -d)
    shift
    dflag=1
    ;;
    -w)
    shift
    wflag=1
    ;;
    -c)
    shift
    cflag=1
    ;;
    -i)
    shift
    iflag=1
    ;;
    -a)
    shift
    aflag=1
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

#################################################################################

if [[ $(($tflag + $aflag)) > 0 ]]
then
    echo "Compiling Textpresso Central..."
    make_tpc
fi
if [[ $(($pflag + $aflag)) > 0 ]]
then
    echo "Starting and loading postgres..."
    set_postgres
fi
if [[ $(($lflag + $aflag)) > 0 ]]
then
    echo "Creating lexica..."
    create_lexica
fi
if [[ $(($dflag + $aflag)) > 0 ]]
then
    echo "Dumping www-data database..."
    dump_database
fi
if [[ $(($wflag + $aflag)) > 0 ]]
then
    echo "Starting webserver..."
    start_webserver
fi
if [[ $(($cflag + $aflag)) > 0 ]]
then
    echo "Setting up cronjobs..."
    setup_cronjobs
fi
if [[ $(($iflag + $aflag)) > 0 ]]
then
    echo "idling..."
    idling
fi
