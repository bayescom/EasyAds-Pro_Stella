
local _M = {}

local conf = _M

_M.log_type = "${LOG_TYPE}"  -- local为本地日志，server为上报服务器

_M.callback_timeout = 3000  -- 回调超时时间，单位毫秒

-- 上报服务器地址
_M.track = {
    url = 'http://${DOMAIN_STELLA}'
}

-- 设备信息SDK端加密秘钥，SDK和这里要同步修改
_M.encryption_keys = {
    device_enc_key = '${SECRET_KEY}',
}

_M.center_syslog_ng = {
    host = '${LOG_URL}',
    port = ${LOG_PORT},
    flush_limit = 1,               -- 4096 4KB
    drop_limit = 10485760,         -- 10485760 10MB
}

_M.redis = {
    host = '${REDIS_URL}',
    port = ${REDIS_PORT},
    passwd = '${REDIS_PASSWORD}',
    media_db = 1,            -- 媒体广告位配置信息
}

_M.frequency_redis = {
    host = '${REDIS_URL}',
    port = ${REDIS_PORT},
    passwd = '${REDIS_PASSWORD}',
    sdk_device_limit_db = 2,    -- 单设备在渠道上的日请求/曝光限制
    sdk_supplier_limit_db = 3,  -- 渠道请求/曝光日限制
    sdk_device_interval_db = 4, -- 单设备渠道请求间隔限制
}

return conf
