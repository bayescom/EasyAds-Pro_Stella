local json = require 'cjson.safe'
local utils = require 'tools.utils'
local file_logger = require 'log.filelogger'
local conf = require 'conf'
local socket_logger = require "resty.logger.socket"

local log_source = 'sdkevent'

local function initFileLogger()
    if not file_logger.initted(log_source) then
        local ok, err = file_logger.init(log_source)
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
    file_logger.log(log, log_source)
end

-- 公共日志输出函数
local function outputLog(logFunc)
    local event = 'sdkevent'

    local full_log_name = utils.concatByUnderscore(event, 'log')
    if utils.tableIsNotEmpty(ngx.ctx[full_log_name]) then
        local log = utils.concat(json.encode(ngx.ctx[full_log_name]), '\n')
        logFunc(log)
    end  
end

-- 本地日志输出
local function localLoggerOutput()
    outputLog(localOutput)
end

-- 服务端日志输出
local function serverLoggerOutput()
    outputLog(syslogngOutput)
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