#!/bin/bash

hostname=$1
note=$2
verbose=$3
attempts=2
samples=200

if [ -z $hostname ]; then
	echo "ERROR: Parameter missing! Provide hostname as first parameter."
	exit
fi

if [ -z $note ]; then
	echo "ERROR: Parameter missing! Provide note as second parameter."
	exit
fi

#testurl="https://bafybeihuvwfdxuyytwrk3ee64qiurvujhwggfhcbb57sy7r7vz22vxtzza.ipfs.${hostname}" #200.txt
testurl="https://k51qzi5uqu5dj1f42xq0srxvfg1l3mn13xzgllamrup0fa2ihozoi3143dk2yt.ipns.${hostname}/" #200.txt via ipns
#testurl="https://200-ttlf-ch.ipns.localhost" #200.txt via ipns dnslink
#testurl="https://en-wikipedia--on--ipfs-org.ipns.${hostname}/wiki/"
#testurl="http://chixodo-xyz.ipns.localhost/"
echo "URL: $testurl"
echo "Number of Attempts: $attempts"
echo "Number of Samples per Attempt: $samples"

i=0; sumt=0; mint=9999; maxt=0; avgt=0
while [ $i -lt $attempts ]; do
	j=0; sum=0; min=9999; max=0; avg=0
	while [ $j -lt $samples ]; do
		v=`curl -s -I --insecure -H "X-Debug-PerformanceTest: true" $testurl | grep -Fi X-debug-ValuationDuration | sed -r 's/.*: (.*)/\1/' | tr -d $'\r'`
		if [ ! -z $verbose ]; then
			echo $v
		fi
		sum=$(echo "$sum + $v" | bc)
		sumt=$(echo "$sumt + $v" | bc)
		if [[ $min > $v ]]; then
			min=$v
		fi
		if [[ $max < $v ]]; then
			max=$v
		fi
		if [[ $mint > $v ]]; then
			mint=$v
		fi
		if [[ $maxt < $v ]]; then
			maxt=$v
		fi
		j=$(( $j + 1 ))
	done
	avg=$(echo "scale=8; $sum/$samples" | bc)
	echo "Attempt $i: ${avg}s (avg), ${min}s (min), ${max}s (max)"
	echo "$hostname;$note;$attempts;$samples;$i;$avg;$min;$max" >> $(dirname "$0")/performance-test-result.csv
	i=$(( $i + 1 ))
done
avgt=$(echo "scale=8; $sumt/$attempts/$samples" | bc)
echo "Total: ${avgt}s (avg), ${mint}s (min), ${maxt}s (max)"
