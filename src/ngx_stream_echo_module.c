
/*
 * Copyright (C) Yichun Zhang (agentzh)
 */


#ifndef DDEBUG
#define DDEBUG 0
#endif
#include "ddebug.h"


#include <ngx_config.h>
#include <ngx_core.h>
#include <nginx.h>
#include <ngx_stream.h>


typedef enum {
    NGX_STREAM_ECHO_OPCODE_ECHO,
#if 0
    NGX_STREAM_ECHO_OPCODE_ECHO_SLEEP,         /* TODO */
    NGX_STREAM_ECHO_OPCODE_ECHO_FLUSH,         /* TODO */
    NGX_STREAM_ECHO_OPCODE_ECHO_DUPLICATE,     /* TODO */
    NGX_STREAM_ECHO_OPCODE_ECHO_READ_REQUEST,  /* TODO */
#endif
} ngx_stream_echo_opcode_t;


typedef struct {
    ngx_array_t                   raw_args;  /* of elements of type ngx_str_t */
    ngx_stream_echo_opcode_t      opcode;
} ngx_stream_echo_cmd_t;


typedef struct {
    ngx_array_t      cmds;  /* of elements of type ngx_stream_echo_cmd_t */
    ngx_msec_t       send_timeout;
#if 0
    ngx_msec_t       read_timeout;  /* unused */
#endif
} ngx_stream_echo_srv_conf_t;


typedef struct {
    ngx_uint_t                       cmd_index;

    ngx_chain_t                     *busy;
    ngx_chain_t                     *free;

    ngx_chain_writer_ctx_t           writer;

#if 0
    ngx_event_t      sleep;
#endif

    unsigned                         done;  /* :1 */
} ngx_stream_echo_ctx_t;


static void ngx_stream_echo_handler(ngx_stream_session_t *s);
static ngx_int_t ngx_stream_echo_run_cmds(ngx_stream_session_t *s);
static ngx_int_t ngx_stream_echo_eval_args(ngx_stream_session_t *s,
    ngx_stream_echo_cmd_t *cmd, ngx_array_t *args, ngx_array_t *opts);
static ngx_int_t ngx_stream_echo_exec_echo(ngx_stream_session_t *s,
    ngx_stream_echo_ctx_t *ctx, ngx_array_t *args, ngx_array_t *opts);
static ngx_int_t ngx_stream_echo_send_last_buf(ngx_stream_session_t *s);
static void ngx_stream_echo_writer(ngx_event_t *ev);
static void ngx_stream_echo_block_reading(ngx_event_t *ev);
static void ngx_stream_echo_finalize_session(ngx_stream_session_t *s,
    ngx_int_t rc);
static ngx_stream_echo_ctx_t *
    ngx_stream_echo_create_ctx(ngx_stream_session_t *s);
static char *ngx_stream_echo_echo(ngx_conf_t *cf, ngx_command_t *cmd,
    void *conf);
static char *ngx_stream_echo_helper(ngx_conf_t *cf, ngx_command_t *cmd,
    void *conf, ngx_stream_echo_opcode_t opcode);
static void *ngx_stream_echo_create_srv_conf(ngx_conf_t *cf);
static char *ngx_stream_echo_merge_srv_conf(ngx_conf_t *cf,
    void *parent, void *child);


static ngx_command_t  ngx_stream_echo_commands[] = {

    { ngx_string("echo"),
      NGX_STREAM_SRV_CONF|NGX_CONF_ANY,
      ngx_stream_echo_echo,
      NGX_STREAM_SRV_CONF_OFFSET,
      0,
      NULL },

    { ngx_string("echo_send_timeout"),
      NGX_STREAM_MAIN_CONF|NGX_STREAM_SRV_CONF|NGX_CONF_TAKE1,
      ngx_conf_set_msec_slot,
      NGX_STREAM_SRV_CONF_OFFSET,
      offsetof(ngx_stream_echo_srv_conf_t, send_timeout),
      NULL },

      ngx_null_command
};


static ngx_stream_module_t  ngx_stream_echo_module_ctx = {
    NULL,                                  /* postconfiguration */

    NULL,                                  /* create main configuration */
    NULL,                                  /* init main configuration */

    ngx_stream_echo_create_srv_conf,       /* create server configuration */
    ngx_stream_echo_merge_srv_conf         /* merge server configuration */
};


ngx_module_t  ngx_stream_echo_module = {
    NGX_MODULE_V1,
    &ngx_stream_echo_module_ctx,           /* module context */
    ngx_stream_echo_commands,              /* module directives */
    NGX_STREAM_MODULE,                     /* module type */
    NULL,                                  /* init master */
    NULL,                                  /* init module */
    NULL,                                  /* init process */
    NULL,                                  /* init thread */
    NULL,                                  /* exit thread */
    NULL,                                  /* exit process */
    NULL,                                  /* exit master */
    NGX_MODULE_V1_PADDING
};


static void
ngx_stream_echo_handler(ngx_stream_session_t *s)
{
    ngx_int_t                    rc;
    ngx_connection_t            *c;
    ngx_stream_echo_ctx_t       *ctx;
    ngx_stream_echo_srv_conf_t  *escf;

    escf = ngx_stream_get_module_srv_conf(s, ngx_stream_echo_module);
    if (escf->cmds.nelts == 0) {
        ngx_stream_echo_finalize_session(s, NGX_DECLINED);
        return;
    }

    c = s->connection;

    c->write->handler = ngx_stream_echo_writer;
    c->read->handler = ngx_stream_echo_block_reading;

    ctx = ngx_stream_echo_create_ctx(s);
    if (ctx == NULL) {
        ngx_stream_echo_finalize_session(s, NGX_ERROR);
        return;
    }

    ngx_stream_set_ctx(s, ctx, ngx_stream_echo_module);

    rc = ngx_stream_echo_run_cmds(s);

    dd("run cmds returned %d", (int) rc);

    if (rc == NGX_OK) {
        /* all commands have been run */
        rc = ngx_stream_echo_send_last_buf(s);
    }

    ngx_stream_echo_finalize_session(s, rc);
}


static ngx_int_t
ngx_stream_echo_run_cmds(ngx_stream_session_t *s)
{
    ngx_int_t                        rc;
    ngx_uint_t                       n;
    ngx_array_t                      opts;
    ngx_array_t                      args;
    ngx_connection_t                *c;
    ngx_stream_echo_cmd_t           *cmd;
    ngx_stream_echo_ctx_t           *ctx;
    ngx_stream_echo_srv_conf_t      *escf;

    escf = ngx_stream_get_module_srv_conf(s, ngx_stream_echo_module);

    c = s->connection;

    ngx_log_debug0(NGX_LOG_DEBUG_STREAM, c->log, 0,
                   "echo run commands");

    c->log->action = "running stream echo commands";

    ctx = ngx_stream_get_module_ctx(s, ngx_stream_echo_module);
    if (ctx == NULL) {
        return NGX_ERROR;
    }

    if (ngx_array_init(&args, c->pool, 1, sizeof(ngx_str_t))
        == NGX_ERROR)
    {
        return NGX_ERROR;
    }

    if (ngx_array_init(&opts, c->pool, 1, sizeof(ngx_str_t))
        == NGX_ERROR)
    {
        return NGX_ERROR;
    }

    cmd = escf->cmds.elts;

    for (; ctx->cmd_index < escf->cmds.nelts; ctx->cmd_index++) {

        dd("cmd indx: %d", (int) ctx->cmd_index);

        n = cmd[ctx->cmd_index].raw_args.nelts;

        dd("n = %d", (int) n);

        /* reset the local arrays */
        args.nelts = 0;
        opts.nelts = 0;

        if (n > 0) {
            rc = ngx_stream_echo_eval_args(s, &cmd[ctx->cmd_index], &args,
                                           &opts);

            if (rc == NGX_ERROR) {
                ngx_log_error(NGX_LOG_ERR, c->log, 0,
                              "stream echo failed to evaluate arguments for "
                              "the directive.");
                return NGX_ERROR;
            }
        }

        switch (cmd->opcode) {
        case NGX_STREAM_ECHO_OPCODE_ECHO:
            rc = ngx_stream_echo_exec_echo(s, ctx, &args, &opts);
            break;

        default:
            ngx_log_error(NGX_LOG_ERR, c->log, 0,
                          "stream echo unknown opcode: %d",
                          cmd[ctx->cmd_index].opcode);

            return NGX_ERROR;
        }

        if (rc == NGX_ERROR) {
            return NGX_ERROR;
        }
    }

    ctx->done = 1;

    return NGX_OK;
}


static ngx_int_t
ngx_stream_echo_eval_args(ngx_stream_session_t *s,
    ngx_stream_echo_cmd_t *cmd, ngx_array_t *args, ngx_array_t *opts)
{
    unsigned                         expecting_opts = 1;
    ngx_str_t                       *arg, *raw, *opt;
    ngx_str_t                       *value;
    ngx_uint_t                       i;
    ngx_array_t                     *raw_args = &cmd->raw_args;

    dd("checking cmd %p", cmd);

    value = raw_args->elts;

    for (i = 0; i < raw_args->nelts; i++) {
        raw = &value[i];

        dd("checking raw arg: \"%.*s\"", (int) raw->len, raw->data);

        if (raw->len > 0) {
            if (expecting_opts) {
                if (raw->len == 1 || raw->data[0] != '-') {
                    expecting_opts = 0;

                } else if (raw->data[1] == '-') {
                    expecting_opts = 0;
                    continue;

                } else {
                    opt = ngx_array_push(opts);
                    if (opt == NULL) {
                        return NGX_ERROR;
                    }

                    opt->len = raw->len - 1;
                    opt->data = raw->data + 1;

                    dd("pushing opt: %.*s", (int) opt->len, opt->data);

                    continue;
                }
            }

        } else {
            expecting_opts = 0;
        }

        arg = ngx_array_push(args);
        if (arg == NULL) {
            return NGX_ERROR;
        }

        *arg = *raw;
    }

    return NGX_OK;
}


static ngx_int_t
ngx_stream_echo_exec_echo(ngx_stream_session_t *s,
    ngx_stream_echo_ctx_t *ctx, ngx_array_t *args, ngx_array_t *opts)
{
    unsigned             nl;  /* append a new line */
    ngx_str_t           *opt, *arg;
    ngx_int_t            rc;
    ngx_uint_t           i;
    ngx_chain_t         *out, *cl, **ll;
    ngx_connection_t    *c;

    c = s->connection;

    ngx_log_debug0(NGX_LOG_DEBUG_STREAM, c->log, 0,
                   "stream echo running echo");

    /* handle options first */

    nl = 1;
    opt = opts->elts;

    for (i = 0; i < opts->nelts; i++) {
        if (opt[i].len == 1 && opt[i].data[0] == 'n') {
            nl = 0;
            continue;
        }

        ngx_log_error(NGX_LOG_ERR, c->log, 0,
                      "stream echo sees unrecognized option \"-%*s\"",
                      opt[i].len, opt[i].data);
        return NGX_ERROR;
    }

    /* prepare the data to be sent (asynchronously)
     * here we avoid data copying at the price of allocating more
     * chain links and skeleton bufs */

    out = NULL;
    ll = &out;
    arg = args->elts;

    for (i = 0; i < args->nelts; i++) {
        if (arg[i].len == 0) {
            /* skip empty string args */
            continue;
        }

        dd("arg: %.*s", (int) arg[i].len, arg[i].data);

        if (i > 0) {
            /* prepend a space buf */
            cl = ngx_chain_get_free_buf(c->pool, &ctx->free);
            if (cl == NULL) {
                return NGX_ERROR;
            }

            cl->buf->memory = 1;
            cl->buf->last_buf = 0;

            cl->buf->pos = (u_char *) " ";
            cl->buf->last = cl->buf->pos + 1;

            cl->buf->tag = (ngx_buf_tag_t) &ngx_stream_echo_module;

            *ll = cl;
            ll = &cl->next;
        }

        cl = ngx_chain_get_free_buf(c->pool, &ctx->free);
        if (cl == NULL) {
            return NGX_ERROR;
        }

        cl->buf->memory = 1;
        cl->buf->last_buf = 0;

        /* the data buffer's memory is allocated in the config pool */
        cl->buf->pos = arg[i].data;
        cl->buf->last = arg[i].data + arg[i].len;

        cl->buf->tag = (ngx_buf_tag_t) &ngx_stream_echo_module;

        *ll = cl;
        ll = &cl->next;
    }

    if (nl) {   /* append a new line */
        cl = ngx_chain_get_free_buf(c->pool, &ctx->free);
        if (cl == NULL) {
            return NGX_ERROR;
        }

        cl->buf->last_buf = 0;
        cl->buf->memory = 1;
        cl->buf->pos = (u_char *) "\n";
        cl->buf->last = cl->buf->pos + 1;
        cl->buf->tag = (ngx_buf_tag_t) &ngx_stream_echo_module;

        *ll = cl;
        /* ll = &cl->next; */
    }

    if (out == NULL) {
        /* do nothing */
        return NGX_OK;
    }

    rc = ngx_chain_writer(&ctx->writer, out);

    dd("chain writer returned: %d", (int) rc);

    ngx_chain_update_chains(c->pool, &ctx->free, &ctx->busy, &out,
                            (ngx_buf_tag_t) &ngx_stream_echo_module);

    return rc;
}


static ngx_int_t
ngx_stream_echo_send_last_buf(ngx_stream_session_t *s)
{
    ngx_int_t                    rc;
    ngx_chain_t                 *out;
    ngx_connection_t            *c;
    ngx_stream_echo_ctx_t       *ctx;

    ctx = ngx_stream_get_module_ctx(s, ngx_stream_echo_module);

    c = s->connection;

    ngx_log_debug0(NGX_LOG_DEBUG_STREAM, c->log, 0,
                   "stream echo send last buf");

    out = ngx_chain_get_free_buf(c->pool, &ctx->free);
    if (out == NULL) {
        return NGX_ERROR;
    }

    out->buf->memory = 0;
    out->buf->last_buf = 1;
    out->buf->tag = (ngx_buf_tag_t) &ngx_stream_echo_module;

    rc = ngx_chain_writer(&ctx->writer, out);

    ngx_chain_update_chains(c->pool, &ctx->free, &ctx->busy, &out,
                            (ngx_buf_tag_t) &ngx_stream_echo_module);

    return rc;
}


static void
ngx_stream_echo_writer(ngx_event_t *ev)
{
    ngx_int_t                    rc;
    ngx_chain_t                 *out;
    ngx_connection_t            *c;
    ngx_stream_session_t        *s;
    ngx_stream_echo_ctx_t       *ctx;
    ngx_stream_echo_srv_conf_t  *escf;

    ngx_log_debug0(NGX_LOG_DEBUG_STREAM, ev->log, 0,
                   "stream echo writer handler");

    c = ev->data;
    s = c->data;

    if (ev->timedout) {
        ngx_log_error(NGX_LOG_INFO, c->log, NGX_ETIMEDOUT,
                      "stream client send timed out");
        c->timedout = 1;

        ngx_stream_echo_finalize_session(s, NGX_ERROR);
        return;
    }

    ctx = ngx_stream_get_module_ctx(s, ngx_stream_echo_module);
    if (ctx == NULL) {
        /* cannot really happen */
        return;
    }

    rc = ngx_chain_writer(&ctx->writer, NULL);

    out = NULL;
    ngx_chain_update_chains(c->pool, &ctx->free, &ctx->busy, &out,
                            (ngx_buf_tag_t) &ngx_stream_echo_module);

    if (rc == NGX_ERROR) {
        ngx_stream_echo_finalize_session(s, NGX_ERROR);
        return;
    }

    if (rc == NGX_AGAIN) {
        if (!c->write->ready) {
            escf = ngx_stream_get_module_srv_conf(s, ngx_stream_echo_module);

            ngx_add_timer(c->write, escf->send_timeout);

        } else if (c->write->timer_set) {
            ngx_del_timer(c->write);
        }

        if (ngx_handle_write_event(c->write, 0) != NGX_OK) {
            ngx_stream_echo_finalize_session(s, NGX_ERROR);
        }

        return;
    }

    /* rc == NGX_OK */

    if (ctx->done) {
        /* all the commands are done */
        ngx_stream_echo_finalize_session(s, NGX_OK);
        return;
    }

    ngx_stream_echo_finalize_session(s, NGX_DONE);
}


static void
ngx_stream_echo_block_reading(ngx_event_t *ev)
{
    ngx_connection_t        *c;
    ngx_stream_session_t    *s;

    c = ev->data;

    ngx_log_debug0(NGX_LOG_DEBUG_STREAM, c->log, 0,
                   "stream echo reading blocked");

    if ((ngx_event_flags & NGX_USE_LEVEL_EVENT)
        && c->read->active)
    {
        if (ngx_del_event(c->read, NGX_READ_EVENT, 0) != NGX_OK) {
            s = c->data;
            ngx_stream_echo_finalize_session(s, NGX_ERROR);
        }
    }
}


static void
ngx_stream_echo_finalize_session(ngx_stream_session_t *s,
    ngx_int_t rc)
{
    ngx_connection_t            *c;
    ngx_stream_echo_ctx_t       *ctx;
    ngx_stream_echo_srv_conf_t  *escf;

    c = s->connection;

    if (rc == NGX_DONE) {   /* yield */

        if ((ngx_event_flags & NGX_USE_LEVEL_EVENT)
            && c->write->active)
        {
            if (ngx_del_event(c->write, NGX_WRITE_EVENT, 0) != NGX_OK) {
                ngx_stream_close_connection(c);
            }
        }

        return;
    }

    if (rc == NGX_ERROR || rc == NGX_DECLINED) {
        goto done;
    }

    /* rc == NGX_OK || rc == NGX_AGAIN */

    ctx = ngx_stream_get_module_ctx(s, ngx_stream_echo_module);
    if (ctx == NULL) {
        goto done;
    }

    dd("c->buffered: %d, busy: %p", (int) c->buffered, ctx->busy);

    if (ctx->busy) { /* having pending data to be sent */

        if (!c->write->ready) {
            escf = ngx_stream_get_module_srv_conf(s, ngx_stream_echo_module);

            ngx_add_timer(c->write, escf->send_timeout);

        } else if (c->write->timer_set) {
            ngx_del_timer(c->write);
        }

        if (ngx_handle_write_event(c->write, 0) != NGX_OK) {
            ngx_stream_close_connection(c);
        }

        return;
    }

done:

    ngx_stream_close_connection(c);
    return;
}


static ngx_stream_echo_ctx_t *
ngx_stream_echo_create_ctx(ngx_stream_session_t *s)
{
    ngx_connection_t            *c;
    ngx_stream_echo_ctx_t       *ctx;

    c = s->connection;

    ctx = ngx_pcalloc(c->pool, sizeof(ngx_stream_echo_ctx_t));
    if (ctx == NULL) {
        return NULL;
    }

    ctx->writer.pool = c->pool;
    ctx->writer.last = &ctx->writer.out;
    ctx->writer.connection = c;

#if 0
    ctx->sleep.handler   = ngx_stream_echo_sleep_event_handler;
    ctx->sleep.data      = s;
    ctx->sleep.log       = c->log;
#endif

    /*
     * set by ngx_pcalloc():
     *
     *      ctx->cmd_index = 0;
     *      ctx->busy = NULL;
     *      ctx->free = NULL;
     *      ctx->writer.out = NULL;
     *      ctx->writer.limit = 0;
     */

    return ctx;
}


static char *
ngx_stream_echo_echo(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    return ngx_stream_echo_helper(cf, cmd, conf, NGX_STREAM_ECHO_OPCODE_ECHO);
}


static char *
ngx_stream_echo_helper(ngx_conf_t *cf, ngx_command_t *cmd, void *conf,
    ngx_stream_echo_opcode_t opcode)
{
    ngx_stream_echo_srv_conf_t  *escf = conf;

    ngx_str_t                   *value, *arg;
    ngx_uint_t                   i;
    ngx_stream_echo_cmd_t       *echo_cmd;
    ngx_stream_core_srv_conf_t  *cscf;

    if (escf->cmds.nelts == 0) {
        cscf = ngx_stream_conf_get_module_srv_conf(cf, ngx_stream_core_module);
        cscf->handler = ngx_stream_echo_handler;
    }

    value = cf->args->elts;

    echo_cmd = ngx_array_push(&escf->cmds);
    if (echo_cmd == NULL) {
        return NGX_CONF_ERROR;
    }

    echo_cmd->opcode = opcode;

    if (ngx_array_init(&echo_cmd->raw_args, cf->pool, cf->args->nelts - 1,
                       sizeof(ngx_str_t))
        == NGX_ERROR)
    {
        return NGX_CONF_ERROR;
    }

    for (i = 1; i < cf->args->nelts; i++) {
        arg = ngx_array_push(&echo_cmd->raw_args);
        if (arg == NULL) {  /* well, cannot fail, really */
            return NGX_CONF_ERROR;
        }

        *arg = value[i];
    }

    return NGX_CONF_OK;
}


static void *
ngx_stream_echo_create_srv_conf(ngx_conf_t *cf)
{
    ngx_stream_echo_srv_conf_t  *conf;

    conf = ngx_palloc(cf->pool, sizeof(ngx_stream_echo_srv_conf_t));
    if (conf == NULL) {
        return NULL;
    }

    if (ngx_array_init(&conf->cmds, cf->pool, 1,
                       sizeof(ngx_stream_echo_cmd_t))
        == NGX_ERROR)
    {
        return NULL;
    }

    conf->send_timeout = NGX_CONF_UNSET_MSEC;

    return conf;
}


static char *
ngx_stream_echo_merge_srv_conf(ngx_conf_t *cf, void *parent, void *child)
{
    ngx_stream_echo_srv_conf_t *prev = parent;
    ngx_stream_echo_srv_conf_t *conf = child;

    if (conf->cmds.nelts == 0 && prev->cmds.nelts > 0) {
        /* assuming that these arrays are read-only afterwards */
        ngx_memcpy(&conf->cmds, &prev->cmds, sizeof(ngx_array_t));
    }

    ngx_conf_merge_msec_value(conf->send_timeout, prev->send_timeout, 60000);

    return NGX_CONF_OK;
}
