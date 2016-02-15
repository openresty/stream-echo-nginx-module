# vi:set ft= ts=4 et:

use Test::Nginx::Socket::Lua::Stream;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4 + 4);

run_tests;

__DATA__

=== TEST 1: read 3 bytes while received more (lingering_close is on by default)
--- stream_server_config
    echo_read_bytes 3;
    echo_request_data;
    echo_read_buffer_size 4;

--- stream_request
hello, world!
--- stream_response chop
hel

--- no_error_log
[error]
[alert]



=== TEST 2: read 3 bytes while received more (lingering_close explicitly on)
--- stream_server_config
    echo_lingering_close on;
    echo_read_bytes 3;
    echo_request_data;
    echo_read_buffer_size 4;

--- stream_request
hello, world!
--- stream_response chop
hel

--- no_error_log
[error]
[alert]



=== TEST 3: read 3 bytes while received more (lingering_close off)
--- stream_server_config
    echo_lingering_close off;
    echo_read_bytes 3;
    echo_request_data;
    echo_read_buffer_size 4;

--- stream_request
hello, world!
--- stream_response eval
qr/(?:receive|send) stream (?:response|request) error: connection reset by peer/

--- no_error_log
[alert]
--- error_log eval
qr/\[error\] .*? (?:send|recv)\(\) failed \(\d+: Connection reset by peer\)/



=== TEST 4: lingering_timeout
--- stream_server_config
    echo_lingering_timeout 321ms;

    echo_read_bytes 3;
    echo_request_data;
    echo_read_buffer_size 4;

--- stream_request
hello, world!
--- stream_response chop
hel

--- error_log eval
qr/event timer add: \d+: 321:/

--- no_error_log
[error]
[alert]



=== TEST 5: lingering_time
--- stream_server_config
    echo_lingering_time 1s;

    echo_read_bytes 3;
    echo_request_data;
    echo_read_buffer_size 4;

--- stream_request
hello, world!
--- stream_response chop
hel

--- error_log eval
qr/event timer add: \d+: 1000:/

--- no_error_log
[error]
[alert]
--- wait: 0.2



=== TEST 6: read 3 bytes while received more (lingering_close is on)
--- stream_server_config
    echo_lingering_timeout 321ms;
    echo_read_bytes 3;
    echo_request_data;
    echo_read_buffer_size 4;

--- stream_request chop
hel
--- stream_response chop
hel

--- wait: 0.1
--- no_error_log eval
[
qr/event timer add: \d+: 321:/,
'[error]',
'[alert]',
'stream echo lingering close handler',
]



=== TEST 7: read 3 bytes while received more (lingering_close is always)
--- stream_server_config
    echo_lingering_close always;
    echo_read_bytes 3;
    echo_request_data;
    echo_read_buffer_size 4;

--- stream_request
hello, world!
--- stream_response chop
hel

--- no_error_log
[error]
[alert]
