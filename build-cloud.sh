#!/usr/bin/env bash
rsync -a /home/mueller/work/swd/textpressocentral .
rsync -a /home/mueller/work/swd/tpctools .
rsync -a /home/mueller/work/swd/textpressoapi .
docker build --no-cache -f Dockerfile-cloud -t $1 .
rm -rf textpressocentral tpctools textpressoapi
