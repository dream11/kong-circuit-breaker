local _M = {}

_M.fixtures = {
    http_mock = {
    circuit_breaker = [[

        server {
            server_name app_config_10001;
            listen 10001;
            charset utf-8;
                charset_types application/json;
                default_type application/json;

            location = "/test" {
                content_by_lua_block {
                    print("nginx worker id : ")
                    print(ngx.worker.id())

                    local request_headers = ngx.req.get_headers()

                    if request_headers["put_delay"] then
                        ngx.sleep(tonumber(request_headers["put_delay"]))
                    end

                    ngx.status = tonumber(request_headers["response_http_code"])

                    ngx.say("success")
                    return ngx.exit(0)
                }
            }
        }
  ]]
  },
}


return _M