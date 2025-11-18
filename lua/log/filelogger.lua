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

-- slog config
local slog_file_path = "./slog/"
-- 全部迁移到 log_state 内
local log_state = {}

local function getNowDateHour()
    return os.date("%Y-%m-%d_%H", unixtime)
end

local function get_log_file_path(log_source, nowDateHour)
    return slog_file_path .. log_source .. "." .. nowDateHour .. ".log"
end

local function reset_log_state(log_source, log_fd, nowDateHour)
    log_state[log_source] = {
        log_fd = log_fd,
        pre_hour = nowDateHour,
        now_hour = nowDateHour,
        logger_initted = true,
    }
end

local function file_rolling(log_source)
    local st = log_state[log_source]
    if not st then
        return
    end

    local nowDateHour = getNowDateHour()

    if nowDateHour ~= st.now_hour then
        C.close(st.log_fd)

        local log_file = get_log_file_path(log_source, nowDateHour)

        local new_log_fd = C.open(log_file, bor(O_RDWR, O_CREAT, O_APPEND), bor(S_IRWXU, S_IRGRP, S_IROTH))

        if not new_log_fd or new_log_fd < 0 then
            ngx.log(ngx.ERR, "Failed to open file : [" .. log_file .. "]")
            return
        end

        -- 更新当前 log source 的状态
        st.log_fd = new_log_fd
        st.pre_hour = st.now_hour
        st.now_hour = nowDateHour
    end
end

function _M.init(log_source)
    local nowDateHour = getNowDateHour()
    local log_file = get_log_file_path(log_source, nowDateHour)

    local log_fd = C.open(log_file, bor(O_RDWR, O_CREAT, O_APPEND), bor(S_IRWXU, S_IRGRP, S_IROTH))

    if not log_fd or log_fd < 0 then
        ngx.log(ngx.ERR, "Failed to open file : [" .. log_file .. "]")
        return nil, "failed to open file"
    else
        reset_log_state(log_source, log_fd, nowDateHour)
        return true
    end
end

function _M.log(msg, log_source)
    local st = log_state[log_source]

    if not st then
        local ok = _M.init(log_source)
        if not ok then
            ngx.log(ngx.ERR, "Failed to init logger for source: ", log_source)
            return
        end
        st = log_state[log_source]
    end

    file_rolling(log_source)
    local log_fd = st.log_fd

    if log_fd then
        C.write(log_fd, msg, #msg)
    else
        ngx.log(ngx.ERR, "Failed to write file, no fd for source: ", log_source)
    end
end

function _M.initted(log_source)
    return log_state[log_source] and log_state[log_source].logger_initted
end

return _M
