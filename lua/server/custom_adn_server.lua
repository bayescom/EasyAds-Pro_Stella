local json = require 'cjson.safe'
local utils = require 'tools.utils'
local conf_cache = require 'tools.conf_cache'

local function handleCustomAdn()
    local query = ngx.req.get_uri_args()
    local appid = query.appid
    local version = query.version

    if utils.isEmpty(appid) then
        return json.encode({ msg = 'appid is required' }), ngx.HTTP_BAD_REQUEST
    end

    local conf_tbl = conf_cache.getCustomAdnInfo(appid)
    if utils.tableIsEmpty(conf_tbl) then
        return json.encode({
            version = '',
            custom_adn_list = json.empty_array,
        }), ngx.HTTP_OK
    end

    local current_version = conf_tbl.version
    local rsp = {
        version = current_version,
    }

    if utils.isNotEmpty(version) and version == current_version then
        rsp.custom_adn_list = json.empty_array
    else
        rsp.custom_adn_list = conf_tbl.custom_adn_list
        if utils.tableIsEmpty(rsp.custom_adn_list) then
            rsp.custom_adn_list = json.empty_array
        end
    end

    return json.encode(rsp), ngx.HTTP_OK
end

local function httpd()
    local status, result, code = pcall(
        function()
            return handleCustomAdn()
        end
    )

    if status then
        ngx.header['Content-Type'] = 'application/json'
        ngx.header['Access-Control-Allow-Origin'] = '*'
        ngx.status = code
        ngx.say(result)
        ngx.exit(code)
    else
        ngx.log(ngx.ERR, result)
        ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
        ngx.say('500 INTERNAL_SERVER_ERROR')
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
end

httpd()
