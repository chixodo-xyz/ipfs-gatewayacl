#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

if [ -z "$1" ] || [ $1 = "ipfs" ]; then
  echo "stopping ipfs..."
  systemctl stop ipfs-dev
  sleep 1
fi

if [ -z "$1" ] || [ $1 = "openresty" ]; then
  echo "stopping openresty..."
  systemctl stop openresty
  sleep 1
fi

echo "Development Environment stopped."