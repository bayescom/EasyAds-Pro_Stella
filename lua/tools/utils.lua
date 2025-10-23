local conf = require 'conf'
local entity = require 'bean.entity'
local aes = require "resty.aes"
local b64 = require("ngx.base64")
local ffi_zlib  = require 'ffi-zlib'
local resty_str = require 'resty.string'
local resty_md5 = require 'resty.md5'
local http = require 'resty.http'

local _M = {}
local utils = _M

function _M.localTimeMs()
    local lt = ngx.localtime()
    local ms = string.format('%.3f', ngx.now())
    local t_str = string.format('%s,%s', lt, string.sub(ms, 12))
    return t_str
end

function _M.localTimeSecond()
    return os.date("%Y-%m-%d %H:%M:%S %z", ngx.time())
end

function _M.nowTimeMilliSecond()
    ngx.update_time()
    return tostring(ngx.now()*1000)
end

function _M.deepcopy(ob)
    local seen = {}
    local function _copy(ob)
        if type(ob) ~= 'table' then
            return ob
        elseif seen[ob] then
            return seen[ob]
        end
        local new_table = {}
        seen[ob] = new_table
        for k, v in pairs(ob) do
            new_table[_copy(k)] = _copy(v)
        end
        return setmetatable(new_table, getmetatable(ob))
    end
    return _copy(ob)
end

function _M.strSplit(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    local i = 1
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

function _M.isInTable(value, tbl)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function _M.tableIsNotEmpty(tbl)
    return type(tbl) == 'table' and tbl ~= nil and tbl ~= ngx.null and  _G.next(tbl) ~= nil
end

function _M.tableIsEmpty(tbl)
    return type(tbl) ~= 'table' or tbl == nil or tbl == ngx.null or _G.next(tbl) == nil
end

function _M.isNotEmpty(s)
    return s ~= nil and s ~= '' and s ~= ngx.null
end

function _M.isEmpty(s)
    return s == nil or s == '' or s == ngx.null
end

function _M.strEndsWith(str, substr)
    if str == nil or substr == nil then
        return false
    end
    local str_tmp = string.reverse(str)
    local substr_tmp = string.reverse(substr)
    if string.find(str_tmp, substr_tmp) ~= 1 then
        return false
    else
        return true
    end
end

function _M.concateStringsHelper(seg, ...)
    local n = select('#', ...)
    if n == 0 then
        return ''
    end
    seg = seg and tostring(seg) or ''
    local ans = ''
    local arg = {...}
    local i = 1
    while i <= n do
        local s = arg[i] and tostring(arg[i]) or 'nil'
        ans = ans .. s
        if i ~= n then
            ans = ans .. seg
        end
        i = i + 1
    end

    return ans
end

function _M.concatByDot(...)
    return _M.concateStringsHelper('.', ...)
end

function _M.concatByUnderscore(...)
    return _M.concateStringsHelper('_', ...)
end

function _M.concatByBlank(...)
    return _M.concateStringsHelper(' ', ...)
end

function _M.concat(...)
    return _M.concateStringsHelper('', ...)
end

function _M.updateReqhisTable(nut, supplier_key, reason)
    nut.reqhis_table[supplier_key].filtered_reason = reason
end

function _M.isVoyagerRequest(nut)
    return "voyager" == nut.nut_type
end

--[[
    请求曝光等频控获取key的相关函数
]]

-- 单日广告位渠道请求限制
-- 单日广告位渠道曝光限制
-- 获取key的方式相同
function _M.getAdspotSupplierDailyLimitKey(nut, supplier)
    local key = nil
    if _M.isVoyagerRequest(nut) then
        -- 20230710 by 夏瑜，需要遥哥确认
        -- 不太确定这边导出里，竞价渠道使用的时sdk_id还是adspot_channel_id
        -- 老版本的代码里：supplier_selector用的是sdk_id，但是记录日志这里用的是adspot channel id
        -- 先统一用sdk_id
        key = utils.concatByUnderscore(nut.pv_req.adspotid, supplier.sdk_id)
    else
        key = utils.concatByUnderscore(nut.pv_req.adspotid, "sdk", supplier.sdk_id)
    end

    return key
end

-- 设备单日广告位渠道限制基础函数
local function getDeviceAdspotSupplierDailyLimitField(nut, supplier, action)
    -- 区分不同的action，目前为req和imp
    local key = utils.concatByUnderscore('supplier', action)
    local field = nil
    if _M.isVoyagerRequest(nut) then
        field = utils.concatByUnderscore(nut.pv_req.adspotid, supplier.sdk_id, key)
    else
        field = utils.concatByUnderscore(nut.pv_req.adspotid, supplier.sdk_id, 'sdk', key)
    end

    return field
end

-- 设备单日广告位渠道请求限制
function _M.getDeviceAdspotSupplierDailyReqLimitField(nut, supplier)
    return getDeviceAdspotSupplierDailyLimitField(nut, supplier, 'req')
end

-- 设备单日广告位渠道曝光限制
function _M.getDeviceAdspotSupplierDailyImpLimitField(nut, supplier)
    return getDeviceAdspotSupplierDailyLimitField(nut, supplier, 'imp')
end

-- 设备广告位渠道请求间隔
function _M.getDeviceAdspotSupplierRequestIntervalKey(device_id, nut, supplier)
    local device_plus_key = nil
    if _M.isVoyagerRequest(nut) then
        device_plus_key = utils.concatByUnderscore(device_id, nut.pv_req.adspotid, supplier.sdk_id)
    else
        device_plus_key = utils.concatByUnderscore(device_id, nut.pv_req.adspotid, "sdk", supplier.sdk_id)
    end

    return device_plus_key
end

function _M.getValue(value)
    if utils.isEmpty(value) then
        return nil
    else
        return value
    end
end

function _M.getDeviceUniqueId(pv_req)
    -- run iOS ids
    if pv_req.os == entity.enum_os.ios then
        local iosid = nil
        if utils.isNotEmpty(pv_req.idfa) then
            iosid = pv_req.idfa
        elseif utils.isNotEmpty(pv_req.idfv) then
            iosid = pv_req.idfv
        end

        if utils.isNotEmpty(iosid) then
            return iosid
        end
    else
        local androidid = nil
        if utils.isNotEmpty(pv_req.imei) then
            androidid = pv_req.imei
        elseif utils.isNotEmpty(pv_req.oaid) then
            androidid = pv_req.oaid
        elseif utils.isNotEmpty(pv_req.androidid) then
            androidid = pv_req.androidid
        end

        if utils.isNotEmpty(androidid) then
            return androidid
        end
    end

    return nil
end

-- AEC ECB 128 PCK5Padding 无偏移量配置
function _M.AES128ECB_PCK5Padding_Creator(key, iv)
    local aes128ecb, _ = aes:new(key, nil, aes.cipher(128, 'ecb'),  {iv = iv or string.rep(string.char(0), 16)})

    return aes128ecb
end

local device_encryptor = _M.AES128ECB_PCK5Padding_Creator(conf.encryption_keys.device_enc_key)

function _M.device_encinfo_decrypt(secret)
    if device_encryptor == nil or _M.isEmpty(secret) then
        return nil
    end

    return device_encryptor:decrypt(b64.decode_base64url(secret))
end

--[[
    --- Parameters: #1: inputTable #2~N: table path
    --- It will walk through the path of the table and return the entire path
    --- e.g. tbl.key.subkey
    --- if the result is table, it will return the table
]]
local function getTableElementHelper(tbl, ...)
    if utils.tableIsEmpty(tbl) then
        return
    end

    local result = tbl
    for i = 1, select('#', ...) do
        -- e.g. tbl.test = 1, if someone want to get tbl.test.test, this will return nil
        if type(result) ~= 'table' then
            return
        end

        local key = select(i, ...)
        local nv  = result[key]
        if nv ~= nil then
            result = nv
        else
            return
        end
    end
    return result
end

function _M.tblElement(tbl, ...)
    return getTableElementHelper(tbl, ...)
end

function _M.includeMatch(req, include)
    if utils.tableIsEmpty(req) then
        return false
    end

    for _, reqDirect in ipairs(req) do
        if utils.isInTable(reqDirect, include) then
            return true
        end
    end

    return false
end

function _M.excludeMatch(req, exclude)
    if utils.tableIsEmpty(req) then
        return true
    end

    for _, reqDirect in ipairs(req) do
        if utils.isInTable(reqDirect, exclude) then
            return false
        end
    end

    return true
end

-- 该函数返回v1是否大于等于v2
-- ifEmpty表示如果有一个为空时的默认值
function _M.isVersionEqualOrLarger(v1, v2, ifEmpty)
    -- ifEmpty is not set, we return false by default
    if ifEmpty == nil then
        ifEmpty = false
    end
    -- since we can not compare with an empty version
    if _M.isEmpty(v1) or _M.isEmpty(v2) then
        return ifEmpty
    end

    -- if input is not string, replace them with string instead
    v1 = type(v1) == 'string' and v1 or tostring(v1)
    v2 = type(v2) == 'string' and v2 or tostring(v2)

    local len1 = #v1
    local len2 = #v2
    local i = 1
    local j = 1
    local n1 = 0
    local n2 = 0
    while i <= len1 or j <= len2 do
        while i <= len1 and (v1:sub(i,i) ~= '.' and v1:sub(i,i) ~= ' ') do
            -- 如果这里转换失败了，可以尝试默认按照0来计算
            if tonumber(v1:sub(i,i)) == nil then
                return false
            end
            n1  = n1 * 10 + tonumber(v1:sub(i,i))
            i = i + 1
        end 

        while j <= len2 and (v2:sub(j,j) ~= '.' and v2:sub(j,j) ~= ' ') do
            if tonumber(v2:sub(j,j)) == nil then
                return false
            end
            n2 = n2 * 10 + tonumber(v2:sub(j,j))
            j = j + 1
        end

        if n1 > n2 then
            return true
        elseif n1 < n2 then
            return false
        end

        n1 = 0
        n2 = 0
        i = i + 1
        j = j + 1
    end

    -- in this case, the version is the same
    return true
end

-- if the value is Empty, return default, else return value
function _M.NilDefault(value, default)
    if _M.isEmpty(value) then
        return default
    else
        return value
    end
end

function _M.getTodayExpireTime()
    local today = os.date("%Y-%m-%d", ngx.time())
    local _, _, year, month, day = string.find(today, "(%d+)-(%d+)-(%d+)")
    return os.time({day=day, month=month, year=year, hour=23, min=59, sec=59})
end

function _M.loadModule(moduleName)
    if utils.isEmpty(moduleName) then
        return nil
    end

    local a_module = package.loaded[moduleName]
    if utils.isEmpty(a_module) then
        a_module = require(moduleName)
    end

    return a_module
end


function _M.loadModuleIfAvailable(moduleName)
    if utils.isEmpty(moduleName) then
        return nil
    end

    if package.loaded[moduleName] then
        return utils.loadModule(moduleName)
    else
        for _,searcher in ipairs(package.searchers or package.loaders) do
            local loader = searcher(moduleName)
            if type(loader) == 'function' then
                package.preload[moduleName] = loader
                return utils.loadModule(moduleName)
            end
        end
        return nil
    end
end

function _M.redisArrayToTable(redis_hash)
    local redis_json = {}
    for i = 1, #redis_hash, 2 do
        redis_json[redis_hash[i]] = redis_hash[i+1]
    end

    return redis_json
end

local function getOsvTop(osv)
    if utils.isEmpty(osv) then
        return ''
    end
    local osv_array = _M.strSplit(osv, ".")
    return _M.concatByDot(osv_array[1] or '', osv_array[2] or '')
end

function _M.getRequestOsv(os, osv)
    local local_os = os or ''
    local local_osv = getOsvTop(osv)

    if utils.isEmpty(local_os) or utils.isEmpty(local_osv) then
        return ''
    end
    return _M.concatByUnderscore(local_os, local_osv)
end

function _M.decompress(str)
    local chunk = 16384
    local count = 0

    local input = function(bufsize)
        local start = count > 0 and bufsize*count or 1
        local data = str:sub(start, (bufsize*(count+1)-1))
        if data == "" then
            data = nil
        end

        count = count + 1
        return data
    end
    local output_table = {}
    local output = function(data)
        table.insert(output_table, data)
    end

    local ok, err = ffi_zlib.inflateGzip(input, output, chunk)
    if not ok then
        ngx.log(ngx.ERR, 'the ffi zlib err: ', err)
    end

    return table.concat(output_table,'')
end

function _M.upper(s)
    if _M.isEmpty(s) then return s end
    return string.upper(s)
end

function _M.getMd5(id, to_upper)
    if _M.isEmpty(id) then
        return nil
    end

    local md5 = resty_md5:new()
    if to_upper == true then
        md5:update(_M.upper(id))
    else
        md5:update(id)
    end

    return resty_str.to_hex(md5:final())
end

function _M.doUrlGet(url, timeout)
    local httpc = http.new()
    httpc:set_timeout(timeout)

    local rsp, err = httpc:request_uri(url,{method = "GET", keepalive_timeout = 500, keepalive_pool = 32})
    if not rsp then
        ngx.log(ngx.ERR, _M.concat("url get request failed, rsp is nil! nurl: ", url, ", err: ", err))
        return entity.enum_rsp_status.http_not_ok
    else
        if rsp.status ~= ngx.HTTP_OK then
            ngx.log(ngx.ERR, _M.concat("url get request failed! url: ", url, ", err: ", err))
            ngx.log(ngx.ERR, "url get rsp: ", json.encode(rsp.body))
            return entity.enum_rsp_status.http_not_ok
        else
            return entity.enum_rsp_status.http_ok, rsp.body
        end
    end
end

return utils
