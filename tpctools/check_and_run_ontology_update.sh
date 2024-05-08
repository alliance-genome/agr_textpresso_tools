#!/usr/bin/env bash

# Calculate the day of the month
day_of_month=$(date +%d)

# Calculate the weekday (Tuesday is 2)
weekday=$(date +%u)

if [ "$weekday" -eq 2 ]; then
    if [ "$day_of_month" -le 7 ]; then
        # It's the first Tuesday of the month, run the main script
        /bin/bash /data/textpresso/tpctools/update_ontology.sh >& /tmp/update_ontology.log &
    fi
fi
