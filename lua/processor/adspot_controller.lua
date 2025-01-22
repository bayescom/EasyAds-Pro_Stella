local utils = require "tools.utils"

local _M = {}
local adspot_controller = _M

local ADSPOT_CONTROLLER_PLUGIS = {
    {func_name = 'deviceDailyAdspotReqLimit', reason = '单设备广告位请求次数限制'},
    {func_name = 'deviceDailyAdspotImpLimit', reason = '单设备广告位曝光次数限制'},
    {func_name = 'deviceDailyAdspotRequestInterval', reason = '单设备广告位请求间隔限制'},
}

local function makeControllerPlugins()
    local controller_plugins = {}

    local plugin = utils.loadModuleIfAvailable("plugin.controller")

    if plugin == nil then
        ngx.log(ngx.ERR, 'Loading controller plugin error')
        return controller_plugins
    end

    for _, func in ipairs(ADSPOT_CONTROLLER_PLUGIS) do
        table.insert(controller_plugins, {func = plugin[func.func_name], reason = func.reason})
    end

    return controller_plugins
end

local function doAdspotController(nut)
    local controller_plugins = makeControllerPlugins()
    for _, plugin in ipairs(controller_plugins) do
        local res = plugin.func(nut)
        if true == res then
            nut:setFiltered("AdspotController", plugin.reason, ngx.HTTP_OK)
            return
        end
    end
end

function _M.doProcess(nut)
    doAdspotController(nut)
end

return adspot_controller