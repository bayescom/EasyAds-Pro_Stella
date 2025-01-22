
local _M = {}

local conf = _M

_M.log_type = "local"  -- local为本地日志，server为上报服务器

-- 上报服务器地址
_M.track = {
    url = 'http://stellar.yourdomain.com'
}

-- 设备信息SDK端加密秘钥，SDK和这里要同步修改
_M.encryption_keys = {
    device_enc_key = 'yourkey',
}

_M.center_syslog_ng = {
    host = '127.0.0.1',
    port = 12001,
    flush_limit = 1,               -- 4096 4KB
    drop_limit = 10485760,         -- 10485760 10MB
}

_M.redis = {
    host = '127.0.0.1',
    port = 6379,
    passwd = 'yourpassword',
    media_db = 1,            -- 媒体广告位配置信息
}

_M.frequency_redis = {
    host = '127.0.0.1',
    port = 6379,
    passwd = 'yourpassword',
    sdk_device_limit_db = 2,    -- 单设备在渠道上的日请求/曝光限制
    sdk_supplier_limit_db = 3,  -- 渠道请求/曝光日限制
    sdk_device_interval_db = 4, -- 单设备渠道请求间隔限制
}

return conf
