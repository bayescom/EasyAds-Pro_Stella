local function httpd()
    ngx.say("OK")
    ngx.exit(ngx.HTTP_OK)
end

httpd()
