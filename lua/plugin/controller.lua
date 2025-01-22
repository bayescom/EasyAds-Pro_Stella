local utils = require 'tools.utils'
local obj_cache = require 'tools.obj_cache'

local _M = {}

-- Controller: 设备日广告位请求上限
function _M.deviceDailyAdspotReqLimit(nut)
    if utils.tableIsEmpty(nut.pv_prop.request_limit)
            or utils.isEmpty(nut.pv_prop.request_limit.device_daily_req_limit)
            or tonumber(nut.pv_prop.request_limit.device_daily_req_limit) <= 0 then
        return false
    end

    -- 这里目前用的是nut，nut已经被设置过值
    local device_id = utils.getDeviceUniqueId(nut.pv_req)
    -- 若device_id为空，那么就不做流控
    if utils.isEmpty(device_id) then
        return false
    end

    local field = utils.concatByUnderscore(nut.pv_req.adspotid, 'adspot_req')
    local curr_times = obj_cache.getDeviceLimit(device_id, field)
    if curr_times >= tonumber(nut.pv_prop.request_limit.device_daily_req_limit) then
        return true
    end

    return false
end

-- Controller: 设备日广告位曝光上限
-- 曝光控制对人人视频无效，所以暂时不增加对曝光的当日统计了
function _M.deviceDailyAdspotImpLimit(nut)
    if utils.tableIsEmpty(nut.pv_prop.request_limit)
            or utils.isEmpty(nut.pv_prop.request_limit.device_daily_imp_limit)
            or tonumber(nut.pv_prop.request_limit.device_daily_imp_limit) <= 0 then
        return false
    end

    local device_id = utils.getDeviceUniqueId(nut.pv_req)
    -- 若device_id为空，那么就不做流控
    if utils.isEmpty(device_id) then
        return false
    end

    local field = utils.concatByUnderscore(nut.pv_req.adspotid, 'adspot_imp')
    local curr_times = obj_cache.getDeviceLimit(device_id, field)
    if curr_times >= tonumber(nut.pv_prop.request_limit.device_daily_imp_limit) then
        return true
    end

    return false
end

-- Controller: 单设备广告位请求频次控制
function _M.deviceDailyAdspotRequestInterval(nut)
    if utils.tableIsEmpty(nut.pv_prop.request_limit)
            or utils.isEmpty(nut.pv_prop.request_limit.device_request_interval)
            or tonumber(nut.pv_prop.request_limit.device_request_interval) <= 0 then
        return false
    end

    local device_id = utils.getDeviceUniqueId(nut.pv_req)
    -- 若device_id为空，那么就不做控制
    if utils.isEmpty(device_id) then
        return false
    end

    local device_adspot_key = utils.concatByUnderscore(device_id, nut.pv_req.adspotid, 'adspot')

    return obj_cache.getDeviceRequestIntervalStatus(device_adspot_key)
end

return _M