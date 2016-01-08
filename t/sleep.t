# vi:set ft= ts=4 et:

use Test::Nginx::Socket::Lua::Stream;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4 + 2);

run_tests;

__DATA__

=== TEST 1: sleep 43ms
--- stream_server_config
echo_sleep 0.043;

--- stream_response
--- error_log eval
qr/event timer add: \d+: 43:/
--- no_error_log
[error]



=== TEST 2: sleep 43ms and then 52ms
--- stream_server_config
echo_sleep 0.043;
echo_sleep 0.052;

--- stream_response
--- error_log eval
[
qr/event timer add: \d+: 43:/,
qr/event timer add: \d+: 52:/,
]
--- no_error_log
[error]



=== TEST 3: sleep 43ms and then 52ms (interleaved with "echo")
--- stream_server_config
echo hi;
echo_sleep 0.043;
echo howdy;
echo_sleep 0.052;
echo hello;

--- stream_response
hi
howdy
hello
--- error_log eval
[
qr/event timer add: \d+: 43:/,
qr/event timer add: \d+: 52:/,
]
--- no_error_log
[error]



=== TEST 4: too many args
--- stream_server_config
echo_sleep 2 a;

--- stream_response chop
hellohello
--- error_log eval
qr/\[emerg\] .*?stream echo requires one value argument in "echo_sleep" but got 2\b/
--- no_error_log
[error]
[alert]
--- must_die



=== TEST 5: delay is -1
--- stream_server_config
echo_sleep -1;

--- stream_response
--- error_log eval
qr/\[emerg\] .*?stream echo sees unknown option \"-1\" in "echo_sleep"/
--- no_error_log
[error]
[alert]
--- must_die



=== TEST 6: bad delay value
--- stream_server_config
echo_sleep a;

--- stream_response
--- error_log eval
qr/\[emerg\] .*? stream echo: bad "delay" argument, "a", in "echo_sleep"/
--- no_error_log
[error]
[alert]
--- must_die
