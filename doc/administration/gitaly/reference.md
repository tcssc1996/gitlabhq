---
stage: Systems
group: Gitaly
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Gitaly reference **(FREE SELF)**

Gitaly is configured via a [TOML](https://github.com/toml-lang/toml)
configuration file. Unlike installations from source, in Omnibus GitLab, you
would not edit this file directly. For Omnibus GitLab installations, the default file location is `/var/opt/gitlab/gitaly/config.toml`.

The configuration file is passed as an argument to the `gitaly` executable, which is usually done by either Omnibus
GitLab or your [init](https://en.wikipedia.org/wiki/Init) script.

An [example configuration file](https://gitlab.com/gitlab-org/gitaly/blob/master/config.toml.example)
can be found in the Gitaly project.

## Format

At the top level, `config.toml` defines the items described on the table below.

| Name | Type | Required | Description |
| ---- | ---- | -------- | ----------- |
| `socket_path` | string | yes (if  `listen_addr` is not set) | A path which Gitaly should open a Unix socket. |
| `listen_addr` | string | yes (if `socket_path` is not set) | TCP address for Gitaly to listen on. |
| `tls_listen_addr` | string | no | TCP over TLS address for Gitaly to listen on. |
| `bin_dir`    | string | yes    | Directory containing Gitaly executables. |
| `prometheus_listen_addr` | string | no | TCP listen address for Prometheus metrics. If not set, no Prometheus listener is started. |

For example:

```toml
socket_path = "/home/git/gitlab/tmp/sockets/private/gitaly.socket"
listen_addr = "localhost:9999"
tls_listen_addr = "localhost:8888"
bin_dir = "/home/git/gitaly"
prometheus_listen_addr = "localhost:9236"
```

### Authentication

Gitaly can be configured to reject requests that do not contain a
specific bearer token in their headers, which is a security measure to
be used when serving requests over TCP:

```toml
[auth]
# A non-empty token enables authentication.
token = "the secret token"
```

Authentication is disabled when the token setting in `config.toml` is absent or
an empty string.

It is possible to temporarily disable authentication with the `transitioning`
setting. This allows you to monitor if all clients are
authenticating correctly without causing a service outage for clients
that are still to be configured correctly:

```toml
[auth]
token = "the secret token"
transitioning = true
```

WARNING:
Remember to disable `transitioning` when you are done
changing your token settings.

All authentication attempts are counted in Prometheus under
the [`gitaly_authentications_total` metric](monitoring.md#queries).

### TLS

Gitaly supports TLS encryption. You need to bring your own certificates as
this isn't provided automatically.

| Name | Type | Required | Description |
| ---- | ---- | -------- | ----------- |
| `certificate_path` | string | no | Path to the certificate. |
| `key_path` | string | no | Path to the key. |

```toml
tls_listen_addr = "localhost:8888"

[tls]
certificate_path = '/home/git/cert.cert'
key_path = '/home/git/key.pem'
```

[Read more](configure_gitaly.md#enable-tls-support) about TLS in Gitaly.

### Storage

GitLab repositories are grouped into directories known as storages, such as
`/home/git/repositories`. They contain bare repositories managed
by GitLab with names, such as `default`.

These names and paths are also defined in the `gitlab.yml` configuration file of
GitLab. When you run Gitaly on the same machine as GitLab (the default
and recommended configuration) storage paths defined in the Gitaly `config.toml`
must match those in `gitlab.yml`.

| Name | Type | Required | Description |
| ---- | ---- | -------- | ----------- |
| `storage` | array | yes | An array of storage shards. |
| `path` | string | yes | The path to the storage shard. |
| `name` | string | yes | The name of the storage shard. |

For example:

```toml
[[storage]]
path = "/path/to/storage/repositories"
name = "my_shard"

[[storage]]
path = "/path/to/other/repositories"
name = "other_storage"
```

### Git

The following values can be set in the `[git]` section of the configuration file.

| Name | Type | Required | Description |
| ---- | ---- | -------- | ----------- |
| `bin_path` | string | no | Path to Git binary. If not set, is resolved using `PATH`. |
| `catfile_cache_size` | integer | no | Maximum number of cached [cat-file processes](#cat-file-cache). Default is `100`. |
| `signing_key` | string | no | Path to [GPG signing key](configure_gitaly.md#configure-commit-signing-for-gitlab-ui-commits). If not set, Gitaly doesn't sign commits made using the UI. [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/19185) in GitLab 15.4. |

#### `cat-file` cache

A lot of Gitaly RPCs need to look up Git objects from repositories.
Most of the time we use `git cat-file --batch` processes for that. For
better performance, Gitaly can re-use these `git cat-file` processes
across RPC calls. Previously used processes are kept around in a
["Git cat-file cache"](https://about.gitlab.com/blog/2019/07/08/git-performance-on-nfs/#enter-cat-file-cache).
To control how much system resources this uses, we have a maximum number of
cat-file processes that can go into the cache.

The default limit is 100 `cat-file`s, which constitute a pair of
`git cat-file --batch` and `git cat-file --batch-check` processes. If
you are seeing errors complaining about "too many open files", or an
inability to create new processes, you may want to lower this limit.

Ideally, the number should be large enough to handle standard
traffic. If you raise the limit, you should measure the cache hit ratio
before and after. If the hit ratio does not improve, the higher limit is
probably not making a meaningful difference. Here is an example
Prometheus query to see the hit rate:

```plaintext
sum(rate(gitaly_catfile_cache_total{type="hit"}[5m])) / sum(rate(gitaly_catfile_cache_total{type=~"(hit)|(miss)"}[5m]))
```

### GitLab Shell

For historical reasons
[GitLab Shell](https://gitlab.com/gitlab-org/gitlab-shell) contains
the Git hooks that allow GitLab to validate and react to Git pushes.
Because Gitaly "owns" Git pushes, GitLab Shell must therefore be
installed alongside Gitaly.

| Name | Type | Required | Description |
| ---- | ---- | -------- | ----------- |
| `dir` | string | yes | The directory where GitLab Shell is installed.|

Example:

```toml
[gitlab-shell]
dir = "/home/git/gitlab-shell"
```

### Prometheus

You can optionally configure Gitaly to record histogram latencies on GRPC method
calls in Prometheus.

| Name | Type | Required | Description |
| ---- | ---- | -------- | ----------- |
| `grpc_latency_buckets` | array | no | Prometheus stores each observation in a bucket, which means you'd get an approximation of latency. Optimizing the buckets gives more control over the accuracy of the approximation. |

Example:

```toml
prometheus_listen_addr = "localhost:9236"

[prometheus]
grpc_latency_buckets = [0.001, 0.005, 0.025, 0.1, 0.5, 1.0, 10.0, 30.0, 60.0, 300.0, 1500.0]
```

### Logging

The following values configure logging in Gitaly under the `[logging]` section.

| Name | Type | Required | Description |
| ---- | ---- | -------- | ----------- |
| `format` | string | no | Log format: `text` or `json`. Default: `text`. |
| `level`  | string | no | Log level: `debug`, `info`, `warn`, `error`, `fatal`, or `panic`. Default: `info`. |
| `sentry_dsn` | string | no | Sentry DSN (Data Source Name) for exception monitoring. |
| `sentry_environment` | string | no | [Sentry Environment](https://docs.sentry.io/product/sentry-basics/environments/) for exception monitoring. |

While the main Gitaly application logs go to `stdout`, there are some extra log
files that go to a configured directory, like the GitLab Shell logs.
GitLab Shell does not support `panic` or `trace` level logs:

- `panic` falls back to `error`.
- `trace` falls back to `debug`.
- Any other invalid log levels default to `info`.

Example:

```toml
[logging]
level = "warn"
dir = "/home/gitaly/logs"
format = "json"
sentry_dsn = "https://<key>:<secret>@sentry.io/<project>"
ruby_sentry_dsn = "https://<key>:<secret>@sentry.io/<project>"
```

## Concurrency

You can adjust the `concurrency` of each RPC endpoint.

| Name | Type | Required | Description |
| ---- | ---- | -------- | ----------- |
| `concurrency` | array | yes | An array of RPC endpoints. |
| `rpc` | string | no | The name of the RPC endpoint (`/gitaly.RepositoryService/GarbageCollect`). |
| `max_per_repo` | integer | no | Concurrency per RPC per repository. |

Example:

```toml
[[concurrency]]
rpc = "/gitaly.RepositoryService/GarbageCollect"
max_per_repo = 1
```
