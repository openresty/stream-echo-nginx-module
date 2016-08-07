# vi:set ft= ts=4 et:

use Test::Nginx::Socket::Lua::Dgram;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4);

run_tests;

__DATA__

=== TEST 1: simple single echo
--- dgram_server_config
echo "Hello, stream echo!";

--- dgram_response
Hello, stream echo!

--- no_error_log
[error]
[alert]



=== TEST 2: multiple echos
--- dgram_server_config
echo Hi Kindy;
echo How is "going?";

--- dgram_response
Hi Kindy
How is going?

--- no_error_log
[error]
[alert]
# pending multi response support in test framework
--- SKIP



=== TEST 3: echo -n
--- dgram_server_config
    echo -n "hello, ";
    echo 'world';

--- dgram_response
hello, world

--- no_error_log
[error]
[alert]
# pending multi response support in test framework
--- SKIP


=== TEST 4: echo without args
--- dgram_server_config
    echo "hello";
    echo;
    echo 'world';

--- dgram_response
hello

world

--- no_error_log
[error]
[alert]
# pending multi response support in test framework
--- SKIP



=== TEST 5: echo --
--- dgram_server_config
    echo -- -n -t -- hi;
--- dgram_response
-n -t -- hi
--- no_error_log
[error]
[alert]



=== TEST 6: echo -n --
--- dgram_server_config
    echo -n -- -n -t -- hi;
--- dgram_response chop
-n -t -- hi
--- no_error_log
[error]
[alert]



=== TEST 7: echo unknown options (after a valid option)
--- dgram_server_config
    echo -n -t ok;

--- dgram_response
--- error_log eval
qr/\[emerg\] .*?stream echo sees unknown option \"-t\" in "echo"/
--- no_error_log
[error]
[alert]
--- must_die



=== TEST 8: echo -n and no other args
--- dgram_server_config
    echo -n;
    echo 'world';

--- dgram_response
world

--- no_error_log
[error]
[alert]



=== TEST 9: using echo in stream {}
--- dgram_config
    echo hi;

--- dgram_response
world

--- no_error_log
[error]
[alert]
--- error_log eval
qr/\[emerg\] .*? "echo" directive is not allowed here/
--- must_die



=== TEST 10: empty string args
--- dgram_server_config
echo "" "" "" a;


--- dgram_response
   a

--- no_error_log
[error]
[alert]
