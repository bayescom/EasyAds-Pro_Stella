local entity = require 'bean.entity'
local utils = require 'tools.utils'
local conf = require 'conf'
local json = require 'cjson.safe'
local net_url = require 'net.url'
local b64 = require("ngx.base64")

local _M = {}
local response_maker = _M

local function genTrackUrlCommon(nut, track_url)
    track_url.query.adspotid = nut.pv_req.adspotid
    track_url.query.appid = nut.pv_req.appid
    track_url.query.request_time = nut.pv_req.time
    track_url.query.version = nut.pv_req.version
    track_url.query.bid_time = ngx.now() * 1000

    if utils.isNotEmpty(nut.pv_rsp.abtag) then
        track_url.query.abtag = nut.pv_rsp.abtag
    end

    if utils.isNotEmpty(nut.pv_req.sdk_version) then
        track_url.query.sdk_version = nut.pv_req.sdk_version
    end

    track_url.query.reqid = nut.sid

    local device = {}
    if utils.isNotEmpty(nut.pv_req.idfa) then
        device.idfa = nut.pv_req.idfa
        device.os = 1
    else
        if utils.isNotEmpty(nut.pv_req.imei) then
            device.imei = nut.pv_req.imei
        end
        device.os = 2
    end

    device.unique_deviceid = nut.pv_req.unique_deviceid
    -- 注意,dinfo里包含了设备相关的信，目前主要有如下几个字段：
    -- imei/idfa/os/unique_deviceid
    -- 加密方法为 json.encode + base64 url encode 
    if utils.tableIsNotEmpty(device) then
        track_url.query.dinfo = b64.encode_base64url(json.encode(device) or '{}')
    end
end

local function setSupplierTrackUrl(track_url, index, supplier)
    track_url.query.priority = index
    track_url.query.sdk_adspotid = utils.NilDefault(supplier.adspotid, "")
    track_url.query.supplierid = supplier.id
    track_url.query.sdk_id = supplier.sdk_id
    track_url.query.track_time = '__TIME__'
end

local function genSupplierInfoSetting(index, supplier, sdk_version)
    local supplier_info = {}
    supplier_info.id = supplier.id
    supplier_info.name = supplier.name
    supplier_info.index = index
    supplier_info.priority = index
    supplier_info.timeout = tonumber(supplier.timeout)
    supplier_info.adspotid = utils.NilDefault(supplier.adspotid, '')
    supplier_info.sdktag = utils.NilDefault(supplier.sdk_tag, '')
    supplier_info.sdk_price = utils.NilDefault(supplier.sdk_price, 0)
    supplier_info.bid_ratio = utils.NilDefault(supplier.bid_ratio, 1.0)
    supplier_info.is_head_bidding = utils.NilDefault(supplier.is_head_bidding, 0)
    supplier_info.mediaid = utils.NilDefault(supplier.appid, '')
    supplier_info.mediakey = utils.NilDefault(supplier.app_key, '')
    supplier_info.mediasecret = utils.NilDefault(supplier.app_secret, '')
    supplier_info.ext = supplier.ext
    supplier_info.imptk= {}
    supplier_info.clicktk = {}
    supplier_info.loadedtk = {}
    supplier_info.succeedtk = {}
    supplier_info.failedtk = {}
    supplier_info.wintk = {}
    
    return supplier_info
end

local function addVariousTrack(supplier_info, supplier, track_url)
    local track = {
        {'win', supplier_info.imptk},
        {'click', supplier_info.clicktk},
        {'loaded', supplier_info.loadedtk},
        {'succeed', supplier_info.succeedtk},
        {'failed', supplier_info.failedtk},
        {'bidwin', supplier_info.wintk},
    }

    -- 这里统一改成track
    track_url.path = "track"

    for _, tkinfo in ipairs(track) do
        local action = tkinfo[1]
        track_url.query.action = action

        -- special process for imp track url
        if "win" == action then
            -- 如果不在这里复制一个新的，会导致后续其他所有的上报串都会带上后面的几个字段
            local win_track_url = utils.deepcopy(track_url)
            -- 新增 sdk_price
            win_track_url.query.sdk_price = supplier_info.sdk_price
            -- 增加设备曝光频控
            if true == supplier.device_imp_limit_tag then
                win_track_url.query.device_imp_limit_tag = 1
            end
            -- 增加sdk 渠道曝光频控
            if true == supplier.supplier_imp_limit_tag then
                win_track_url.query.supplier_imp_limit_tag = 1
            end

            -- 当 action 为 win 的时候，track 对象肯定存在，所以不用判断
            table.insert(tkinfo[2], tostring(win_track_url))
        else
            -- 当 action 为 bidwin 的时候，track 对象不一定存在，所以需要判断
            if tkinfo[2] ~= nil then
                table.insert(tkinfo[2], tostring(track_url))
            end
        end
    end
end

local function abTagSetting(nut)
    if utils.tableIsNotEmpty(ngx.ctx.select_group) then
        -- 这个是新的ABTest的tag设置
        nut.pv_rsp.group_id = ngx.ctx.select_group.group_id
        nut.pv_rsp.group_exp_id = ngx.ctx.select_group.group_percentage_exp_id
    end

    if utils.tableIsNotEmpty(ngx.ctx.select_strategy) then
        -- 这个是新的ABTest的打印字段
        nut.pv_rsp.strategy_id = ngx.ctx.select_strategy.strategy_id
    end

    if utils.tableIsNotEmpty(ngx.ctx.select_strategy_percentage) then
        -- 这个是新的ABTest的tag设置
        nut.pv_rsp.strategy_percentage_id = ngx.ctx.select_strategy_percentage.strategy_percentage_id
        nut.pv_rsp.strategy_percentage_exp_id = ngx.ctx.select_strategy_percentage.strategy_percentage_exp_id
    end
end


local function parallelGroupSetting(nut)
    if utils.tableIsEmpty(nut.pv_rsp.setting) then
        nut.pv_rsp.setting = {}
    end

    -- 设置每一个并发层的超时等待时间
    nut.pv_rsp.setting.parallel_timeout = 5000

    nut.pv_rsp.setting.parallel_group = nut.parallel_group_setting
    
    if utils.tableIsEmpty(nut.pv_rsp.setting.parallel_group) then
        nut.pv_rsp.setting.parallel_group = json.empty_array
    end
end

local function headBiddingConfSetting(nut)
    if utils.tableIsEmpty(nut.pv_rsp.setting) then
        nut.pv_rsp.setting = {}
    end

    -- Head Bidding Group Setting
    if utils.tableIsNotEmpty(nut.head_bidding_group) then
        nut.pv_rsp.setting.head_bidding_group = nut.head_bidding_group
    else
        nut.pv_rsp.setting.head_bidding_group = json.empty_array
    end
end


function _M.doProcess(nut)
    local suppliers = {}

    if utils.tableIsNotEmpty(nut.suppliers) then
        abTagSetting(nut)

        -- setting parallel_group
        parallelGroupSetting(nut)

        -- setting head_bidding_group
        headBiddingConfSetting(nut)

        nut.pv_rsp.setting.bidding_type = entity.enum_bidding_type.aggregate_bidding

        local track_url = net_url.parse(conf.track.url)
        genTrackUrlCommon(nut, track_url)

        for k, supplier in ipairs(nut.suppliers) do
            setSupplierTrackUrl(track_url, k, supplier)
            local supplier_info = genSupplierInfoSetting(k, supplier, nut.pv_req.sdk_version)
            addVariousTrack(supplier_info, supplier, track_url)
            table.insert(suppliers, supplier_info)
        end
    end

    nut.pv_rsp.reqid = nut.sid
    if utils.tableIsNotEmpty(suppliers) then
        nut.pv_rsp.msg = "SUCCESS"
        nut.pv_rsp.suppliers = suppliers
        nut.pv_rsp.code = ngx.HTTP_OK
    else
        nut.pv_rsp.msg = nut.pv_rsp_msg or "NOBID"
        nut.pv_rsp.code = ngx.HTTP_NO_CONTENT
    end

    local rsp = utils.deepcopy(nut.pv_rsp)
    nut.http_rsp.body = json.encode(rsp)
    nut.http_rsp.code = ngx.HTTP_OK
end

return response_maker