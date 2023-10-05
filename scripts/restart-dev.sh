#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

$(dirname "$0")/stop-dev.sh $1
$(dirname "$0")/start-dev.sh $1
