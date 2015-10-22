# vi:set ft= ts=4 et:

use t::TestStream;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4);

no_long_string;
run_tests;

__DATA__

=== TEST 1: discard request before simple single echo (no request)
--- stream_server_config
echo_discard_request;
echo "Hello, stream echo!";

--- stream_response
Hello, stream echo!

--- no_error_log
[error]
[alert]



=== TEST 2: discard request before simple single echo (with request)
--- stream_server_config
echo_discard_request;
echo "Hello, stream echo!";

--- stream_request
hello, world!
--- stream_response
Hello, stream echo!

--- no_error_log
[error]
[alert]



=== TEST 3: read bytes then discard
should fail in mockeagain "r" mode.

--- stream_server_config
#echo_lingering_time 100ms;
echo_read_bytes 2;
echo_request_data;
echo;
echo_discard_request;
echo "Hello, stream echo!";

--- stream_request
Hey, server!
--- stream_response
He
Hello, stream echo!

--- no_error_log
[error]
[alert]



=== TEST 4: discard then read bytes
should fail in mockeagain "r" mode.

--- stream_server_config
#echo_lingering_time 100ms;
echo_discard_request;
echo_read_bytes 2;
echo_request_data;
echo;
echo "Hello, stream echo!";

--- stream_request
Hey, server!

--- stream_response eval
qr/^(?:send stream request error: broken pipe)?$/s;

--- error_log eval
qr/\[crit\] .*?stream echo: echo_read_bytes not allowed after echo_discard_request/
--- no_error_log
[alert]



=== TEST 5: read line then discard request
should fail in mockeagain "r" mode.

--- stream_server_config
#echo_lingering_time 100ms;
echo_read_line;
echo_request_data;
echo_discard_request;
echo "Hello, stream echo!";
echo_request_data;

--- stream_request
Hey, server!
Hi, dear!
--- stream_response
Hey, server!
Hello, stream echo!

--- no_error_log
[error]
[alert]



=== TEST 6: discard then read line
should fail in mockeagain "r" mode.

--- stream_server_config
#echo_lingering_time 100ms;
echo_discard_request;
echo_read_line;
echo_request_data;
echo "Hello, stream echo!";

--- stream_request
Hey, server!
Halo

--- stream_response eval
qr/^(?:send stream request error: broken pipe)?$/s;

--- error_log eval
qr/\[crit\] .*?stream echo: echo_read_line not allowed after echo_discard_request/
--- no_error_log
[alert]
