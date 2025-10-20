local utils = require 'tools.utils'

local _M = {}


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

-- -- 设备定向
-- function _M.isHitDeviceDirection(strategy, nut)
--     local custom_direct = strategy.target_info.custom_direct

--     -- 没有设备自定义定向的，直接返回true，认为定向成功
--     if utils.tableIsEmpty(custom_direct) then
--         return true
--     end

--     -- 设备号获取为空，直接返回true，认为定向成功
--     local deviceId = utils.getDeviceUniqueId(nut.pv_req)
--     if utils.isEmpty(deviceId) then
--         return true
--     end

--     local target_ids_tb = obj_cache.getTargetInfo(deviceId)

--     for _, each_custom in ipairs(custom_direct) do
--         -- 不满足定向条件的直接返回false，认为定向不成功
--         if not utils.includeMatch(target_ids_tb, each_custom.include)
--             or not utils.excludeMatch(target_ids_tb, each_custom.exclude) then
--             return false
--         end
--     end

--     return true
-- end

return _M