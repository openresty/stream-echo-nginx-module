# vi:set ft= ts=4 et:

use t::TestStream;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4);

run_tests;

__DATA__

=== TEST 1: simple single echo
--- stream_server_config
echo "Hello, stream echo!";

--- stream_response
Hello, stream echo!

--- no_error_log
[error]
[alert]



=== TEST 2: multiple echos
--- stream_server_config
echo Hi Kindy;
echo How is "going?";

--- stream_response
Hi Kindy
How is going?

--- no_error_log
[error]
[alert]



=== TEST 3: echo -n
--- stream_server_config
    echo -n "hello, ";
    echo 'world';

--- stream_response
hello, world

--- no_error_log
[error]
[alert]



=== TEST 4: echo without args
--- stream_server_config
    echo "hello";
    echo;
    echo 'world';

--- stream_response
hello

world

--- no_error_log
[error]
[alert]



=== TEST 5: echo --
--- stream_server_config
    echo -- -n -t -- hi;
--- stream_response
-n -t -- hi
--- no_error_log
[error]
[alert]



=== TEST 6: echo -n --
--- stream_server_config
    echo -n -- -n -t -- hi;
--- stream_response chop
-n -t -- hi
--- no_error_log
[error]
[alert]



=== TEST 7: echo unknown options (after a valid option)
--- stream_server_config
    echo -n -t ok;
--- stream_response
--- error_log eval
qr/\[error\] .*?stream echo sees unrecognized option \"-t\"/
--- no_error_log
[alert]



=== TEST 8: echo -n and no other args
--- stream_server_config
    echo -n;
    echo 'world';

--- stream_response
world

--- no_error_log
[error]
[alert]



=== TEST 9: using echo in stream {}
--- stream_config
    echo hi;

--- stream_response
world

--- no_error_log
[error]
[alert]
--- error_log eval
qr/\[emerg\] .*? "echo" directive is not allowed here/
--- must_die
