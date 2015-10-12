# vi:set ft= ts=4 et:

use Test::Nginx::Socket::Lua;

plan tests => blocks() * 4;

run_tests;

__DATA__

=== TEST 1: simple single echo
--- main_config
    stream {
        server {
            listen 54321;

            echo "Hello, stream echo!";
        }
    }

--- config
    location = /t {
        content_by_lua_block {
            local sock, err = ngx.socket.tcp()
            assert(sock, err)

            local ok, err = sock:connect("127.0.0.1", 54321)
            if not ok then
                ngx.say("connect error: ", err)
                return
            end

            local data, err = sock:receive("*a")
            if not data then
                ngx.say("receive error: ", err)
                return
            end

            ngx.print(data)
        }
    }
--- request
GET /t
--- response_body
Hello, stream echo!
--- no_error_log
[error]
[alert]



=== TEST 2: multiple echos
--- main_config
    stream {
        server {
            listen 54321;

            echo Hi Kindy;
            echo How is "going?";
        }
    }

--- config
    location = /t {
        content_by_lua_block {
            local sock, err = ngx.socket.tcp()
            assert(sock, err)

            local ok, err = sock:connect("127.0.0.1", 54321)
            if not ok then
                ngx.say("connect error: ", err)
                return
            end

            local data, err = sock:receive("*a")
            if not data then
                ngx.say("receive error: ", err)
                return
            end

            ngx.print(data)
        }
    }
--- request
GET /t
--- response_body
Hi Kindy
How is going?

--- no_error_log
[error]
[alert]



=== TEST 3: echo -n
--- main_config
    stream {
        server {
            listen 54321;

            echo -n "hello, ";
            echo 'world';
        }
    }

--- config
    location = /t {
        content_by_lua_block {
            local sock, err = ngx.socket.tcp()
            assert(sock, err)

            local ok, err = sock:connect("127.0.0.1", 54321)
            if not ok then
                ngx.say("connect error: ", err)
                return
            end

            local data, err = sock:receive("*a")
            if not data then
                ngx.say("receive error: ", err)
                return
            end

            ngx.print(data)
        }
    }
--- request
GET /t
--- response_body
hello, world

--- no_error_log
[error]
[alert]



=== TEST 4: echo without args
--- main_config
    stream {
        server {
            listen 54321;

            echo "hello";
            echo;
            echo 'world';
        }
    }

--- config
    location = /t {
        content_by_lua_block {
            local sock, err = ngx.socket.tcp()
            assert(sock, err)

            local ok, err = sock:connect("127.0.0.1", 54321)
            if not ok then
                ngx.say("connect error: ", err)
                return
            end

            local data, err = sock:receive("*a")
            if not data then
                ngx.say("receive error: ", err)
                return
            end

            ngx.print(data)
        }
    }
--- request
GET /t
--- response_body
hello

world

--- no_error_log
[error]
[alert]
