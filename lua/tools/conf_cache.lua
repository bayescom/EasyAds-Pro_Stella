local _M = {}

local json = require 'cjson.safe'
local conf = require "conf"
local utils = require 'tools.utils'
local redis_utils = require 'tools.redis_utils'

-- Redis Client都需要在这里初始化，不然会出问题
_M.DEVICE_INTERVAL_RDB = redis_utils.createRedisClient(conf.frequency_redis, conf.frequency_redis.sdk_device_interval_db)

_M.DEVICE_LIMIT_RDB = redis_utils.createRedisClient(conf.frequency_redis, conf.frequency_redis.sdk_device_limit_db)

_M.SUPPLIER_LIMIT_RDB = redis_utils.createRedisClient(conf.frequency_redis, conf.frequency_redis.sdk_supplier_limit_db)


local SMALL_CACHE_SIZE = 5000
local MEDIUM_CACHE_SIZE = 20000
local LARGE_CACHE_SIZE = 100000

-- 下面用于存md5的缓存中存的是表，表中有两个元素，conf_md5用于存md5，update_tag用于存配置是否需要更新
-- update_tag是int类型，值为0的时候表示不需要更新，值为1的时候需要更新

-- supplier conf
local supplier_conf = {
    name = 'supplier conf',
    redis_client = redis_utils.createRedisClient(conf.redis, conf.redis.media_db),
    cache_size = MEDIUM_CACHE_SIZE,
    md5_cache = redis_utils.createLruCache(MEDIUM_CACHE_SIZE),
    cache = redis_utils.createLruCache(MEDIUM_CACHE_SIZE),
    is_zip = false,
    check_empty = true,
}

local function redisArrayToTable(redis_array)
    local redis_tbl = {}
    for i = 1, #redis_array, 2 do
        redis_tbl[redis_array[i]] = redis_array[i+1]
    end

    return redis_tbl
end

local function getMd5ConfHashMap(redis_client)
    -- 获取所有的md5
    local status, res = pcall(
        function ()
            return redis_client:hgetall('MD5KV')
        end
    )

    if not status then
        ngx.log(ngx.ERR, 'get MD5KV failed' .. res)
        return nil
    end

    -- 如果md5表里没东西也就不需要更新和删除
    if utils.tableIsEmpty(res) then
        return nil
    end

    return redisArrayToTable(res)
end

function _M.conf_cache_base(one_conf)
    local cache_size = one_conf.cache_size
    local md5_cache = one_conf.md5_cache
    local cache = one_conf.cache

    -- 获取所有的md5
    local status, md5_res = pcall(
        function ()
            return getMd5ConfHashMap(one_conf.redis_client)
        end
    )

    if not status then
        ngx.log(ngx.ERR, 'get MD5KV failed for ' .. one_conf.name)
        return nil
    end

    -- 如果md5表里没东西也就不需要更新和删除
    if utils.tableIsEmpty(md5_res) then
        if one_conf.check_empty then
            -- 如果是需要检查的配置，这里需要报警
            ngx.log(ngx.ERR, 'MD5KV is empty for ' .. one_conf.name)
        end
        return nil
    end

    if #md5_res > cache_size then
        ngx.log(ngx.ERR, 'MD5KV size is larger than cache size for ' .. one_conf.name)
    end

    -- 用来记录哪些是新的配置，哪些是需要更新的配置
    local isLive_map = {}

    for id, new_md5 in pairs(md5_res) do
        -- 获取之前的md5
        local confmd5_table = md5_cache:get(id)

        -- 说明这个id存在
        isLive_map[id] = 1

        -- 这里只做对缓存中存在的配置进行更新判断，首先要在旧缓存中存在，如果新旧缓存内不一样说明变更了
        -- 不在这里更改媒体配置的缓存，而是标记需要更新，请求使用配置时通过这个标记判断需不需要更新，在这里不读取redis
        if utils.tableIsNotEmpty(confmd5_table) then
            local old_md5 = confmd5_table.conf_md5
            if old_md5 ~= new_md5 then
                local new_confmd5_table = {
                    conf_md5 = new_md5,
                    update_tag = 1
                }
                md5_cache:set(id, new_confmd5_table)
            end
        else
            -- 如果旧缓存中没有这个id，说明是新的配置，需要读取redis并塞入缓存
            local new_confmd5_table = {
                conf_md5 = new_md5,
                update_tag = 1
            }
            md5_cache:set(id, new_confmd5_table)
        end
    end

    -- 这里做删除
    -- 获取缓存里所有的md5对应的id
    local id_list = md5_cache:get_keys()

    for _, id in ipairs(id_list) do
        -- 所有还存在的id都在这个表里，如果在表里找不到说明被删除了
        if 1 ~= isLive_map[id] then
            cache:delete(id)
            md5_cache:delete(id)
        end
    end
end

function _M.conf_cache()
    local conf_map = {
        supplier_conf,
    }

    for _, one_conf in ipairs(conf_map) do
        _M.conf_cache_base(one_conf)
    end

end

local function readFromRedis(redis_client, id, is_zip)
    local res, err = redis_client:get(id)
    
    if err ~= nil then -- redis error
        error(err)
    else
        if res ~= nil then -- key found
            -- 使用gzip对字符串进行解压缩
            if is_zip then
                res = utils.decompress(ngx.decode_base64(res))
            end
            local res_table = json.decode(res)
            return res_table
        else -- key not found
            ngx.log(ngx.WARN, 'id: '.. id .. ' not found')
            return nil
        end
    end
end

-- iszip用来判断是否需要解压缩，true需要解压，false不需要
local function getConfById(key, conf)
    local conf_md5_cache = conf.md5_cache
    local conf_cache = conf.cache
    local conf_redis_client = conf.redis_client
    local is_zip = conf.is_zip

    local conf_tbl = conf_cache:get(key)
    -- 读取redis的中新的配置并塞入cache的行为在这里进行，需要读取update_tag来判断是否需要更新
    local conf_md5_tbl = conf_md5_cache:get(key)

    if utils.tableIsEmpty(conf_md5_tbl) then
        -- confmd5_tbl为空说明肯定没有这个id的配置
        return nil
    elseif 1 == utils.tblElement(conf_md5_tbl, 'update_tag') then
        -- 如果update_tag为1说明需要更新
        conf_tbl = readFromRedis(conf_redis_client, key, is_zip)
        if utils.tableIsNotEmpty(conf_tbl) then
            -- 如果读取到了配置信息，需要更新缓存
            conf_cache:set(key, conf_tbl)
            conf_md5_tbl.update_tag = 0
            conf_md5_cache:set(key, conf_md5_tbl)
            return conf_tbl
        else
            return nil
        end
    else
        -- 如果update_tag为0说明不需要更新，直接返回缓存中的配置
        return conf_tbl
    end
end

-- Supplier conf
function _M.getSuppliersInfo(adspotid)
    return getConfById(adspotid, supplier_conf)
end

return _M