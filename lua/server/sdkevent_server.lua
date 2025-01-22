local dlog = require 'log.dlog'
local utils = require 'tools.utils'
local json = require 'cjson.safe'
local b64 = require("ngx.base64")

-- sdkevent里定义的字段名字不太规范
-- 因此在服务内直接先做名字的转换
local function rewriteSdkEventLog(pixel)
    -- check if query_tb is empty or not
    if utils.tableIsEmpty(pixel.query_tb) then
        return
    end

    local query_tb = pixel.query_tb
    -- 改写后可以删除离线日志部分关于sdkver和sdkadspotid的定义
    if utils.isNotEmpty(query_tb.sdkver) then
        query_tb.sdk_version = query_tb.sdkver
    end

    if utils.isNotEmpty(query_tb.sdkadspotid) then
        query_tb.sdk_adspotid = query_tb.sdkadspotid
    end
end

local function extendQuery(pixel)
    pixel.query_tb.action = string.sub(pixel.path, 2)
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

    rewriteSdkEventLog(pixel)
end

local function doOneTK(pixel)
    -- add action, _time
    extendQuery(pixel)

    dlog.logSdkEvent(pixel.query_tb)

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
    -- SDK event log 是 POST请求
    -- reading post body
    ngx.req.read_body()
    
    -- parsing post body
    local body_str = ngx.req.get_body_data()
    -- using cjson.safe, so here can directly decode string
    local body_tbl = json.decode(body_str)

    if utils.isEmpty(body_str) or utils.tableIsEmpty(body_tbl) then
        return 'Request body is empty', ngx.HTTP_BAD_REQUEST
    end

    return doOneTK(initOnePixel(body_str, body_tbl))
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
