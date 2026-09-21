local _M = {}
local strategy = _M

local utils = require 'tools.utils'
local obj_cache = require 'tools.obj_cache'

local STRATEGY_DIRECT_PLUGINS = {
    {func_name = 'isHitAppVersionDirection', reason = 'App版本定向'},
    {func_name = 'isHitSdkVersionDirection', reason = 'SDK版本定向'},
    {func_name = 'isHitLocationDirection', reason = '地域定向过滤'},
    {func_name = 'isHitMakeDirection', reason = '手机制造商定向过滤'},
    {func_name = 'isHitOsVersionDirection', reason = 'Os版本定向过滤'}
}

local SUPPLIER_DIRECT_PLUGINS = {
    {func_name = 'isHitLocationDirection', reason = '地域定向过滤'},
    {func_name = 'isHitAppVersionDirection', reason = 'App版本定向过滤'},
    {func_name = 'isHitOsVersionDirection', reason = 'Os版本定向过滤'},
    {func_name = 'isHitMakeDirection', reason = '手机制造商定向过滤'},
    {func_name = 'deviceDailyReqLimit', reason = '单设备日请求次数限制'},
    {func_name = 'deviceDailyImpLimit', reason = '单设备日曝光次数限制'},
    {func_name = 'supplierDailyReqLimit', reason = '渠道日请求次数限制'},
    {func_name = 'supplierDailyImpLimit', reason = '渠道日曝光次数限制'},
    {func_name = 'supplierRequestInterval', reason = '单设备请求渠道时间间隔限制'}
}

local function doGroupSelect()
    local random_data = math.random(1, 100)
    local rate = 0
    for _, group in ipairs(ngx.ctx.traffic) do
        rate = rate + tonumber(group.percentage)
        if random_data <= rate then
            ngx.ctx.select_group = group
            break
        end
    end
end

local function makeStrategyDirectPlugins()
    local strategy_direct_plugins = {}

    local plugin = utils.loadModule("plugin.strategy_selector")

    if plugin == nil then
        ngx.log(ngx.ERR, 'Loading strategy selector plugin error')
        return strategy_direct_plugins
    end

    for _, func in ipairs(STRATEGY_DIRECT_PLUGINS) do
        table.insert(strategy_direct_plugins, {func = plugin[func.func_name], reason = func.reason})
    end

    return strategy_direct_plugins
end

local function hitStrategy(nut, strategy)
    local strategy_direct_plugins = makeStrategyDirectPlugins()

    for _, plugin in ipairs(strategy_direct_plugins) do
        local res = plugin.func(strategy, nut)
        if false == res then
            return false
        end
    end

    return true
end


local function doStrategySelect(nut)
    -- 如果group选则为空，那么就没有选到分组，选择的策略也置为nil
    if utils.tableIsEmpty(ngx.ctx.select_group) then
        ngx.ctx.select_strategy = nil
    else
        for _, strategy in ipairs(ngx.ctx.select_group.strategy) do
            if hitStrategy(nut, strategy) then
                ngx.ctx.select_strategy = strategy
                break
            end
        end
    end

    -- 最后将选中的策略的suppliers进行copy到原结构体，后面的代码就不用太调整了
    if utils.tableIsEmpty(ngx.ctx.select_strategy) then
        nut.suppliers_conf = {}
    else
        -- 现在strategy下面还有一层 strategyPercentageList
        -- 这里是一个百分比的列表，按照百分比来随机选择一个策略组
        local random_data = math.random(1, 100)
        local rate = 0
        for _, strategy_percentage in ipairs(ngx.ctx.select_strategy.strategyPercentageList) do
            rate = rate + tonumber(strategy_percentage.percentage)
            if random_data <= rate then
                ngx.ctx.select_strategy_percentage = strategy_percentage
                break
            end
        end

        if utils.tableIsEmpty(ngx.ctx.select_strategy_percentage) then
            nut.suppliers_conf = {}
        else
            -- 这里将suppliers进行深拷贝，避免后续的代码对suppliers_conf的修改影响到suppliers
            nut.suppliers_conf = utils.deepcopy(ngx.ctx.select_strategy_percentage.suppliers)
        end
    end

end

local function buildReqhis(nut, supplier)
    local reqhis_item = {
        sid = nut.sid,
        appid = nut.pv_req.appid,
        adspotid = nut.pv_req.adspotid,
        ip = nut.pv_req.ip,
        supplier_id = supplier.id,
        supplier_name = supplier.name,
        meta_appid = supplier.appid,
        meta_adspotid = supplier.adspotid,
        filtered_reason = 'no filtered',
        filtered_code = '0',
    }

    return reqhis_item
end

local function creatReqhisTable(nut)
    if utils.tableIsEmpty(nut.suppliers_conf) then
        ngx.log(ngx.WARN, 'select percentage suppliers config is null')
        return
    end

    for _, supplier in ipairs(nut.suppliers_conf) do
        -- init reqhis
        local reqhis_item = buildReqhis(nut, supplier)
        nut.reqhis_table[supplier.supplier_key] = reqhis_item
    end
end

local function runSupplierPlugins(plugins, supplier, nut)
    for _, plugin in ipairs(plugins) do
        local res = plugin.func(supplier, nut)
        -- 如果不满足，渠道不被选择中
        if false == res then
            utils.updateReqhisTable(nut, supplier.supplier_key, plugin.reason)
            return false
        end
    end

    return true
end

local function makeSupplierDirectPlugins()
    local supplier_direct_plugins = {}

    local plugin = utils.loadModuleIfAvailable("plugin.supplier_selector")

    if plugin == nil then
        ngx.log(ngx.ERR, 'Loading supplier selector plugin error')
        return supplier_direct_plugins
    end

    for _, func in ipairs(SUPPLIER_DIRECT_PLUGINS) do
        table.insert(supplier_direct_plugins, {func = plugin[func.func_name], reason = func.reason})
    end

    return supplier_direct_plugins
end

local function doSupplierDirection(nut)
    for _, sp in ipairs(nut.suppliers_conf) do
        local supplier = utils.deepcopy(sp)

        local supplier_direct_plugins = makeSupplierDirectPlugins()

        if runSupplierPlugins(supplier_direct_plugins, supplier, nut) then
            table.insert(nut.suppliers, supplier)
            
            -- 对选中的supplier进行标记判断，若存在标记则需要进行对应redis的更新
            -- 渠道请求频次限制
            if true == supplier.supplier_req_limit_tag then
                obj_cache.addSupplyReqLimit(nut, supplier)
            end

            -- 设备请求频次限制
            if true == supplier.device_req_limit_tag then
                local device_id = utils.getDeviceUniqueId(nut.pv_req)
                if utils.isNotEmpty(device_id) then
                    obj_cache.addDeviceReqLimit(device_id, nut, supplier)
                end
            end

            -- 设备请求间隔控制
            if true == supplier.request_interval_tag then
                local device_id = utils.getDeviceUniqueId(nut.pv_req)

                if utils.isNotEmpty(device_id) then
                    local device_plus_key = utils.getDeviceAdspotSupplierRequestIntervalKey(device_id, nut, supplier)
                    obj_cache.addDeviceRequestInterval(device_plus_key, supplier.request_limit.device_request_interval)
                end
            end
        end

        -- 记录广告位上的频次/间隔控制
        if #nut.suppliers > 0 then
            if utils.tableIsNotEmpty(nut.pv_prop.request_limit)
                    and utils.isNotEmpty(nut.pv_prop.request_limit.device_daily_req_limit)
                    and tonumber(nut.pv_prop.request_limit.device_daily_req_limit) > 0 then
                local device_id = utils.getDeviceUniqueId(nut.pv_req)
                if utils.isNotEmpty(device_id) then
                    local field = utils.concatByUnderscore(nut.pv_req.adspotid, 'adspot_req')
                    obj_cache.addDeviceLimit(device_id, field)
                end
            end

            if utils.tableIsNotEmpty(nut.pv_prop.request_limit)
                    and utils.isNotEmpty(nut.pv_prop.request_limit.device_request_interval)
                    and tonumber(nut.pv_prop.request_limit.device_request_interval) > 0 then
                local device_id = utils.getDeviceUniqueId(nut.pv_req)
                if utils.isNotEmpty(device_id) then
                    local device_adspot_key = utils.concatByUnderscore(device_id, nut.pv_req.adspotid, 'adspot')
                    obj_cache.addDeviceRequestInterval(device_adspot_key, tonumber(nut.pv_prop.request_limit.device_request_interval))
                end
            end
        end
    end
end

local function supplierSelect(nut)
    -- doing normal direction
    doSupplierDirection(nut)
end

local function sortByPriority(rsp_a, rsp_b)
    local pa = tonumber(rsp_a.priority)
    local pb = tonumber(rsp_b.priority)

    if pa == pb then
        local ia = tonumber(rsp_a.index)
        local ib = tonumber(rsp_b.index)
        return ia < ib
    else
        return pa < pb
    end
end

local function supplierPriority(nut)
    table.sort(nut.suppliers, sortByPriority)
end

local function parallelHeadGroupSetting(nut)
    if utils.tableIsEmpty(nut.suppliers) then
        return
    end

    -- 增加了一个判定是否有并行的参数，目前没有使用，可能后面可以用
    local has_parallel_setting = false
    local parallel_group = {}
    local head_bidding_group = {}
    local priority = nut.suppliers[1].priority
    local each_group = {}
    for k, sp in ipairs(nut.suppliers) do
        -- 遇到head_bidding的sdk直接加到head_bidding组
        if 1 == sp.is_head_bidding then
            table.insert(head_bidding_group, k)
        else
            if sp.priority == priority then
                table.insert(each_group, k)
            else
                -- 增加一个判定，如果each_group里面是超过一个sdk supplier，则是真的有并行的sdk
                if #each_group > 1 then
                    has_parallel_setting = true
                end
                -- 因为存在有head bidding的sdk，该sdk会被放置到单独的队列，所以这里处理时候要加一个判定，不把空的group放到parallel group里面
                if utils.tableIsNotEmpty(each_group) then
                    table.insert(parallel_group, utils.deepcopy(each_group))
                end
                each_group = {}
                priority = sp.priority
                table.insert(each_group, k)
            end
        end
    end

    -- 如果最终each_group为空，则不再往parallel_group插入group
    -- 否则后续json encode 会出现table list
    if utils.tableIsNotEmpty(each_group) then
        table.insert(parallel_group, utils.deepcopy(each_group))
    end

    nut.head_bidding_group = head_bidding_group
    nut.parallel_group_setting = parallel_group
    nut.has_parallel_setting = has_parallel_setting
end

function _M.doProcess(nut)
    -- Group Select
    doGroupSelect()

    -- Strategy Select
    doStrategySelect(nut)

    -- creat reqhis table
    creatReqhisTable(nut)

    -- suppliers list select
    supplierSelect(nut)
    if utils.tableIsEmpty(nut.suppliers) then
        ngx.log(ngx.WARN, 'create suppliers list is null')
        return
    end

    -- supplier priority
    supplierPriority(nut)

    -- parallel group setting & head bidding group setting
    parallelHeadGroupSetting(nut)
end

return strategy
