#!/bin/bash

config=$( realpath config/default.json )

log(){
	echo "$(date +"%Y-%m-%dT%H:%M:%S%:z") | $1 | $2"
	if [ $1 = "ERROR" ]; then
		exit
	fi
}

log "INFO" "UPDATE CID-BLOCKLIST STARTED"
log "INFO" "Using config file: $config"

if [[ ! -f "$config" ]]; then
	log "ERROR" "Config file missing!"
fi

if [[ ! $(jq '.' $config) ]]; then
	log "ERROR" "Config file does not contain valid json data."
fi

rawDataFolder=$( jq -r '.cid_blocklist.dataFolder' $config )
rawLocalFile=$( jq -r '.cid_blocklist.localFile' $config )
source=$( jq -r '.cid_blocklist.source' $config )
remoteFile=$( jq -r '.cid_blocklist.remoteFile' $config )

if [ "$rawDataFolder" = "null" ] || [ "$rawLocalFile" = "null" ] || [ "$remoteFile" = "null" ] || [ "$source" = "null" ] || ( [ ! "$source" = "remote" ] && [ ! "$source" = "local" ] && [ ! "$source" = "both" ] ); then
	log "WARNING" "Config file different than expected!"
	echo "Expected:"
	echo -n "\"cid_blocklist\": "
	jq '.cid_blocklist' 'config/default.example.json'
	echo "Got:"
	echo -n "\"cid_blocklist\": "
	jq '.cid_blocklist' $config
	log "ERROR" "Missing or invalid parameter in config file (see above)!"
fi

dataFolder=$( realpath $rawDataFolder )
dataFolderTEMP="${dataFolder}_TEMP"
localFile=$( realpath $rawLocalFile )

log "INFO" "Preparing folder structure"
rm -rf $dataFolderTEMP
mkdir $dataFolderTEMP
for i in {0..255}; do mkdir $dataFolderTEMP/$(printf "%02x" $i); done

if [ $source = 'remote' ]; then
	log "INFO" "Generating cid-blocklist using remote data from ${remoteFile}"
	{ curl -sN $remoteFile | grep "^//" | sed 's/\/\///g' ; } | while read -r line; do echo "$line" >> $dataFolderTEMP/${line:0:2}/${line:0:4}; done
fi

if [ $source = 'local' ]; then
	log "INFO" "Generating cid-blocklist using local data from ${localFile}"
	{ cat $localFile 2>/dev/null ; } | while read -r line; do echo "$line" >> $dataFolderTEMP/${line:0:2}/${line:0:4}; done
fi

if [ $source = 'both' ]; then
	log "INFO" "Generating cid-blocklist using remote data from ${remoteFile} including local data from ${localFile}"
	{ curl -sN $remoteFile | grep "^//" | sed 's/\/\///g' ; cat $localFile 2>/dev/null ; } | while read -r line; do echo "$line" >> $dataFolderTEMP/${line:0:2}/${line:0:4}; done
fi

echo "$(date +"%Y-%m-%dT%H:%M:%S%:z")" > $dataFolderTEMP/version
echo ""

log "INFO" "Overwriting data folder with temp data folder"
rsync -ac --delete "$dataFolderTEMP/" "$dataFolder/"
rm -rf $dataFolderTEMP

log "INFO" "cid-blocklist now counts $(find $dataFolder -type f -exec cat {} + | wc -l) records."

log "INFO" "cid-blocklist updated!"
log "INFO" "UPDATE CID-BLOCKLIST ENDED"
