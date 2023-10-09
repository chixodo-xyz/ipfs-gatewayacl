-- performance measure start
local starttime = os.clock()

-- libraries
local sha = require "sha2"
local cidlib = require "cid"
local json = require "json"
local tinylogger = require "log"

-- prepare global variables
local host = ngx.var.host
local requesturi = ngx.var.request_uri
local scheme = ngx.var.scheme
local statuscode = 200
local statusmessage = "OK"
local config, cidstr, path, resolutionStyle, headers = ""
local mode = "ipfs"

-- functions
function string.starts(String,Start)
  return string.sub(String,1,string.len(Start))==Start
end

local function readAll(file)
  local f = io.open(file, "r")
  if f~=nil then
    local content = f:read("*all")
    f:close()
    return content
  else
    return ""
  end
end

local function write(file, content)
  local f = io.open(file, "w")
  io.output(f)
  io.write(content)
  io.close(f)   
end

local function exists(file)
  local ok, err, code = os.rename(file, file)
  if not ok then
    if code == 13 then
       -- Permission denied, but it exists
       return true
    end
  end
  return ok, err
end

local function isdir(path)
  return exists(path.."/")
end

local function ternary ( cond , T , F )
  if cond then return T else return F end
end

local function absPath (p)
  return ternary(not string.starts(p, "/"), ngx.var.ipfs_gatewayacl_root .. "/", "") .. p
end

local function getServerHostname()
    local f = io.popen ("/bin/hostname")
    local hostname = f:read("*a") or ""
    f:close()
    hostname =string.gsub(hostname, "\n$", "")
    return hostname
end

local function log(z, a, b, c)
  -- Log to nginx error log
  -- Expected parameter options:
  -- [boolean]DisplayTrace, [number]LogLevel, [string]Message, [*]Data
  -- [number]LogLevel, [string]Message, [*]Data
  -- [string]Message, [*]Data
  -- [*]Data
  -- 
  -- Default Values:
  -- DisplayTrace = true
  -- LogLevel = ngx.ERR
  -- Message = ""
  -- Data = ""
  -- 
  -- Examples:
  -- log(false, ngx.Debug, "Debugging Variable x. Content is: ", x)
  -- log(ngx.CRIT, "Recieved data invalid:", data)
  -- log("Unexpected error occured:", err)

  local data = ""
  local trace = ""
  local lvl = ""
  local msg = ""
  if type(z) ~= "boolean" then
    c = b
    b = a
    a = z
    z = true
  end
  if z then
    trace = " - " .. debug.traceback()
  end

  if(type(a) == "number" and type(b) == "string") then
    -- default: level, message, (additional-data)
    if c then data = json.encode(c) end
    lvl, msg = a, b .. data .. trace
  elseif(type(a) == "number" and type(b) ~= "string") then
    -- non-msg: level, additional-data
    if b then data = json.encode(b) end
    lvl, msg = a, data .. trace
  elseif(type(a) == "string") then
    -- no-lvl: message, (additional-data)
    if b then data = json.encode(b) end
    lvl, msg = ngx.ERR, a .. data .. trace
  else
    -- only data
    if a then data = json.encode(a) end
    lvl, msg = ngx.ERR, data .. trace
  end

  -- log to nginx default log (ipfs-gateway-acl.nginx.conf defines to log only level warn and higher)
  ngx.log(lvl, msg)

  -- log to ipfs-gateway-acl logfile if set
  if config.logfile then
    if ( lvl == ngx.DEBUG and config.debug ) then tinylogger.debug(msg)
    elseif lvl == ngx.INFO then tinylogger.info(msg)
    elseif lvl == ngx.NOTICE then tinylogger.info(msg)
    elseif lvl == ngx.WARN then tinylogger.warn(msg)
    elseif lvl == ngx.ERR then tinylogger.error(msg)
    elseif lvl == ngx.CRIT then tinylogger.fatal(msg)
    elseif lvl == ngx.ALERT then tinylogger.warn(msg)
    elseif lvl == ngx.EMERG then tinylogger.warn(msg)
    end
  end
end

local function prepareResolutionStyles(host, requesturi)
  local cidstr = ""
  local path = ""
  local resolutionStyle = "path"
  -- Preparation for resolution styles
  if string.starts(requesturi, "/ipfs/") then
    -- IPFS Path resolution (cidv0 and cidv1 supported): /ipfs/<CID>
    cidstr = requesturi:gsub("^/ipfs/([^/]+)/?(.*)$", "%1")
    path = requesturi:gsub("^/ipfs/([^/]+)/?(.*)$", "%2")
  elseif string.match(host, "^[a-z0-9]+%.ipfs%..*$") then
    -- IPFS Subdomain resolution (only cidv1 supported): <CID>.ipfs.<hostname>
    cidstr = host:gsub("^([a-z0-9]+)%.ipfs%..*$", "%1")
    path = requesturi:gsub("^/(.*)$", "%1")
    resolutionStyle = "subdomain"
  elseif string.starts(requesturi, "/ipns/") then
    -- IPNS Path resolution (cidv0, cidv1 and dnslink supported): /ipns/<CID/DNSLINK>
    cidstr = requesturi:gsub("^/ipns/([^/]+)/?(.*)$", "%1")
    path = requesturi:gsub("^/ipns/([^/]+)/?(.*)$", "%2")
    mode = "ipns"
  elseif string.match(host, "^[^/^%.]+%.ipns%..*$") then
    -- IPNS Subdomain resolution (cidv1 and dnslink supported): <CID/DNSLINK>.ipfs.<hostname>
    cidstr = host:gsub("^([^/^%.]+)%.ipns%..*$", "%1")
    path = requesturi:gsub("^/(.*)$", "%1")
    resolutionStyle = "subdomain"
    mode = "ipns"
  else
    -- invalid request! 
  end
  return cidstr, path, resolutionStyle
end

local function harmonizeRequest(cidstr, path)
  -- harmonise request to format: <base32-encoded-cidv1-string>/<optional_path>
  local cid = ""
  if #cidstr == 46 and string.sub(cidstr, 1, 2) == 'Qm' then
    cid = cidlib.decodeV0(cidstr)
  else
    cid = cidlib.decodeV1(cidstr)
  end
  if cid.version == 0 then
    cid.version = 1
    cid.multibase = "base32"
    cidstr = cidlib.encode(cid)
  end
  if path ~= "" then
    return cidstr .. "/" .. path
  else
    return cidstr
  end
end

local function checkOrigin(headers, trusted_origins)
  local origin = ""
  if (headers["origin"] and headers["origin"] ~= "null") then
    -- proper embedded request (f.E. ajax)
    origin = headers["origin"]
  elseif (headers["Referer"] and headers["Referer"] ~= "null") then
    -- proper embedded request (f.E. iframe)
    origin = headers["Referer"]
  end

  log(false, ngx.DEBUG, "ORIGIN -> " .. origin)

  for k,v in pairs(trusted_origins) do 
    if (string.match(origin, v)) then
      return true
    end
  end
  return false
end

-- preparation
headers = ngx.req.get_headers()
cidstr, path, resolutionStyle = prepareResolutionStyles(host, requesturi)
config = json.decode(readAll(ngx.var.ipfs_gatewayacl_root .. "/config/default.json"))
if config.logfile then 
  if not isdir(absPath(config.logfile)) then
    os.execute("mkdir -p $(dirname " .. absPath(config.logfile) .. ")")
  end
  tinylogger.outfile = absPath(config.logfile)
end
log(false, ngx.INFO, "REQUEST INFORMATION -> scheme = " .. scheme .. " ; host = " .. host .. " ; requesturi = " .. requesturi .. " ; cidstr = " .. cidstr .. " ; path -> " .. path .. " ; headers -> ", headers)

-- write pre-debuging header
if config.debug then
  ngx.header['X-debug-trace_uid'] = ngx.var.trace_uid
  ngx.header['X-debug-HOST'] = host
  ngx.header['X-debug-RequestURI']= requesturi
end

-- 0. cid_check
if cidstr == "" then
  statuscode, statusmessage = 400, "CID missing"
  log(false, ngx.INFO, "CID_CHECK RESULT -> " .. statuscode .. " (" .. statusmessage .. ")")
end

if (config.ipns_cache and not isdir(absPath(config.ipns_cache))) then
  os.execute("mkdir -p " .. absPath(config.ipns_cache))
end

if mode == "ipns" then
  if resolutionStyle == "subdomain" then
    cidstr = cidstr:gsub("-", "."):gsub("%.%.", "-")
  end

  -- check if ipns exists in cache and is up to date
  local ipns_cache_file = absPath(config.ipns_cache) .. "/" .. sha.sha256(cidstr)
  if (exists(ipns_cache_file)
  and os.time() - io.popen("stat -c %Y " .. ipns_cache_file):read() <= 60) then
    cidstr = readAll(ipns_cache_file)
    mode = "ipfs"
    log(false, ngx.INFO, "CID_CHECK -> IPNS resolved from cache to: " .. cidstr)
  end

  if mode == "ipns" then
    -- try to resolve ipns
    local handle = io.popen("export IPFS_PATH=" .. absPath(config.ipfs_repo) .. " && export PATH=$PATH:/usr/bin && ipfs resolve /ipns/" .. cidstr)
    local result = handle:read("*a")
    handle:close()
    if string.starts(result, "/ipfs/") then
      cidstr = result:gsub("^/ipfs/(.*)", "%1"):gsub("[\n\r]","")
      write(ipns_cache_file, cidstr)
      mode = "ipfs"
      log(false, ngx.INFO, "CID_CHECK -> IPNS resolved to: " .. cidstr)
    end
  end
end

-- 1. pinset_filter

if (config.pinset_filter.enable and statuscode == 200 and mode == "ipfs") then
  local dataFolder = absPath(config.pinset_filter.dataFolder)
  local pinsetfile = dataFolder .. "/" .. cidstr:sub(0,8) .. "/" .. cidstr:sub(0,10)
  if not exists(dataFolder .. "/version") then
    statuscode, statusmessage = 503, "pinset datafolder not found."
    log(ngx.ERR, "ERROR: pinset datafolder not found! Check: " .. dataFolder)
  end
  if string.find(readAll(pinsetfile), cidstr) == 1 then
    statuscode, statusmessage = 202, "cid found in pinset"
  elseif config.pinset_filter.optional == false then
    statuscode, statusmessage = 403, "cid not found in pinset"
  end
  log(false, ngx.INFO, "PINSET_FILTER RESULT -> " .. statuscode .. " (" .. statusmessage .. ")")
end


-- 2. origin_filter

if (config.origin_filter.enable 
  and (statuscode == 200 or (statuscode == 202 and config.pinset_filter.overwrite.origin_filter == false))) then
  local policy = false
  if (type(config.origin_filter.policies.direct) ~= "table" or type(config.origin_filter.policies.same_origin) ~= "table" or type(config.origin_filter.policies.user_initiated_top_level) ~= "table" or type(config.origin_filter.policies.cross_site) ~= "table") then
    log(ngx.ERR, "ERROR in config: every element of origin_filter.policies must be table/array! Check: " .. ngx.var.ipfs_gatewayacl_root .. "/config/default.json")
    statuscode, statusmessage = 500, "Error in config origin_filter.policies"
  else
    if headers["sec-fetch-site"] == "none" or headers["sec-fetch-site"] == nil then
      -- user-originated request (no origin) (f.E. entering address in address bar)
      policy = config.origin_filter.policies.direct
      log(false, ngx.DEBUG, "ORIGIN_FILTER using policy: policies.direct")
    elseif (headers["sec-fetch-site"] == "same-origin" or headers["sec-fetch-site"] == "same-site") then
      -- same-origin request (f.E. navigating on webpage)
      policy = config.origin_filter.policies.same_origin
      log(false, ngx.DEBUG, "ORIGIN_FILTER using policy: policies.same_origin")
    elseif headers["sec-fetch-dest"] == "document" then
      -- user initiated top level cross-site request (f.E. clicking a link on an external page)
      policy = config.origin_filter.policies.user_initiated_top_level
      log(false, ngx.DEBUG, "ORIGIN_FILTER using policy: policies.user_initiated_top_level")
    else
      -- other cross-site request
      policy = config.origin_filter.policies.cross_site
      log(false, ngx.DEBUG, "ORIGIN_FILTER using policy: policies.cross_site")
    end
    if checkOrigin(headers, policy) == false then
      statuscode, statusmessage = 403, "cross-site origin missmatch"
    end
  end
  log(false, ngx.INFO, "ORIGIN_FILTER RESULT -> " .. statuscode .. " (" .. statusmessage .. ")")
end


-- 3. cid_blocklist

if (config.cid_blocklist.enable 
  and (statuscode == 200 or (statuscode == 202 and config.pinset_filter.overwrite.cid_blocklist == false))
  and mode == "ipfs") then
  if cidstr ~= "" then
    local request = harmonizeRequest(cidstr, path)
    local sha256 = sha.sha256(request)
    local dataFolder = absPath(config.cid_blocklist.dataFolder)
    local cidblocklistfile = dataFolder .. "/" .. sha256:sub(0,2) .. "/" .. sha256:sub(0,4)
    if not exists(dataFolder .. "/version") then
      statuscode, statusmessage = 503, "cid_blocklist datafolder not found."
      log(ngx.ERR, "ERROR: cid_blocklist datafolder not found! Check: " .. dataFolder)
    end
    if config.debug then
      ngx.header['X-debug-Request'] = request
      ngx.header['X-debug-SHA256'] = sha256
      ngx.header['X-debug-CIDBlocklistFile'] = cidblocklistfile
    end
    -- check cid blocklist file for sha256 hash 
    if string.find(readAll(cidblocklistfile), sha256) then
      statuscode = 403
      statusmessage = "cid in blocklist"
    end
  end
  log(false, ngx.INFO, "CID_BLOCKLIST RESULT -> " .. statuscode .. " (" .. statusmessage .. ")")
end

-- performance measure end
local duration = (os.clock() - starttime)

-- write debuging header
if headers["X-Debug-PerformanceTest"] == "true" then
  ngx.header['X-debug-ValuationDuration'] = duration
end
if config.debug then
  ngx.header['X-debug-ValuationDuration'] = duration
  ngx.header['X-debug-Statuscode'] = statuscode
  ngx.header['X-debug-Statusmessage'] = statusmessage
  ngx.header['X-debug-ServerHostname'] = getServerHostname()
  ngx.header['X-debug-RemoteAddr'] = ngx.var.remote_addr;
  ngx.header['X-debug-Origin'] = ngx.req.get_headers()["Origin"];
end

-- return statuscode, f.E. 200 if valid file or 403 if blocked
return statuscode
