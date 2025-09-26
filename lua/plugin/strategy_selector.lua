local utils = require 'tools.utils'

local _M = {}

-- 地域定向
function _M.isHitLocationDirection(strategy, nut)
    local location_list = strategy.target_info.system_direct.location

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
function _M.isHitAppVersionDirection(strategy, nut)
    local app_ver = nut.pv_req.appver
    local app_version_direct = strategy.target_info.system_direct.app_version
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


-- SDK版本定向
function _M.isHitSdkVersionDirection(strategy, nut)
    local sdk_ver = nut.pv_req.sdk_version
    local sdk_version_direct = strategy.target_info.system_direct.sdk_version
    if utils.tableIsEmpty(sdk_version_direct) then
        return true
    end

    if utils.isEmpty(sdk_version_direct.larger) and utils.isEmpty(sdk_version_direct.smaller)
            and utils.tableIsEmpty(sdk_version_direct.include)
            and utils.tableIsEmpty(sdk_version_direct.exclude) then
        return true
    elseif utils.isEmpty(sdk_ver) then
        return false
    elseif utils.isNotEmpty(sdk_version_direct.larger) then
        return utils.isVersionEqualOrLarger(sdk_ver, sdk_version_direct.larger)
    elseif utils.isNotEmpty(sdk_version_direct.smaller) then
        return utils.isVersionEqualOrLarger(sdk_version_direct.smaller, sdk_ver)
    elseif utils.tableIsNotEmpty(sdk_version_direct.include) then
        return utils.isInTable(sdk_ver, sdk_version_direct.include)
    elseif utils.tableIsNotEmpty(sdk_version_direct.exclude) then
        return not utils.isInTable(sdk_ver, sdk_version_direct.exclude)
    else
        -- 其实不会走到这，为了代码结构好看还是加了一条
        return true
    end
end


-- 手机制造商定向
function _M.isHitMakeDirection(strategy, nut)
    local make = string.upper(nut.pv_req.make or '')
    local make_direct = strategy.target_info.system_direct.make

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
function _M.isHitOsVersionDirection(strategy, nut)
    local osv = utils.getRequestOsv(nut.pv_req.os, nut.pv_req.osv)
    local osv_version_direct = strategy.target_info.system_direct.osv
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

return _M