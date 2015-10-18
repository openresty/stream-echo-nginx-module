NAME
====

ngx_stream_echo - TCP/stream echo module for NGINX (a port of the ngx_http_echo module)

Table of Contents
=================

* [NAME](#name)
* [Version](#version)
* [Synopsis](#synopsis)
* [Description](#description)
* [Directives](#directives)
    * [echo](#echo)
    * [echo_duplicate](#echo_duplicate)
    * [echo_send_timeout](#echo_send_timeout)
* [Caveats](#caveats)
* [Installation](#installation)
* [Compatibility](#compatibility)
* [Community](#community)
    * [English Mailing List](#english-mailing-list)
    * [Chinese Mailing List](#chinese-mailing-list)
* [Report Bugs](#report-bugs)
* [Source Repository](#source-repository)
* [Author](#author)
* [Copyright & License](#copyright--license)
* [See Also](#see-also)

Version
=======

This module is still under early development.

Synopsis
========

```nginx
# nginx.conf

stream {
    server {
        listen 1234;

        echo_send_timeout   10s;    # default to 60s

        echo "Hello, world!";
        echo I really like doing downstream TCP;
    }
}
```

```console
# on the terminal

$ telnet 127.0.0.1 1234
Trying 127.0.0.1...
Connected to 127.0.0.1.
Escape character is '^]'.
Hello, world!
I really like doing downstream TCP
Connection closed by foreign host.
```

Description
===========

This module is a port of the handy [ngx_http_echo](https://github.com/openresty/echo-nginx-module)
module over the shiny new "stream" subsystem of NGINX. With this module,
you can do simple custom output from constant strings directly from memory in your
generic TCP (or stream-typed unix domain socket) server.

This module is particularly handy for mocking silly TCP endpoints during unit testing (like
mocking a buggy and evil memcached server).

Also, this module can serve as a useful simple demo for writing NGINX stream-typed 3rd-party modules.
Well, it is just a little bit more complex than a "hello world" module anyway.

[Back to TOC](#table-of-contents)

Directives
==========

[Back to TOC](#table-of-contents)

echo
----
**syntax:** *echo \[options\] &lt;string&gt;...*

**default:** *no*

**context:** *server*

**phase:** *content*

Sends string arguments joined by spaces, along with a trailing newline, out to the client.

For example,

```nginx
stream {
    server {
        listen 1234;

        echo "Hello, world!";
        echo foo bar baz;
    }
}
```

Then connecting to the server port 1234 will immediately receive the response data

```
Hello, world!
foo bar baz
```

and then the server closes the connection right away.

When no argument is specified, *echo* emits the trailing newline alone, just like the *echo* command in shell.

one can suppress the trailing newline character in the output by using the `-n` option, as in

```nginx
echo -n "hello, ";
echo "world";
```

Connecting to the server will receive the response data

```
hello, world
```

where the first `echo` command generates no trailing new-line due to the use of the `-n` option.

To output string values prefixed with a dash (`-`), you can specify the special `--` option
to disambiguate such arguments from options. For instance,

```nginx
echo -n -- -32+5;
```

The response is

```
-32+5
```

This command sends the data *asynchronously* to the main execution flow, that is, this command
will return immediately without waiting for the output to be actually flushed into the
system socket send buffers.

For slow connections the sending timeout protection is subject to the configuration of
the [echo_send_timeout](#echo_send_timeout) configuration directive.

This command can be mixed with other `echo_*` commands (like [echo_duplicate](#echo_duplicate))
freely in the same server. The module
handler will run them sequentially in the same order of their appearance in the NGINX configuration file.

[Back to TOC](#table-of-contents)

echo_duplicate
--------------
**syntax:** *echo_duplicate &lt;count&gt; &lt;string&gt;*

**default:** *no*

**context:** *server*

**phase:** *content*

Outputs duplication of a string indicated by the second argument, using the count specified in the first argument.

For instance,

```nginx
echo_duplicate 3 "abc";
```

will lead to the output of `"abcabcabc"`.

Underscores are allowed in the count number, just like in Perl. For example, to emit 1000,000,000 instances of `"hello, world"`:

```nginx
echo_duplicate 1000_000_000 "hello, world";
```

The `count` argument could be zero, but not negative. The second `string` argument could be an empty string ("") likewise.

Unlike the [echo](#echo) directive, no trailing newline is appended to the result.

Like the [echo](#echo) command, this command sends the data *asynchronously* to the main
execution flow, that is, this command
will return immediately without waiting for the output to be actually flushed into the
system socket send buffers.

For slow connections the sending timeout protection is subject to the configuration of
the [echo_send_timeout](#echo_send_timeout) configuration directive.

This command can be mixed with other `echo*` commands (like [echo](#echo))
freely in the same server. The module
handler will run them sequentially in the same order of their appearance in the NGINX configuration file.

[Back to TOC](#table-of-contents)

echo_send_timeout
-----------------
**syntax:** *echo_send_timeout &lt;time&gt;*

**default:** *echo_send_timeout 60s*

**context:** *stream, server*

Sets the sending timeout for the downstream socket, in seconds by default.

It is wise to always explicitly specify the time unit to avoid confusion. Time units supported are "s"(seconds), "ms"(milliseconds), "y"(years), "M"(months), "w"(weeks), "d"(days), "h"(hours), and "m"(minutes).

This time must be less than 597 hours.

If this directive is not specified, this module will use `60s` as the default.

[Back to TOC](#table-of-contents)

Caveats
=======

* Unlike the [ngx_http_echo module](https://github.com/openresty/echo-nginx-module), this module has no NGINX variable
support since NGINX variables are not supported in the "stream" subsystem of NGINX (yet).

[Back to TOC](#table-of-contents)

Installation
============

Grab the nginx source code from [nginx.org](http://nginx.org/), for example,
the version 1.9.3 (see [nginx compatibility](#compatibility)), and then build the source with this module:

```bash
wget 'http://nginx.org/download/nginx-1.9.3.tar.gz'
tar -xzvf nginx-1.9.3.tar.gz
cd nginx-1.9.3/

# Here we assume you would install you nginx under /opt/nginx/.
./configure --prefix=/opt/nginx \
    --with-stream \
    --add-module=/path/to/stream-echo-nginx-module

make -j2
sudo make install
```

[Back to TOC](#table-of-contents)

Compatibility
=============

The following versions of Nginx should work with this module:

* **1.9.x**                       (last tested: 1.9.3)

NGINX versions older than 1.9.0 will *not* work due to the lack of the "stream" subsystem.

[Back to TOC](#table-of-contents)

Community
=========

[Back to TOC](#table-of-contents)

English Mailing List
--------------------

The [openresty-en](https://groups.google.com/group/openresty-en) mailing list is for English speakers.

[Back to TOC](#table-of-contents)

Chinese Mailing List
--------------------

The [openresty](https://groups.google.com/group/openresty) mailing list is for Chinese speakers.

[Back to TOC](#table-of-contents)

Report Bugs
===========

Although a lot of effort has been put into testing and code tuning, there must be some serious bugs lurking somewhere in this module. So whenever you are bitten by any quirks, please don't hesitate to

1. create a ticket on the [issue tracking interface](https://github.com/agentzh/stream-echo-nginx-module/issues) provided by GitHub,
1. or send a bug report, questions, or even patches to the [OpenResty Community](#community).

[Back to TOC](#table-of-contents)

Source Repository
=================

Available on github at [agentzh/stream-echo-nginx-module](https://github.com/agentzh/stream-echo-nginx-module).

[Back to TOC](#table-of-contents)

Author
======

Yichun "agentzh" Zhang (章亦春) *&lt;agentzh@gmail.com&gt;*, CloudFlare Inc.

This wiki page is also maintained by the author himself, and everybody is encouraged to improve this page as well.

[Back to TOC](#table-of-contents)

Copyright & License
===================

Copyright (c) 2015, Yichun "agentzh" Zhang (章亦春) <agentzh@gmail.com>, CloudFlare Inc.

This module is licensed under the terms of the BSD license.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

[Back to TOC](#table-of-contents)

See Also
========

* [ngx_http_echo_module](https://github.com/openresty/echo-nginx-module/#readme)
* NGINX's [stream subsystem](http://nginx.org/en/docs/stream/ngx_stream_core_module.html)
* [OpenResty](https://openresty.org)

[Back to TOC](#table-of-contents)

