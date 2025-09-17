local json = require 'cjson.safe'
local utils = require 'tools.utils'
local file_logger = require "log.filelogger"
local conf = require 'conf'
local socket_logger = require "resty.logger.socket"

local function initFileLogger()
    local file_path = "./slog/track."

    if not file_logger.initted() then
        local ok, err = file_logger.init(file_path)
        if not ok then
            ngx.log(ngx.ERR, "failed to initialize the local logger: ", err)
            return
        end
    end
end

local function initSocketLogger()
    if conf.center_syslog_ng ~= nil then
        if not socket_logger.initted() then
            local ok, err = socket_logger.init{
                host        = conf.center_syslog_ng.host,
                port        = conf.center_syslog_ng.port,
                flush_limit = conf.center_syslog_ng.flush_limit,
                drop_limit  = conf.center_syslog_ng.drop_limit
            }
            if not ok then
                ngx.log(ngx.ERR, "failed to initialize the center logger: ", err)
                return
            end
        end
    end
end

-- 发送到syslog-ng的日志
local function syslogngOutput(log)
    socket_logger.log(log)
end

-- 发送到fluentd的日志，先还是output到本地文件夹
local function localOutput(log)
    file_logger.log(log)
end

-- 公共日志输出函数
local function outputLog(events, logFunc)
    for _, actionName in ipairs(events) do
        local fullLogName = utils.concatByUnderscore(actionName, 'log')
        local logData = ngx.ctx[fullLogName]

        if utils.tableIsNotEmpty(logData) then
            local log = utils.concat(json.encode(logData), '\n')
            logFunc(log)
        end
    end
end

-- 日志事件列表
local events = {'loaded', 'succeed', 'bidwin', 'win', 'click', 'failed', 'error'}

-- 本地日志输出
local function localLoggerOutput()
    outputLog(events, localOutput)
end

-- 服务端日志输出
local function serverLoggerOutput()
    outputLog(events, syslogngOutput)
end

local function logOutput()
    if conf.log_type == 'server' then
        initSocketLogger()
        serverLoggerOutput()
    else
        initFileLogger()
        localLoggerOutput()
    end
end    

logOutput()