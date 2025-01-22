local utils = require 'tools.utils'
local obj_cache = require 'tools.obj_cache'

local _M = {}

-- 地域定向
function _M.isHitLocationDirection(supplier, nut)
    local location_list = supplier.system_direct.location

    local ip_info = ngx.ctx.ip_info

    -- 这里有后面的判断是因为location_list的exclude和include字段为空的时候会在这两个字段塞个空表，导致对location_list判空失效
    if utils.tableIsEmpty(location_list) or (utils.tableIsEmpty(location_list.exclude) and utils.tableIsEmpty(location_list.include)) then
        return true
    end

    if utils.tableIsEmpty(ip_info) then
        return false
    end

    local province_code = "-1"
    local city_code = "-1"
    if utils.tableIsNotEmpty(ip_info) and utils.tableIsNotEmpty(ip_info.bayes_id) then
        if utils.isNotEmpty(ip_info.bayes_id.province_id) then
            province_code = ip_info.bayes_id.province_id
        end

        if utils.isNotEmpty(ip_info.bayes_id.city_id) then
            city_code = ip_info.bayes_id.city_id
        end
    end

    if "-1" == province_code and "-1" == city_code then
        -- 没有正确获取ip对应信息，以及没有映射到province或city的，不过滤
        return true
    end

    if utils.tableIsNotEmpty(location_list.include) then
        return utils.isInTable(province_code, location_list.include) or utils.isInTable(city_code, location_list.include)
    end

    if utils.tableIsNotEmpty(location_list.exclude) then
        return not (utils.isInTable(province_code, location_list.exclude) or utils.isInTable(city_code, location_list.exclude))
    end

    return true
end

-- App版本定向
function _M.isHitAppVersionDirection(supplier, nut)
    local app_ver = nut.pv_req.appver
    local app_version_direct = supplier.system_direct.app_version
    if utils.tableIsEmpty(app_version_direct) then
        return true
    end

    if utils.isEmpty(app_version_direct.larger) and utils.isEmpty(app_version_direct.smaller)
            and utils.tableIsEmpty(app_version_direct.include)
            and utils.tableIsEmpty(app_version_direct.exclude) then
        return true
    elseif utils.isEmpty(app_ver) then
        return false
    elseif utils.isNotEmpty(app_version_direct.larger) then
        return utils.isVersionEqualOrLarger(app_ver, app_version_direct.larger)
    elseif utils.isNotEmpty(app_version_direct.smaller) then
        return utils.isVersionEqualOrLarger(app_version_direct.smaller, app_ver)
    elseif utils.tableIsNotEmpty(app_version_direct.include) then
        return utils.isInTable(app_ver, app_version_direct.include)
    elseif utils.tableIsNotEmpty(app_version_direct.exclude) then
        return not utils.isInTable(app_ver, app_version_direct.exclude)
    else
        -- 其实不会走到这，为了代码结构好看还是加了一条
        return true
    end
end

local function makeJudgeInList(pv_make, make_list)
    for _, make_name in ipairs(make_list) do
        if string.find(pv_make, make_name) then
            return true
        end
    end

    return false
end

-- 手机制造商定向
function _M.isHitMakeDirection(supplier, nut)
    local make = string.upper(nut.pv_req.make or '')
    local make_direct = supplier.system_direct.make

    if utils.tableIsEmpty(make_direct) then
        return true
    end

    if utils.tableIsEmpty(make_direct.include) and utils.tableIsEmpty(make_direct.exclude) then
        return true
    elseif utils.isEmpty(make) then
        return false
    elseif utils.tableIsNotEmpty(make_direct.include) then
        return makeJudgeInList(make, make_direct.include)
    elseif utils.tableIsNotEmpty(make_direct.exclude) then
        return not makeJudgeInList(make, make_direct.exclude)
    else
        -- 其实不会走到这，为了代码结构好看还是加了一条
        return true
    end
end

-- OS版本定向
function _M.isHitOsVersionDirection(supplier, nut)
    local osv = utils.getRequestOsv(nut.pv_req.os, nut.pv_req.osv)
    local osv_version_direct = supplier.system_direct.osv
    if utils.tableIsEmpty(osv_version_direct) then
        return true
    end

    if utils.tableIsEmpty(osv_version_direct.include)
            and utils.tableIsEmpty(osv_version_direct.exclude) then
        return true
    elseif utils.isEmpty(osv) then
        return false
    elseif utils.tableIsNotEmpty(osv_version_direct.include) then
        return utils.isInTable(osv, osv_version_direct.include)
    elseif utils.tableIsNotEmpty(osv_version_direct.exclude) then
        return not utils.isInTable(osv, osv_version_direct.exclude)
    else
        -- 其实不会走到这，为了代码结构好看还是加了一条
        return true
    end
end

-- 设备单日请求限制
function _M.deviceDailyReqLimit(supplier, nut)
    if utils.isEmpty(supplier.request_limit.device_daily_req_limit)
            or supplier.request_limit.device_daily_req_limit <= 0 then
        return true
    end

    -- 对需要进行设备单日请求限制的supplier进行标记
    supplier.device_req_limit_tag = true

    local device_id = utils.getDeviceUniqueId(nut.pv_req)
    if utils.isEmpty(device_id) then
        -- 无设备id的不进行频控了
        return true
    end

    local field = utils.getDeviceAdspotSupplierDailyReqLimitField(nut, supplier)
    local curr_times = obj_cache.getDeviceLimit(device_id, field)
    if curr_times >= supplier.request_limit.device_daily_req_limit then
        return false
    end

    return true
end

-- 设备单日曝光限制
function _M.deviceDailyImpLimit(supplier, nut)
    if utils.isEmpty(supplier.request_limit.device_daily_imp_limit)
            or supplier.request_limit.device_daily_imp_limit <= 0 then
        return true
    end

    -- 对需要进行设备单日曝光限制的supplier进行标记
    supplier.device_imp_limit_tag = true

    local device_id = utils.getDeviceUniqueId(nut.pv_req)
    if utils.isEmpty(device_id) then
        -- 无设备id的不进行频控了
        return true
    end

    local field = utils.getDeviceAdspotSupplierDailyImpLimitField(nut, supplier)
    local curr_times = obj_cache.getDeviceLimit(device_id, field)
    if curr_times >= supplier.request_limit.device_daily_imp_limit then
        return false
    end

    return true
end

-- 渠道单日请求限制
function _M.supplierDailyReqLimit(supplier, nut)
    if utils.isEmpty(supplier.request_limit.daily_req_limit)
            or supplier.request_limit.daily_req_limit <= 0 then
        return true
    end

    -- 对需要进行请求限制的渠道supplier进行标记
    supplier.supplier_req_limit_tag = true
    local curr_times = obj_cache.getSupplierReqLimit(nut, supplier)
    if curr_times >= supplier.request_limit.daily_req_limit then
        return false
    end

    return true
end

-- 渠道单日曝光限制
function _M.supplierDailyImpLimit(supplier, nut)
    if utils.isEmpty(supplier.request_limit.daily_imp_limit)
            or supplier.request_limit.daily_imp_limit <= 0 then
        return true
    end

    -- 对需要进行曝光限制的渠道supplier进行标记
    supplier.supplier_imp_limit_tag = true
    local curr_times = obj_cache.getSupplierImpLimit(nut, supplier)
    if curr_times >= supplier.request_limit.daily_imp_limit then
        return false
    end

    return true
end

-- 渠道单设备请求间隔
function _M.supplierRequestInterval(supplier, nut)
    if utils.isEmpty(supplier.request_limit.device_request_interval)
            or supplier.request_limit.device_request_interval <= 0 then
        return true
    end

    local device_id = utils.getDeviceUniqueId(nut.pv_req)
    if utils.isEmpty(device_id) then
        -- 无设备id的不进行请求间隔控制了
        return true
    end

    -- 对需要进行请求间隔控制supplier进行标记
    supplier.request_interval_tag = true

    local device_plus_key = utils.getDeviceAdspotSupplierRequestIntervalKey(device_id, nut, supplier)
    if obj_cache.getDeviceRequestIntervalStatus(device_plus_key) then
        return false
    end

    return true
end

return _M