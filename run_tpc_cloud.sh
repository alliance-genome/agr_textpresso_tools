#!/bin/bash
docker run --restart always -d -p $2:80 -p $3:18080 -v $1:/data/textpresso cloud-tpc
