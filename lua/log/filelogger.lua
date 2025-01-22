local bit = require "bit"
local ffi = require "ffi"
local C = ffi.C
local bor = bit.bor

ffi.cdef[[
int write(int fd, const char *buf, int nbyte);
int open(const char *path, int access, int mode);
int close(int fd);
]]

local O_RDWR   = 0X0002
local O_CREAT  = 0x0040
local O_APPEND = 0x0400
local S_IRWXU  = 0x01C0
local S_IRGRP  = 0x0020
local S_IROTH  = 0x0004

local succ, new_tab = pcall(require, "table.new")
if not succ then
    new_tab = function () return {} end
end
local _M = new_tab(0,5)

--config
local pre_hour
local now_hour
local logger_initted
local log_fn
local log_fd

local function getNowDateHour()
    return os.date("%Y-%m-%d_%H", unixtime)
end

local function file_rolling()
    local nowDateHour = getNowDateHour()
    if nowDateHour ~= now_hour then
        C.close(log_fd)
        local logfile = log_fn..""..nowDateHour..".log"
        pre_hour = now_hour
        now_hour = nowDateHour
        log_fd = C.open(logfile, bor(O_RDWR, O_CREAT, O_APPEND), bor(S_IRWXU, S_IRGRP, S_IROTH))
        if nil == log_fd then
            ngx.log(ngx.ERR, "Failed to open file : ["..logfile.."]")
        end
    end
end

function _M.init(filename)
    local nowDateHour = getNowDateHour()
    log_fn = filename
    local log_file = filename..""..nowDateHour..".log"
    log_fd = C.open(log_file, bor(O_RDWR, O_CREAT, O_APPEND), bor(S_IRWXU, S_IRGRP, S_IROTH))
    if nil == log_fd then
        ngx.log(ngx.ERR, "Failed to open file : ["..log_file.."]")
        return nil, "failed to open file"
    else
        pre_hour = nowDateHour
        now_hour = nowDateHour
        logger_initted = true
        return logger_initted
    end
end

function _M.log(msg)
    file_rolling()
    if nil ~= log_fd then
        C.write(log_fd, msg, #msg)
    else
        ngx.log(ngx.ERR, "Failed to write file")
    end
end

function _M.initted()
    return logger_initted
end

return _M