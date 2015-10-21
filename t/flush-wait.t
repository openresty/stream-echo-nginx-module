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
qr/\[emerg\] .*?invalid number of arguments in "echo_flush_wait" directive/
--- no_error_log
[error]
[alert]
--- must_die
