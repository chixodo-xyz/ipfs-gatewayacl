#!/bin/bash

config=$( realpath config/default.json )

log(){
	echo "$(date +"%Y-%m-%dT%H:%M:%S%:z") | $1 | $2"
	if [ $1 = "ERROR" ]; then
		exit
	fi
}

log "INFO" "UPDATE PINSET STARTED"
log "INFO" "Using config file: $config"

if [[ ! -f "$config" ]]; then
	log "ERROR" "Config file missing!"
fi

if [[ ! $(jq '.' $config) ]]; then
	log "ERROR" "Config file does not contain valid json data."
fi

rawDataFolder=$( jq -r '.pinset_filter.dataFolder' $config )

if [ "$rawDataFolder" = "null" ]; then
	log "WARNING" "Config file different than expected!"
	echo "Expected:"
	echo -n "\"pinset_filter\": "
	jq '.pinset_filter' 'config/default.example.json'
	echo "Got:"
	echo -n "\"pinset_filter\": "
	jq '.pinset_filter' $config
	log "ERROR" "Missing or invalid parameter in config file (see above)!"
fi

dataFolder=$( realpath $rawDataFolder )
dataFolderTEMP="${dataFolder}_TEMP"

log "INFO" "Preparing folder structure"

rm -rf $dataFolderTEMP
mkdir $dataFolderTEMP

log "INFO" "Generating pinset using local pins"
{ ipfs pin ls -q -t recursive | ipfs cid base32 ; } | while read -r line; do mkdir -p $dataFolderTEMP/${line:0:8}; echo "$line" >> $dataFolderTEMP/${line:0:8}/${line:0:10}; done
echo "$(date +"%Y-%m-%dT%H:%M:%S%:z")" > $dataFolderTEMP/version

log "INFO" "Overwriting data folder with temp data folder"
rsync -ac --delete "$dataFolderTEMP/" "$dataFolder/"
rm -rf $dataFolderTEMP

log "INFO" "pinset now counts $(find $dataFolder -type f -exec cat {} + | wc -l) records."

log "INFO" "pinset updated!"
log "INFO" "UPDATE PINSET ENDED"
