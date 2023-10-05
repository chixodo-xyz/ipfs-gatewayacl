#!/bin/bash

printf "\033[34;1mDetecting System Configuration\n\033[0m"

if [ $(which nginx) ] ; then
	nginxservice=`systemctl status openresty | grep enabled`
	: "${nginxservice:=disabled}"
	printf "Nginx installed (Service: %s): %s\n" "$nginxservice" "`nginx -v 2>&1`"
else
	printf "\033[0;33mNginx not installed.\n\033[0m"
fi

if [ $(which openresty) ] ; then
	openrestyservice=`systemctl status openresty | grep enabled`
	: "${openrestyservice:=disabled}"
	printf "Openresty installed (Service: %s): %s\n" "$openrestyservice" "`openresty -v 2>&1`"
else
	printf "\033[0;33mOpenresty not installed.\n\033[0m"
fi

printf "\033[34;1mCreate Package\n\033[0m"
