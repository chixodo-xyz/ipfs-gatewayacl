#!/bin/bash

config=$( realpath config/default.json )

log(){
	echo "$(date +"%Y-%m-%dT%H:%M:%S%:z") | $1 | $2"
	if [ $1 = "ERROR" ]; then
		exit
	fi
}

log "INFO" "ROTATE LOG STARTED"
log "INFO" "Using config file: $config"

if [[ ! -f "$config" ]]; then
	log "ERROR" "Config file missing!"
fi

if [[ ! $(jq '.' $config) ]]; then
	log "ERROR" "Config file does not contain valid json data."
fi

rawLogFile=$( jq -r '.logfile' $config )

if [ "$rawLogFile" = "null" ]; then
	log "WARNING" "Config file different than expected! Expected: <string>"
	log "ERROR" "Missing or invalid parameter in config file (see above)!"
fi

logFile=$( realpath $rawLogFile )

if [[ ! -f "$logFile" ]]; then
	log "WANRING" "Logfile doesn't exist."
else
	max_file_size=$((1024 * 1024 * 20)) # 20MB
	file_size=`du -b $logFile | tr -s '\t' ' ' | cut -d' ' -f1`
	log "INFO" "FileSize: $(bc <<< "scale=2; $file_size/1024/1024")MB"
  if [ $file_size -gt $max_file_size ];then
      timestamp=`date +%s`
      rm -f ${logFile}.9.gz
      for i in {8..1}; do
      	mv -f ${logFile}.${i}.gz ${logFile}.$(($i+1)).gz 2>/dev/null; true
      done
      mv -f ${logFile}.gz ${logFile}.1.gz 2>/dev/null; true
      gzip $logFile
      log "INFO" "LogFile rotated."
  else
  	log "INFO" "LogFile not being rotated because FileSize doesn't exceed $(bc <<< "scale=0; $max_file_size/1024/1024")MB"
  fi
fi

log "INFO" "ROTATE LOG ENDED"