local utils = require 'tools.utils'
local conf_cache = require 'tools.conf_cache'

local _M = {}
local supplier_reader = _M

function _M.doProcess(nut)
    -- get adspot suppliers info from cluster redis
    local adspotid = nut.pv_req.adspotid
    local suppliers_info = conf_cache.getSuppliersInfo(adspotid)
    if utils.tableIsEmpty(suppliers_info) then
        nut:setFiltered('supplierConf', 'suppliers info decode error', ngx.HTTP_NO_CONTENT)
        return
    end

    -- get supplier conf info
    ngx.ctx.traffic = suppliers_info.group

    -- replace appid
    nut.pv_req.appid = suppliers_info.appid

    -- set pv_prop info
    nut.pv_prop.appid = suppliers_info.appid
    nut.pv_prop.request_limit = suppliers_info.request_limit
    nut.pv_prop.ext_settings = suppliers_info.ext_settings
end

return supplier_reader