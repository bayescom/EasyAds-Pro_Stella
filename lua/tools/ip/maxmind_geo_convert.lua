local _M = {}
local maxmind_geo_convert = _M

local utils = require 'tools.utils'
local geo_id_mapping = require 'tools.ip.geo_id_mapping'

-- 将maxmind的解析结果转换成我们定义的结构体及值
-- 我们定义的地区id值见README文件
function _M.convert(maxmind_res)
    local maxmind_res_city = maxmind_res.city

    if utils.tableIsEmpty(maxmind_res_city) then
        return nil
    end

    local geoname_id = tostring(maxmind_res_city.geoname_id)
    local province_id = nil
    local city_id = geo_id_mapping.getCityIdByGeoId(geoname_id)
    if city_id == nil then
        province_id = geo_id_mapping.getProvinceIdByGeoId(geoname_id)
    else
        province_id = geo_id_mapping.getProvinceIdByCityId(city_id)
    end

    return {
        province_id = province_id,
        city_id = city_id
    }
end

return maxmind_geo_convert