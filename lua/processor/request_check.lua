local _M = {}
local request_check = _M

local json = require 'cjson.safe'
local utils = require 'tools.utils'
local uuid = require 'resty.jit-uuid'

local function httpMethodCheck(nut)
    if 'POST' ~= nut.http_req.method then
        nut:setFiltered('httpMethodFilter', 'not http post request', ngx.HTTP_BAD_REQUEST)
    end
end


local function httpBodyCheck(nut)
    if utils.isEmpty(nut.http_req.body) then
        nut:setFiltered('httpBodyFilter', 'body data is empty', ngx.HTTP_BAD_REQUEST)
    end
end

-- 改写加密的设备信息
local function decryptDeviceIds(pv_req)
    -- 通过增加device_encinfo字段，对设备信息进行加密
    -- 参考文档：http://www.bayescom.com/docsify/docs/#/advance/api/advance_sdk_cruiser
    local deviceids_str = utils.device_encinfo_decrypt(pv_req.device_encinfo)

    if utils.isEmpty(deviceids_str) then
        return
    end

    local deviceids_tbl = json.decode(deviceids_str)

    if utils.tableIsEmpty(deviceids_tbl) then
        return
    end

    -- 这里是直接对原始数据进行改写的
    -- 所以不会影响日志里的信息
    for req_field, req_value in pairs(deviceids_tbl) do
        if utils.isNotEmpty(req_value) then
            pv_req[req_field] = req_value
        end
    end
end


local function requestParamsExtend(nut)
    -- 生成唯一的请求id
    nut.sid = string.gsub(uuid(), '-', '')
    
    -- 全部通过该方式来获取客户端真实ip
    nut.pv_req.ip = nut.http_req.real_ip

    -- 解密设备信息加密
    decryptDeviceIds(nut.pv_req)

    -- 在req日志中增加唯一设备id
    nut.pv_req.unique_deviceid = utils.getDeviceUniqueId(nut.pv_req)
end

local function requestParamsCheck(nut)
    -- http_req body format
    local pv_req = json.decode(nut.http_req.body)
    if utils.tableIsEmpty(pv_req) then
        nut:setFiltered('paramsFilter', 'request body is not valid JSON', ngx.HTTP_BAD_REQUEST)
        return
    end

    -- set pv_req
    nut.pv_req = pv_req

    -- extend pv_req params
    requestParamsExtend(nut)
end

local filter_list = {
    httpMethodCheck,
    httpBodyCheck,
    requestParamsCheck
}

function _M.doProcess(nut)
    -- do filter in filter_list
    for _, func in ipairs(filter_list) do
        func(nut)
        if nut:isFiltered() then
            break
        end
    end
end

return request_check