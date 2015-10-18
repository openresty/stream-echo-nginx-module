# vi:set ft= ts=4 et:

use t::TestStream;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4);

run_tests;

__DATA__

=== TEST 1: simple single echo_duplicate (n=3)
--- stream_server_config
echo_duplicate 3 hello;

--- stream_response chop
hellohellohello

--- no_error_log
[error]
[alert]



=== TEST 2: simple single echo_duplicate (n=1)
--- stream_server_config
echo_duplicate 1 hello;

--- stream_response chop
hello

--- no_error_log
[error]
[alert]



=== TEST 3: simple single echo_duplicate (n=0)
--- stream_server_config
echo_duplicate 0 hello;

--- stream_response

--- no_error_log
[error]
[alert]



=== TEST 4: multiple echo_duplicate's
--- stream_server_config
echo_duplicate 10 a;
echo_duplicate 5 b;
echo_duplicate 3 abc;

--- stream_response chop
aaaaaaaaaabbbbbabcabcabc

--- no_error_log
[error]
[alert]



=== TEST 5: multiple echo_duplicate's (intermixed with echo)
--- stream_server_config
echo_duplicate 10 a;
echo;
echo_duplicate 5 b;
echo;
echo_duplicate 3 abc;
echo;

--- stream_response
aaaaaaaaaa
bbbbb
abcabcabc

--- no_error_log
[error]
[alert]



=== TEST 6: simple single echo_duplicate (n=-1)
--- stream_server_config
echo_duplicate -1 hello;

--- stream_response
--- error_log eval
qr/\[emerg\] .*?stream echo sees unknown option \"-1\" in "echo_duplicate"/
--- no_error_log
[error]
[alert]
--- must_die



=== TEST 7: -- option
--- stream_server_config
echo_duplicate -- 2 hello;

--- stream_response chop
hellohello
--- no_error_log
[error]
[alert]



=== TEST 8: too few args
--- stream_server_config
echo_duplicate -- 2;

--- stream_response chop
hellohello
--- error_log eval
qr/\[emerg\] .*?stream echo requires two value arguments in "echo_duplicate" but got 1\b/
--- no_error_log
[error]
[alert]
--- must_die



=== TEST 9: too many args
--- stream_server_config
echo_duplicate 2 a bb;

--- stream_response chop
hellohello
--- error_log eval
qr/\[emerg\] .*?stream echo requires two value arguments in "echo_duplicate" but got 3\b/
--- no_error_log
[error]
[alert]
--- must_die



=== TEST 10: underscores
--- stream_server_config
echo_duplicate 2_000 a;

--- stream_response eval
"a" x 2_000
--- no_error_log
[error]
[alert]



=== TEST 11: repeat an empty string
--- stream_server_config
echo_duplicate 3 "";

--- stream_response

--- no_error_log
[error]
[alert]



=== TEST 12: bad n argument
--- stream_server_config
echo_duplicate bc a;

--- stream_response

--- error_log eval
qr/\[emerg\] .*? stream echo: bad "n" argument, "bc", in "echo_duplicate"/
--- no_error_log
[error]
[alert]
--- must_die
