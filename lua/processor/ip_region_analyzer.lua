local _M = {}
local ip_region_analyzer = _M

local geo = require 'resty.maxminddb'
local maxmind_convert = require 'tools.ip.maxmind_geo_convert'


function _M.doProcess(nut)
    if not geo.initted() then
        geo.init("./data/GeoLite2-City.mmdb")
    end

    local res, err = geo.lookup(nut.pv_req.ip)

    if not res then
        ngx.log(ngx.ERR, "failed to lookup ip: ", err)
        return
    end

    ngx.ctx.ip_info = maxmind_convert.convert(res)
end

return ip_region_analyzer
