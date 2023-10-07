# IPFS Gateway ACL

>This code is still a prototype! 
>1. not properly tested or audited
>2. Origin_filter does not make sense with direct because it will never have a referer or origin...
>3. IPNS speed reduced when using dnslink

## Requirements

- Linux OS (tested on Arch)
- Nginx with Lua Support (tested with OpenResty)
- IPFS (tested with Kubo)
- bash, jq, rsync, cron, curl, grep, sed

## Policies (config/default.json)

This ACL implements different policies. Each type of policy can be enabled or disabled. If the request violates one of the policies the status code 403 is returned. The following policies are available (in order of checking):

1. pinset_filter
  - Filter requests that are pinned on host
  - *optional=false:* requires request to be pinned, otherwise 403 will be returned; can be combined with overwrites.
  - *optional=true:* request has not to be pinned, but pinned requested cid can overwrite other policies; therefore it only makes sense in combination with at least one of the overwrites
  - *overwrite:* use to overwrite other policies; so that if pinset contains requested pin the desired policy will not be valuated.
2. origin_filter: 
  - valid hostnames for specific types of request (use lua match expression)
  - *direct:* user-originated request (no origin) (f.E. entering address in address bar)
  - *same_origin:* same-origin request (f.E. navigating on webpage)
  - *user_initiated_top_level:* user initiated top level cross-site request (f.E. clicking a link on an external page)
  - *cross_site:* other cross-site request
3. cid_blocklist: 
  - list of cid to be blocked (generated by `scripts/update-cid-blocklist.sh`)
  - *local / remote / both:* load blocklist from local file (generated by `scripts/block-cid.sh`), badbits (by ipfs) or both.

## Implementation (untested)

>Follow this information to implement IPFS Gateway ACL to existing Gateway.

0. Prerequirements

>Make sure you use nginx with support for LUA filter. Easiest (for Arch-Linux) is to use Openresty as proxy (see [Development Environment](#development-environment)). Alternatively you can use a lua-module for nginx. For example in debian based distros:

```bash
apt install nginx libnginx-mod-http-lua
echo "load_module modules/ngx_http_lua_module.so;"  > /etc/nginx/modules-enabled/50-mod-http-lua.conf
sudo systemctl restart nginx
```

1. Clone Repo to /usr/share/IPFS-Gateway-ACL

```bash
cd /usr/share
git clone https://github.com/chixodo-xyz/ipfs-gateway-acl.git
cd IPFS-Gateway-ACL
```

2. Install LUA dependencies

```bash
sudo cp helpers/lib/*.lua /opt/openresty/site/lualib/

# Alternative for nginx with lua-module:
# sudo mkdir -p /usr/share/lua/5.1/
# sudo helpers/lib/*.lua /usr/share/lua/5.1/
```


3. include nginx.conf to nginx virtual host (section server)

```bash
sudo nano /opt/openresty/nginx/conf/nginx.conf
#ADD to every server section:>
  include /usr/share/ipfs-gateway-acl/nginx.conf;

# Alternative for nginx with lua-module:
# nano /etc/nginx/sites-available/[ipfs-host-config].conf
# #ADD to every server section:>
#  include /usr/share/IPFS-Gateway-ACL/nginx.conf;
```

4. Generate denylist by dwebops 

```bash
bash scripts/update-denylist.sh
#for Testing: 
bash scripts/deny-cid.sh QmcniBv7UQ4gGPQQW2BwbD4ZZHzN3o3tPuNLZCbBchd1zh
bash scripts/update-denylist.sh
```

>Remember to remove customdeny after testing: `rm customdeny.txt ; ./update-denylist.sh`

5. Activate change

```bash
nginx -t
service nginx restart
```

6. Setup Cron to Update denylist
```bash
crontab -e
ADD:>
*/20 * * * * cd /usr/share/ipfs-denylist && ./update-denylist.sh
```


## Development Environment

Use the `scripts/setup-dev.sh` to setup local development environment on arch based linux.

>We compile kubo manually that we can install go plugins and such if needed.

```bash
#normal dev environment
bash scripts/setup-dev.sh

#limited dev environment (connect only to chixodo nodes)
bash scripts/setup-dev.sh chixodo_only
```


## Credits:

- CID/Multicode/Multihash Implementation: https://github.com/filecoin-project/lua-filecoin
- SHA2 Implementation: https://github.com/Egor-Skriptunoff/pure_lua_SHA
- JSON Implementation: https://github.com/rxi/json.lua
- Tiny Logging Module: https://github.com/rxi/log.lua