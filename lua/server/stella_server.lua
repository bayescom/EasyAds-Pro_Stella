local json = require 'cjson.safe'
local dlog = require 'log.dlog'
local nut_module = require 'bean.nut_module'
local http_parser = require 'processor.http_parser'
local request_check = require 'processor.request_check'
local supplier_reader = require 'processor.supplier_reader'
local adspot_controller = require 'processor.adspot_controller'
local ip_region_analyzer = require 'processor.ip_region_analyzer'
local main_strategy = require 'processor.main_strategy'
local response_maker = require 'processor.response_maker'
local bidlog_process = require 'processor.bidlog_process'

local process_list = {
    http_parser,        -- http request parser
    request_check,      -- request checker
    supplier_reader,    -- make request
    adspot_controller,  -- adspot controller
    ip_region_analyzer,  -- analyze region from ip
    main_strategy,      -- main strategy
    response_maker,     -- generate response
    bidlog_process,     -- bid log
}

local function createPvRsp(nut)
    local pv_rsp = {}
    pv_rsp.code = ngx.HTTP_BAD_REQUEST
    pv_rsp.msg = json.encode(nut.filter_result)
    pv_rsp.reqid = nut.sid

    return pv_rsp
end

local function doAllProcess(nut)
    for _, processor in ipairs(process_list) do
        processor.doProcess(nut)
        if nut:isFiltered() then
            local pv_rsp = createPvRsp(nut)
            nut.http_rsp.body = json.encode(pv_rsp)
            nut.http_rsp.code = nut:getFilterCode()
            pv_rsp.code = nut:getFilterCode()
            return
        end
    end
end

local function requestAd()
    local nut = nut_module:new()
    nut:init()

    local status, err = pcall(
            function()
                doAllProcess(nut)
            end
    )

    -- log
    nut:log()

    -- server error occurred, return 404
    if not status then
        nut.http_rsp.body = '500 INTERNAL_SERVER_ERROR'
        nut.http_rsp.code = ngx.HTTP_INTERNAL_SERVER_ERROR
        ngx.log(ngx.ERR, err)
    end

    return nut.http_rsp.body, nut.http_rsp.code
end

local function httpd()
    local status, result, code = pcall(
        function()
            return requestAd()
        end
    )

    if status then
        -- js script cross-domain
        ngx.header['Content-Type'] = 'application/json'
        ngx.header['Access-Control-Allow-Origin'] = '*'
        ngx.header['Access-Control-Allow-Headers'] = 'Content-Type, x-bridge-version, x-vendor-id, x-is-test'
        ngx.status = code
        ngx.say(result)
        ngx.exit(code)
    else
        ngx.log(ngx.ERR, result)
        local logstr = string.format("500 INTERNAL_SERVER_ERROR status: %s result: %s.", status, result)
        dlog.error(logstr)
        ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
        ngx.say('500 INTERNAL_SERVER_ERROR')
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
end

httpd()