local _M = {}
local http_parser = _M

local utils = require 'tools.utils'


function _M.doProcess(nut)
    -- read body first
    ngx.req.read_body()

    -- http request parser
    nut.http_req = {
        real_ip = ngx.var.remote_addr,
        port = ngx.var.server_port,
        ua = ngx.var.http_user_agent,
        headers = ngx.req.get_headers(),
        method = ngx.var.request_method,
        path = ngx.var.document_uri,
        query_args = ngx.req.get_uri_args(),
        body = ngx.req.get_body_data(),
        hostname = ngx.var.hostname,
    }
end

return http_parser
