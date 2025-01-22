local _M = {}
local obj_cache = _M

local utils = require "tools.utils"
local conf_cache  = require "tools.conf_cache"

local DEVICE_INTERVAL_RDB = conf_cache.DEVICE_INTERVAL_RDB

local DEVICE_LIMIT_RDB = conf_cache.DEVICE_LIMIT_RDB

local SUPPLIER_LIMIT_RDB = conf_cache.SUPPLIER_LIMIT_RDB

-- 单设备渠道请求/曝光上限Redis
function _M.getDeviceLimit(key, field)
    local res, err = DEVICE_LIMIT_RDB:hget(key, field)

    if err ~= nil then -- redis error
        error(err)
        -- no return here
        return 0
    else
        if res ~= nil then -- key found
            return tonumber(res)
        else -- key not found
            return 0
        end
    end
end

function _M.addDeviceLimit(key, field)
    local status, err = pcall(
            function()
                DEVICE_LIMIT_RDB:hincrby(key, field, 1)
                DEVICE_LIMIT_RDB:expireat(key, utils.getTodayExpireTime())
            end
    )

    if not status then
        ngx.log(ngx.ERR, 'add rediskey ['.. key ..  '] device limit ' .. err.. ' on ' .. field)
    end
end

function _M.addDeviceReqLimit(device_id, nut, supplier)
    local field = utils.getDeviceAdspotSupplierDailyReqLimitField(nut, supplier)
    _M.addDeviceLimit(device_id, field)
end

-- 渠道请求/曝光上限Redis
function _M.getSupplierLimit(key, field)
    local res, err = SUPPLIER_LIMIT_RDB:hget(key, field)

    if err ~= nil then -- redis error
        error(err)
        return 0
    else
        if res ~= nil then -- key found
            return tonumber(res)
        else -- key not found
            return 0
        end
    end
end

-- 广告位渠道日请求次数
function _M.getSupplierReqLimit(nut, supplier)
    local key = utils.getAdspotSupplierDailyLimitKey(nut, supplier)
    return _M.getSupplierLimit(key, 'req')
end

-- 广告位渠道日曝光次数
function _M.getSupplierImpLimit(nut, supplier)
    local key = utils.getAdspotSupplierDailyLimitKey(nut, supplier)
    return _M.getSupplierLimit(key, 'imp')
end

function _M.addSupplyLimit(key, field)
    local status, err = pcall(
            function()
                SUPPLIER_LIMIT_RDB:hincrby(key, field, 1)
                SUPPLIER_LIMIT_RDB:expireat(key, utils.getTodayExpireTime())
            end
    )

    if not status then
        ngx.log(ngx.ERR, 'add rediskey ['.. key ..  '] supplier limit ' .. err.. ' on ' .. field)
    end
end

function _M.addSupplyReqLimit(nut, supplier)
    local key = utils.getAdspotSupplierDailyLimitKey(nut, supplier)
    _M.addSupplyLimit(key, 'req')
end

-- 请求间隔Redis获取
function _M.getDeviceRequestIntervalStatus(key)
    local res, err = DEVICE_INTERVAL_RDB:get(key)

    if err ~= nil then -- redis error
        error(err)
        return false
    else
        if res ~= nil then -- key found
            return true
        else -- key not found
            return false
        end
    end
end

function _M.addDeviceRequestInterval(key, interval)
    local status, err = pcall(
            function()
                DEVICE_INTERVAL_RDB:set(key, 1)
                DEVICE_INTERVAL_RDB:expire(key, interval)
            end
    )

    if not status then
        ngx.log(ngx.ERR, 'device add request interval' .. err)
    end
end

return obj_cache
