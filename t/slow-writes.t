# vim:set ft= ts=4 sw=4 et fdm=marker:

BEGIN {
    if (!defined $ENV{LD_PRELOAD}) {
        $ENV{LD_PRELOAD} = '';
    }

    if ($ENV{LD_PRELOAD} !~ /\bmockeagain\.so\b/) {
        $ENV{LD_PRELOAD} = "mockeagain.so $ENV{LD_PRELOAD}";
    }

    if ($ENV{MOCKEAGAIN} eq 'r') {
        $ENV{MOCKEAGAIN} = 'rw';

    } else {
        $ENV{MOCKEAGAIN} = 'w';
    }

    $ENV{TEST_NGINX_EVENT_TYPE} = 'poll';
    $ENV{MOCKEAGAIN_WRITE_TIMEOUT_PATTERN} = 'hello, world';
    $ENV{TEST_NGINX_POSTPONE_OUTPUT} = 1;
}

use t::TestStream;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4 + 5);

run_tests;

__DATA__

=== TEST 1: default echo_send_timeout is 60s
--- http_config
    lingering_close off;
--- stream_server_config
echo_lingering_close off;
echo ok;
--- stream_response
ok
--- grep_error_log eval: qr/event timer add: \d+: \d+:/
--- grep_error_log_out eval
qr/^(?:event timer add: \d+: 60000:\n)+$/s;
--- no_error_log
[error]



=== TEST 2: explicitly set echo_send_timeout to 60s
--- http_config
    lingering_close off;
--- stream_server_config
echo_lingering_close off;
echo_send_timeout 60s;
echo ok;
--- stream_response
ok
--- grep_error_log eval: qr/event timer add: \d+: \d+:/
--- grep_error_log_out eval
qr/^(?:event timer add: \d+: 60000:\n)+$/s;
--- no_error_log
[error]



=== TEST 3: explicitly set echo_send_timeout to 30s (server level)
--- stream_server_config
echo_send_timeout 30s;
echo ok;
--- stream_response
ok
--- error_log eval
qr/event timer add: \d+: 30000:/
--- no_error_log
[error]



=== TEST 4: explicitly set echo_send_timeout to 30s (http level)
--- stream_config
echo_send_timeout 30s;
--- stream_server_config
echo ok;
--- stream_response
ok
--- error_log eval
qr/event timer add: \d+: 30000:/
--- no_error_log
[error]



=== TEST 5: echo_send_timeout to 30s (stream {} level)
--- stream_config
echo_send_timeout 30s;
--- stream_server_config
echo ok;
--- stream_response
ok
--- error_log eval
qr/event timer add: \d+: 30000:/
--- no_error_log
[error]



=== TEST 6: echo_send_timeout to 30s (server {} override stream {} settings)
--- stream_config
echo_send_timeout 30s;

--- stream_server_config
echo_send_timeout 15s;
echo ok;

--- stream_response
ok
--- error_log eval
qr/event timer add: \d+: 15000:/
--- no_error_log eval
[
"[error]",
qr/event timer add: \d+: 30000:/,
]



=== TEST 7: echo_send_timeout fires with short timeouts
--- stream_server_config
echo_send_timeout 30ms;
echo hello, world;

--- error_log eval
[
qr/event timer add: \d+: 30:/,
qr/\[info\] .*? client send timed out/,
]
--- no_error_log
[error]



=== TEST 8: sleep 43ms and then 52ms (interleaved with "echo")
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
--- grep_error_log eval
qr/stream echo running sleep \(delay: \d+\)|stream echo writer handler|stream echo sleep event handler/
--- grep_error_log_out eval
qr/^stream echo running sleep \(delay: 43\)
(?:stream echo writer handler
)*stream echo sleep event handler
stream echo running sleep \(delay: 52\)
(?:stream echo writer handler
)+stream echo sleep event handler
(?:stream echo writer handler
)+$/s
--- no_error_log
[error]



=== TEST 9: sleep 43ms and then 52ms (interleaved with "echo"), always flush out everything before sleeping
--- stream_server_config
echo hi;
echo_flush_wait;
echo_sleep 0.043;
echo howdy;
echo_flush_wait;
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
--- grep_error_log eval
qr/stream echo running sleep \(delay: \d+\)|stream echo writer handler|stream echo sleep event handler/
--- grep_error_log_out eval
qr/^(?:stream echo writer handler
)+stream echo running sleep \(delay: 43\)
stream echo sleep event handler
(?:stream echo writer handler
)+stream echo running sleep \(delay: 52\)
stream echo sleep event handler
(?:stream echo writer handler
)+$/s
--- no_error_log
[error]
