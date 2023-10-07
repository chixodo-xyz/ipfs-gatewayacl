#!/bin/bash

# Preparation
repoDir=`realpath "$(dirname $0)/.."`
cd $repoDir
mode=$1
if [ -z $mode ] ; then
	mode="default"
fi

# Print Help Page
if [[ $mode == "help" ]] ; then
	printf "Tutorial...\n"
	exit
fi

printf "\033[33;1mUse with caution!\n\033[0m"
printf "\033[0;33mThis will overwrite current .dev-environment (including IPFS Repository) and OpenResty Nginx config (/opt/openresty/nginx/conf/nginx.conf).\n\033[0m"
while true; do
  read -r -p "Do you want to continue? (yes|No) " answer
  case $answer in
    [Yy]* ) break;;
    [Nn]* ) exit;;
	"" ) exit;;
    * ) echo "Please answer yes or no.";;
  esac
done

# Setup IPFS
printf "We need higher priviledges to run some of the commands.\nPlease enter PW to authorize usage of sudo.\n"
sudo systemctl stop ipfs-dev
sudo rm -rf .dev-environment
mkdir .dev-environment && cd "$_"

printf "\033[34;1mPrepare IPFS (Kubo)\n\033[0m"
git clone https://github.com/ipfs/kubo && cd kubo
KuboVersion=$(git describe --tags --abbrev=0)
printf "\033[34;1mBuild Kubo %s (%s)\n\033[0m" ${KuboVersion} $(git describe --long --tags --abbrev=7 --match="v*" HEAD | sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g')
git config advice.detachedHead false
git checkout ${KuboVersion} -f
make build
cp cmd/ipfs/ipfs ../ipfs
cd ../..

printf "\033[34;1mConfigure IPFS...\n\033[0m"
export IPFS_PATH=$repoDir/.dev-environment/ipfs-repo
.dev-environment/ipfs init
.dev-environment/ipfs config --json Gateway.PublicGateways '{"localhost": {"UseSubdomains": true,"InlineDNSLink": true,"Paths": ["/ipfs","/ipns"]}}'
.dev-environment/ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '["PUT","POST"]'
.dev-environment/ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["http://localhost:5001","https://webui.ipfs.io"]'
.dev-environment/ipfs config --json Swarm.ConnMgr '{"Type": "basic","LowWater": 10,"HighWater": 30,"GracePeriod": "20s"}'

if [[ $mode == "chixodo_only" ]] ; then
  printf "Modify IPFS-Configuration to connect to Chixodo Nodes only."
  .dev-environment/ipfs bootstrap rm --all
  .dev-environment/ipfs config --json Swarm.AddrFilters "$(cat 'helpers/addrfilters-chixodo_only.json')"
else
  .dev-environment/ipfs bootstrap add /ip4/185.143.45.58/tcp/4001/p2p/12D3KooWPE1U1x31QteygQ7a34tzqx5FFJ3B5ttrfWjAqTn8kHo1
  .dev-environment/ipfs bootstrap add /ip4/195.15.245.11/tcp/4001/p2p/12D3KooWRHKJzo1ajNGBJnjeaunXXL9jNkEwsEi32KHMQkS5pm3t
  .dev-environment/ipfs config --json Swarm.AddrFilters "$(cat 'helpers/addrfilters.json')"
fi

sed -e "s|<user>|$(whoami)|g" -e "s|<repo>|$repoDir|g" helpers/ipfs-dev.service > .dev-environment/ipfs-dev.service
sudo cp .dev-environment/ipfs-dev.service /lib/systemd/system/ipfs-dev.service

printf "\033[34;1mStart IFPS Deamon...\n\033[0m"
sudo systemctl daemon-reload
sudo systemctl start ipfs-dev

while true; do
  printf "waiting for IPFS to start...\n"
  sleep 2
  .dev-environment/ipfs swarm connect /dnsaddr/chixodo.xyz &>/dev/null
  if [ $? -eq 0 ]; then
    break;
  fi
done

printf "\033[0;36m\nIPFS Configuration done. You can test it using:\n\033[0m"
printf "http://localhost:8080/ipfs/QmcniBv7UQ4gGPQQW2BwbD4ZZHzN3o3tPuNLZCbBchd1zh\n"
printf "http://localhost:5001/webui\n"

# Setup OpenResty
printf "\033[34;1m\nPrepare OpenResty\n\033[0m"
sudo pamac install openresty

printf "\033[34;1mCopy lua libraries...\n\033[0m"
sudo cp lib/*.lua /lib/lua/5.1/

printf "\033[34;1mGenerate ssl certificate...\n\033[0m"
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj '/CN=IPFS-Gateway-ACL' -keyout .dev-environment/ssl-fallback.key -out .dev-environment/ssl-fallback.crt 
sed -e "s|<user>|$(whoami)|g" -e "s|<repo>|$(pwd)|g" helpers/nginx-dev.conf > .dev-environment/nginx-dev.conf

printf "\033[34;1mApply OpenResty Nginx Config...\n\033[0m"
sudo cp /opt/openresty/nginx/conf/nginx.conf /opt/openresty/nginx/conf/nginx.conf.$(date +"%s").backup
sudo cp .dev-environment/nginx-dev.conf /opt/openresty/nginx/conf/nginx.conf

printf "\033[34;1mStart OpenResty Deamon...\n\033[0m"
sudo systemctl daemon-reload
sudo systemctl start openresty

printf "\033[0;36m\nOpenResty Configuration done. You can test it using:\n\033[0m"
printf "https://localhost/ipfs/QmcniBv7UQ4gGPQQW2BwbD4ZZHzN3o3tPuNLZCbBchd1zh\n"
printf "https://localhost/ipfs/QmeomffUNfmQy76CQGy9NdmqEnnHU9soCexBnGU3ezPHVH\n"

printf "\n\033[37;1mControl dev-environment using:\n\033[0m"
printf "bash scripts/start-dev.sh\n"
printf "bash scripts/stop-dev.sh\n"
printf "bash scripts/restart-dev.sh\n"