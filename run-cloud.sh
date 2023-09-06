#!/usr/bin/env bash
mkdir -p /data/textpresso/textpressoapi_data
mkdir -p /data/textpresso/postgres
ln -s /usr/local/bin/tai.sh /usr/local/bin/convert_text
ln -s /usr/local/bin/03pdf2cas4tai.sh /usr/local/bin/tokenize
ln -s /usr/local/bin/07cas1tocas2.sh /usr/local/bin/annotate
ln -s /usr/local/bin/12index.sh /usr/local/bin/index
createdb "www-data"; zcat stopwords.postgres.tar.gz | pg_restore -d "www-data" 
/root/run.sh -p
/root/run.sh -l &
/root/run.sh -w
/root/run.sh -i
