local uuid = require 'resty.jit-uuid'
local utils = require 'tools.utils'
local dlog = require 'log.dlog'
local json = require 'cjson.safe'

local Nut_Module = {
    nut_type = 'cruiser',
    -- http request
    http_req = {},
    -- http response
    http_rsp = {
        code = ngx.HTTP_OK,
        body = ''
    },
    -- filter result reason
    filter_result = {
        is_filtered = false,
        filtered_by = '',
        reason = '',
        code = ngx.HTTP_OK
    },
    -- pv requst
    pv_req = {},
    -- pv response
    pv_rsp = {
        code = ngx.HTTP_OK,
        msg = '',
        suppliers = {},
        abtag = 'group_strategy'
    },
    -- pv property
    pv_prop = {},

    reqhis_table = {},
    suppliers = {},
    parallel_group_setting = {},
    head_bidding_group = {},

    -- bid info
    bid_info = json.empty_array
}


function Nut_Module:new(obj)
    obj = obj or {}
    local copy = utils.deepcopy(self)
    setmetatable(obj, {__index = copy})
    return obj
end

function Nut_Module:init()
    self.sid = string.gsub(uuid(), '-', '')
    self.stime = ngx.now() * 1000
    self.ftime = utils.localTimeSecond()
    self.action_time = utils.nowTimeMilliSecond()
end

function Nut_Module:setFiltered(name, reason, code)
    self.filter_result.is_filtered = true
    self.filter_result.filtered_by = name
    self.filter_result.reason = reason
    self.filter_result.code = code
end

function Nut_Module:isFiltered()
    return self.filter_result.is_filtered
end

function Nut_Module:getFilterCode()
    return self.filter_result.code
end

function Nut_Module:logReq()
    local tcost = ngx.now() * 1000 - self.stime

    local req = {
        reqid       = self.sid,
        ftime       = self.ftime,
        action      = 'req',
        action_time = self.action_time,
        tcost       = tcost,
        host        = self.http_req.hostname,
        addr        = self.http_req.real_ip,
        pv_req      = self.pv_req,
        pv_prop     = self.pv_prop,
        abtag       = self.pv_rsp.abtag,
        ip_info     = {},
        filter_info = self.filter_result,
        bid_info    = self.bid_info,
    }

    if utils.tableIsNotEmpty(ngx.ctx.ip_info) then
        req.ip_info = ngx.ctx.ip_info
    end

    dlog.logReq(req)
end

function Nut_Module:log()
    self:logReq()
end

return Nut_Module