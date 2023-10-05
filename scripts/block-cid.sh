#!/bin/bash

config=$( realpath config/default.json )
cidParam=$1

if [ -z $cidParam ]; then
	echo "ERROR: Parameter missing! Provide CID or CID/path as first parameter."
	exit
fi

echo "INFO: Using config file: $config"

if [[ ! -f "$config" ]]; then
	echo "ERROR: Config file missing!"
	exit
fi

if [[ ! $(jq '.' $config) ]]; then
	echo "ERROR: Config file does not contain valid json data."
	exit
fi

rawLocalFile=$( jq -r '.cid_blocklist.localFile' $config )
source=$( jq -r '.cid_blocklist.source' $config )
remoteFile=$( jq -r '.cid_blocklist.remoteFile' $config )

if [ "$rawLocalFile" = "null" ] || [ "$remoteFile" = "null" ] || [ "$source" = "null" ] || ( [ ! "$source" = "remote" ] && [ ! "$source" = "local" ] && [ ! "$source" = "both" ] ); then
	echo "WARNING: Config file different than expected!"
	echo "Expected:"
	echo -n "\"cid_blocklist\": "
	jq '.cid_blocklist' 'config/default.example.json'
	echo "Got:"
	echo -n "\"cid_blocklist\": "
	jq '.cid_blocklist' $config
	echo "ERROR: Missing or invalid parameter in config file (see above)!"
	exit
fi

localFile=$( realpath $rawLocalFile )
localFileHistory="${localFile}.history"

cid=$(echo -n $(ipfs cid base32 $1))
path=$2

if [ -z "$path" ]; then
	deny=$cid
else
	deny="$cid/$path"
fi

sha256=$(echo -n $deny | sha256sum | awk '{print $1;}')

echo ""
echo "Provided CID: $1"
echo "Provided Path: $path"
echo ""
echo "base32 encoded cidv1: $cid"
echo ""
echo "Blocking: $deny"
echo "SHA256: $sha256"
echo ""

echo -e "$(date +"%Y-%m-%dT%H:%M:%S%z")\t$deny" >> $localFileHistory
if ! grep -Fxq "$sha256" $localFile; then
	echo "$sha256" >> $localFile
fi

echo "Don't forget to run: scripts/update-cid-blocklist.sh"