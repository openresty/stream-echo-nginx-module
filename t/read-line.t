# vi:set ft= ts=4 et:

use t::TestStream;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4 + 1);

no_long_string;
run_tests;

__DATA__

=== TEST 1: read a line
--- stream_server_config
    echo_read_line;
    echo_request_data;

--- stream_request
hello, world!
--- stream_response
hello, world!

--- no_error_log
[error]
[alert]



=== TEST 2: read a line, mixed with echo
--- stream_server_config
    echo_read_line;
    echo -n "I got: ";
    echo_request_data;

--- stream_request
hello, world!
--- stream_response
I got: hello, world!

--- no_error_log
[error]
[alert]



=== TEST 3: read multiple lines (read a line, echo a line)
--- stream_server_config
    echo_read_line;
    echo -n "I got 1st: ";
    echo_request_data;
    echo_read_line;
    echo -n "I got 2nd: ";
    echo_request_data;

--- stream_request
hello, world!
howdy, lua!
--- stream_response
I got 1st: hello, world!
I got 2nd: howdy, lua!

--- no_error_log
[error]
[alert]



=== TEST 4: read multiple lines (read two lines, echo two lines)
--- stream_server_config
    echo_read_line;
    echo_read_line;
    echo -n "I got: ";
    echo_request_data;

--- stream_request
hello, world!
howdy, lua!
--- stream_response
I got: hello, world!
howdy, lua!

--- no_error_log
[error]
[alert]



=== TEST 5: interleaving read-bytes and read-line
--- stream_server_config
    echo_read_line;
    echo_read_bytes 3;
    echo -n "I got: ";
    echo_request_data;

--- stream_request chop
hello, world!
abc
--- stream_response chop
I got: hello, world!
abc

--- no_error_log
[error]
[alert]



=== TEST 6: line is too long
--- stream_server_config
    echo_read_line;
    echo_request_data;
    echo_read_buffer_size 5;

--- stream_request chop
hello, world!
--- stream_response eval
qr/(?:receive|send) stream (?:response|request) error: connection reset by peer/

--- error_log eval
[
qr/\[error\] .*? (?:send|recv)\(\) failed \(\d+: Connection reset by peer\)/,
qr/\[error\] .*? stream echo: echo_buffer_size is too small for the request/,
]
--- no_error_log
[alert]
