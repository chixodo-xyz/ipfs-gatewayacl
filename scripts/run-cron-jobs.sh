#!/bin/bash

$(dirname "$0")/update-pinset.sh
$(dirname "$0")/update-cid-blocklist.sh
$(dirname "$0")/rotate-log.sh