local _M = {}
local dlog = _M

local utils = require 'tools.utils'

function _M.error(log)
    if utils.tableIsEmpty(ngx.ctx.error_log) then
        ngx.ctx.error_log = {}
    end
    table.insert(ngx.ctx.error_log, {msg = log})
end

function _M.logReq(log)
    ngx.ctx.req_log = log
end

function _M.logLoaded(log)
    ngx.ctx.loaded_log = log
end

function _M.logSucceed(log)
    ngx.ctx.succeed_log = log
end

function _M.logBidWin(log)
    ngx.ctx.bidwin_log = log
end

function _M.logWin(log)
    ngx.ctx.win_log = log
end

function _M.logClick(log)
    ngx.ctx.click_log = log
end

function _M.logFailed(log)
    ngx.ctx.failed_log = log
end

function _M.logReward(log)
    ngx.ctx.reward_log = log
end

function _M.logSdkEvent(log)
    ngx.ctx.sdkevent_log = log
end

return dlog
