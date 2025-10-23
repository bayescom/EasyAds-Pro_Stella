local _M = {}
local entity = _M

_M.enum_rsp_status = {
    http_ok = 0,
    http_not_ok = -1
}

_M.enum_os = {
    unknown     = 0,
    ios         = 1,
    android     = 2
}

_M.enum_bidding_type = {
    aggregate_bidding = 0,
}

_M.enum_log_type = {
    ['local'] = 'local',
    ['server'] = 'server,'
}

return entity
