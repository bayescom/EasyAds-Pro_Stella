local dlog = require 'log.dlog'
local utils = require 'tools.utils'
local obj_cache = require 'tools.obj_cache'
local json = require 'cjson.safe'
local b64 = require("ngx.base64")

local function addDeviceLimit2Redis(pixel)
    local query_tb = pixel.query_tb
    if utils.isEmpty(query_tb.device_imp_limit_tag) then
        return
    end

    local device_id = query_tb.unique_deviceid
    if utils.isNotEmpty(device_id) then
        local field = utils.concatByUnderscore(query_tb.adspotid, query_tb.sdk_id, "supplier_imp")
        obj_cache.addDeviceLimit(device_id, field)
    end
end

local function addSupplierLimit2Redis(pixel)
    local query_tb = pixel.query_tb
    if utils.isEmpty(query_tb.supplier_imp_limit_tag) then
        return
    end

    local key = utils.concatByUnderscore(query_tb.adspotid, query_tb.sdk_id)
    obj_cache.addSupplyLimit(key, "imp")
end

local function extendQuery(pixel)
    pixel.query_tb._time = pixel.time_str
    pixel.query_tb.source_ip = pixel.source_ip
    if utils.isEmpty(pixel.query_tb.ua) then
        pixel.query_tb.ua = pixel.ua
    end
    pixel.query_tb.host = ngx.var.hostname
    pixel.query_tb.ftime = utils.localTimeSecond()
    pixel.query_tb.action_time = pixel.action_time

    -- 注意,dinfo里包含了设备相关的信，目前主要有如下几个字段：
    -- imei/idfa/os/unique_deviceid
    -- 解密方法为 base64 url decode + json.decode
    if utils.isNotEmpty(pixel.query_tb.dinfo) then
        local device = json.decode(b64.decode_base64url(pixel.query_tb.dinfo) or '{}')

        if utils.tableIsNotEmpty(device) then
            for k, v in pairs(device) do
                pixel.query_tb[k] = v
            end
        end
    end
end

local function doOneTK(pixel)
    -- add action, _time
    extendQuery(pixel)

    local action = pixel.query_tb.action

    if action == 'loaded' then
        dlog.logLoaded(pixel.query_tb)
    elseif action == 'succeed' then
        dlog.logSucceed(pixel.query_tb)
    elseif action == 'win' then
        dlog.logWin(pixel.query_tb)
        addDeviceLimit2Redis(pixel)
        addSupplierLimit2Redis(pixel)
    elseif action == 'click' then
        dlog.logClick(pixel.query_tb)
    elseif action == 'failed' then
        dlog.logFailed(pixel.query_tb)
    elseif action == 'bidwin' then
        dlog.logBidWin(pixel.query_tb)
    end
    
    return pixel.rsp_str, pixel.rsp_code, pixel.rsp_headers
end

local function initOnePixel(query_str, query_tb)
    local pixel = {
        sid         = '',
        stime       = ngx.now() * 1000,
        action_time = utils.nowTimeMilliSecond(),
        time_str    = utils.localTimeMs(),
        source_ip   = ngx.var.remote_addr,
        ua          = ngx.var.http_user_agent,
        headers     = ngx.req.get_headers(),
        path        = ngx.var.document_uri,
        query_tb    = query_tb,
        query_str   = query_str,
        method      = ngx.var.request_method,
        req         = {},
        rsp_headers = {
            ['Content-Type'] = 'text/plain',
            ['Access-Control-Allow-Origin'] = '*'
        },
        rsp_str     = 'OK',
        rsp_code    = ngx.HTTP_OK
    }

    return pixel
end


local function handleAction()
    local query_str = ngx.var.query_string
    local query_tbl = ngx.req.get_uri_args()

    -- in case we get empty 
    if utils.isEmpty(query_str) and utils.tableIsEmpty(query_tbl) then
        return 'Request params is empty', ngx.HTTP_BAD_REQUEST
    end

    return doOneTK(initOnePixel(ngx.var.query_string, query_tbl))
end

local function httpd()
    local status, result, code, headers = pcall(
        function ()
            return handleAction()
        end
    )

    if status then
        if utils.tableIsNotEmpty(headers) then
            -- js script cross-domain
            for k, v in pairs(headers) do
                ngx.header[k] = v
            end
        end
        ngx.status = code
        ngx.print(result)
        ngx.exit(code)
    else
        ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
        ngx.print("500 INTERNAL_SERVER_ERROR")
        ngx.log(ngx.ERR, result)
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
end

httpd()
