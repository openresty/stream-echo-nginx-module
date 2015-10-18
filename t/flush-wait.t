# vi:set ft= ts=4 et:

use t::TestStream;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4);

run_tests;

__DATA__

=== TEST 1: flush_wait
--- stream_server_config
echo hello;
echo_flush_wait;
echo world;

--- stream_response
hello
world
--- no_error_log
[error]
--- error_log
stream echo running flush-wait (busy:



=== TEST 2: too many args
--- stream_server_config
echo_flush_wait 2;

--- error_log eval
qr/\[emerg\] .*?stream echo takes no value arguments in "echo_flush_wait" but got 1\b/
--- no_error_log
[error]
[alert]
--- must_die



=== TEST 3: --
--- stream_server_config
echo_flush_wait --;
echo ok;

--- stream_response
ok
--- error_log eval
--- no_error_log
[error]
[alert]
