local _M = {}
local redis_utils = _M

local utils = require "tools.utils"
local json = require "cjson.safe"
local lrucache = require "resty.lrucache"
local redis = require "resty.redis-util"

function _M.createRedisClient(redis_conf, db_index)
    if utils.tableIsEmpty(redis_conf) or utils.isEmpty(db_index) then
        ngx.log(ngx.ERR, 'redis conf is empty!', json.encode(redis_conf), db_index)
        return nil
    end

    local rdb = redis:new(
            {
                host = redis_conf.host,
                port = redis_conf.port,
                db_index = db_index,
                password = redis_conf.passwd,
                timeout = 200,
                keepalive = 60000,
                pool_size = 100
            }
    )

    if rdb == nil then
        ngx.log(ngx.ERR, utils.concatByBlank('redis creation failed.', redis_conf.host, db_index))
        return nil
    end

    return rdb
end

function _M.createLruCache(cache_size)
    local conf_cache, err = lrucache.new(cache_size)  -- allow up to 200 items in the cache
    if not conf_cache then
        error("failed to create the cache: " .. (err or "unknown"))
    end
    return conf_cache
end

return redis_utils