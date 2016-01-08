# vi:set ft= ts=4 et:

use Test::Nginx::Socket::Lua::Stream;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4 + 3);

run_tests;

__DATA__

=== TEST 1: read 3 bytes
--- stream_server_config
    echo_read_bytes 3;
    echo_request_data;

--- stream_request chop
hel
--- stream_response chop
hel

--- no_error_log
[error]
[alert]



=== TEST 2: read 3 bytes (buffer size == 3, twice)
--- stream_server_config
    echo_read_buffer_size 3;

    echo_read_bytes 3;
    echo_request_data;
    echo;
    echo_read_bytes 3;
    echo_request_data;

--- stream_request chop
hello!
--- stream_response chop
hel
lo!

--- no_error_log
[error]
[alert]



=== TEST 3: read 3 bytes (buffer size == 4, twice)
--- stream_server_config
    echo_read_buffer_size 4;

    echo_read_bytes 3;
    echo_request_data;
    echo_flush_wait;
    echo;
    echo_read_bytes 3;
    echo_request_data;
    echo_flush_wait;

--- stream_request chop
hello!
--- stream_response chop
hel
lo!

--- no_error_log
[error]
[alert]



=== TEST 4: read 0 bytes
--- stream_server_config
    echo_read_bytes 0;
    echo_request_data;

--- stream_request
--- stream_response

--- no_error_log
[error]
[alert]



=== TEST 5: echo request data without reading any request data
--- stream_server_config
    echo_request_data;

--- stream_request
--- stream_response

--- no_error_log
[error]
[alert]



=== TEST 6: the -- option
--- stream_server_config
    echo_read_bytes --;
    echo_request_data;

--- stream_request
--- stream_response
--- error_log eval
qr/\[emerg\] .*?stream echo requires one value argument in "echo_read_bytes" but got 0\b/
--- no_error_log
[error]
[alert]
--- must_die



=== TEST 7: read timeout (error)
--- stream_server_config
    echo_client_error_log_level error;
    echo_read_timeout 137ms;
    echo_read_bytes 1k;
    echo_request_data;

--- stream_request
--- stream_response

--- error_log eval
[
qr/event timer add: \d+: 137:/,
qr/\[error\] .*? stream client read timed out/,
]
--- no_error_log
[alert]



=== TEST 8: read timeout (info by default)
--- stream_server_config
    echo_read_timeout 137ms;
    echo_read_bytes 2;
    echo_request_data;

--- stream_request
--- stream_response

--- error_log eval
[
qr/event timer add: \d+: 137:/,
qr/\[info\] .*? stream client read timed out/,
]
--- no_error_log
[error]
[alert]



=== TEST 9: unknown option
--- stream_server_config
    echo_read_bytes -t;
    echo_request_data;

--- stream_request chop
ab
--- stream_response chop

--- error_log eval
qr/\[emerg\] .*?stream echo sees unknown option "-t" in "echo_read_bytes"/
--- no_error_log
[error]
[alert]
--- must_die
