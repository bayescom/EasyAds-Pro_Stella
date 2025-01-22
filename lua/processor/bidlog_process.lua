local utils = require "tools.utils"
local json = require 'cjson.safe'

local _M = {}
local bidlog_process = _M

local function getBidInfo(pv_rsp)
    local bid_info = {}

    if utils.tableIsEmpty(pv_rsp) or utils.tableIsEmpty(pv_rsp.suppliers) then
        return json.empty_array
    end

    for _, supplier in ipairs(pv_rsp.suppliers) do
        local bid = {}
        for field, value in pairs(supplier) do
            if not utils.strEndsWith(field, "tk") then
                bid[field] = value
            end
        end
        table.insert(bid_info, bid)
    end

    return bid_info
end

function _M.doProcess(nut)
    nut.bid_info = getBidInfo(nut.pv_rsp)
end

return bidlog_process