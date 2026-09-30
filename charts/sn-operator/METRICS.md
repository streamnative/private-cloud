# sn-operator metrics 指标说明

本文介绍 sn-operator manager 自身的 `/metrics` 指标，帮助排查控制器协调、工作队列、进程资源和许可证状态。Pulsar Broker、BookKeeper、ZooKeeper 等由 operator 管理的组件有各自的指标端点，不包含在这里。

内容依据 `sn-operator` 源码的 `v0.20.14` tag，以及 2026-09-30 从 `kind-kind` 集群 `pulsar/sn-operator` 抓取的一次样本。该部署使用 `--metrics-bind-address=0.0.0.0:8080` 和 `--metrics-secure=false`；HTTP 请求返回 200，样本中有 65 个带 `TYPE` 声明的指标族。控制器数量、时间序列和可见指标会随运行状态变化。

## 抓取方式

在一个终端转发 metrics Service：

```bash
kubectl --context kind-kind -n pulsar port-forward \
  service/sn-operator-controller-manager-metrics-service 18080:8080
```

在另一个终端抓取：

```bash
curl --noproxy '*' http://127.0.0.1:18080/metrics
```

`metrics.secure=false` 时端点使用 HTTP，不需要 bearer token。设为 `true` 时端点使用 HTTPS，且请求需要获得 `/metrics` 读取权限的 Kubernetes ServiceAccount token；chart 的 ServiceMonitor 会按该值选择协议。ServiceMonitor 还需要集群安装对应 CRD，当前 kind 集群未安装该 CRD。

## 指标来源和数量

下表是这次抓取中实际出现的指标族数量。`counter` 是累计值，通常用 `rate()` 查看变化率；`gauge` 是当前值；`histogram` 会展开为 `_bucket`、`_sum` 和 `_count` 时间序列。

| 来源 | 前缀或名称 | 指标族数 | 用途 |
| --- | --- | ---: | --- |
| sn-operator | `streamnative_pulsar_license_*` | 8 | 许可证时间、额度、状态和数量 |
| controller-runtime | `controller_runtime_*` | 8 | 控制器协调次数、错误、耗时和 worker |
| Kubernetes 工作队列 | `workqueue_*` | 7 | 队列深度、重试和等待或处理耗时 |
| Kubernetes REST 客户端 | `rest_client_requests_total` | 1 | operator 发出的 API 请求 |
| Leader election | `leader_election_master_status` | 1 | 当前实例是否持有 leader lease |
| 证书监听器 | `certwatcher_*` | 2 | 证书读取及错误次数 |
| Go 运行时 | `go_*` | 29 | GC、堆内存、goroutine 和线程 |
| 进程采集器 | `process_*` | 9 | CPU、内存、文件描述符和网络字节数 |

## 许可证指标

这些指标由 `pkg/monitoring/monitoring.go` 注册，由 `pkg/license/sn_license.go` 在加载和检查许可证时更新。除 `license_valid_licenses` 外，标签均为 `license_id` 和 `type`；`license_id` 来自许可证的 `jti`，`type` 来自许可证类型。表中的时间戳是 Unix 秒，天数按 86,400 秒取整。

| 指标名，省略共同前缀 `streamnative_pulsar_` | 类型 | 含义 |
| --- | --- | --- |
| `license_metrics_issue_time` | gauge | 许可证 `iat`，签发时间 |
| `license_metrics_not_before_time` | gauge | 许可证 `nbf`，开始生效时间 |
| `license_metrics_expire_time` | gauge | 许可证 `exp`，过期时间 |
| `license_max_compute_unit` | gauge | 许可证声明的最大计算单元值 |
| `license_max_storage_unit` | gauge | 许可证声明的最大存储单元值 |
| `license_valid_licenses` | gauge | 验证通过的许可证数量；没有 `license_id`、`type` 标签 |
| `license_valid_status` | gauge | `1` 为有效，`0` 为过期，`-1` 为没有有效许可证 |
| `license_expire_close_days` | gauge | 有效许可证距离过期的完整天数 |
| `license_expired_days` | gauge | 已过期的完整天数；源码已注册，但这次抓取未出现 |

`license_expire_close_days` 仅在检查有效许可证时设置；`license_expired_days` 仅在检查到过期许可证时设置。因此已注册的指标不一定在每次抓取中都有时间序列。额度值由许可证 claim 转为 Kubernetes `resource.Quantity` 后取 `Value()`；不要把 `license_max_storage_unit` 直接解释为字节数。

## 控制器协调指标

这些指标由 controller-runtime 产生，主要以 `controller` 标签区分控制器。当前样本有 23 个不同的控制器标签值；实际数量取决于启用的控制器和运行状态。

| 指标 | 类型 | 含义 |
| --- | --- | --- |
| `controller_runtime_reconcile_total` | counter | 协调调用累计次数，另有 `result` 标签 |
| `controller_runtime_reconcile_errors_total` | counter | 协调错误累计次数 |
| `controller_runtime_terminal_reconcile_errors_total` | counter | 终止性协调错误累计次数 |
| `controller_runtime_reconcile_panics_total` | counter | 协调 panic 累计次数 |
| `controller_runtime_reconcile_time_seconds` | histogram | 每次协调的耗时，单位秒 |
| `controller_runtime_active_workers` | gauge | 当前正在工作的 worker 数量 |
| `controller_runtime_max_concurrent_reconciles` | gauge | 配置的最大并行协调数量 |
| `controller_runtime_webhook_panics_total` | counter | Webhook panic 累计次数，不带 `controller` 标签 |

例如，按控制器看最近五分钟的错误速率和协调耗时 P95：

```promql
sum by (controller) (rate(controller_runtime_reconcile_errors_total[5m]))
histogram_quantile(0.95, sum by (controller, le) (rate(controller_runtime_reconcile_time_seconds_bucket[5m])))
```

## 工作队列指标

`workqueue_*` 指标带 `controller` 和 `name` 标签；两个 histogram 的 bucket 时间序列还带 `le`。队列深度反映积压量，重试计数和耗时有助于区分排队与处理变慢。

| 指标 | 类型 | 含义 |
| --- | --- | --- |
| `workqueue_adds_total` | counter | 加入队列的请求累计次数 |
| `workqueue_depth` | gauge | 当前队列长度 |
| `workqueue_retries_total` | counter | 重试累计次数 |
| `workqueue_queue_duration_seconds` | histogram | 请求从入队到取出的等待时间 |
| `workqueue_work_duration_seconds` | histogram | 请求被取出后的处理时间 |
| `workqueue_longest_running_processor_seconds` | gauge | 当前运行最久的处理器已运行时间 |
| `workqueue_unfinished_work_seconds` | gauge | 尚未完成且尚未计入处理耗时的工作量，以秒表示 |

例如，查看各队列的当前深度：

```promql
max by (controller, name) (workqueue_depth)
```

## 其他运行指标

- `rest_client_requests_total` 是 operator 向 Kubernetes API 发出的 HTTP 请求累计数，标签为 `code`、`method` 和 `host`。它不是访问 `/metrics` 的请求数。
- `leader_election_master_status` 以 `name` 标识 lease；`1` 表示当前实例持有 leader lease，`0` 表示未持有。
- `certwatcher_read_certificate_total` 和 `certwatcher_read_certificate_errors_total` 分别统计证书读取及读取错误。即使当前 metrics 使用 HTTP，这两个已注册的指标族仍可能出现在端点中。
- `go_*` 是 Go 运行时指标。常用项包括 `go_goroutines`、`go_gc_duration_seconds`、`go_memstats_heap_alloc_bytes`、`go_memstats_heap_objects`、`go_threads`；其余 `go_memstats_*` 描述不同的内存类别。
- `process_*` 是进程指标。常用项包括 `process_cpu_seconds_total`、`process_resident_memory_bytes`、`process_open_fds`、`process_network_receive_bytes_total` 和 `process_network_transmit_bytes_total`。

指标的完整名称、类型和英文 HELP 文本可直接从端点查看：

```bash
curl --noproxy '*' -s http://127.0.0.1:18080/metrics | grep -E '^# (HELP|TYPE) '
```

## 源码依据

- `sn-operator` tag `v0.20.14` 的 [main.go](https://github.com/streamnative/sn-operator/blob/v0.20.14/main.go)：metrics 监听地址、`--metrics-secure`、认证过滤器和注册调用。
- [pkg/monitoring/monitoring.go](https://github.com/streamnative/sn-operator/blob/v0.20.14/pkg/monitoring/monitoring.go)：九个许可证指标的名称、HELP 文本、类型和标签。
- [pkg/license/sn_license.go](https://github.com/streamnative/sn-operator/blob/v0.20.14/pkg/license/sn_license.go)：许可证 claim 到指标值的映射，以及有效、过期和无有效许可证时的赋值逻辑。
- [go.mod](https://github.com/streamnative/sn-operator/blob/v0.20.14/go.mod)：controller-runtime、Kubernetes client-go 和 Prometheus Go client 依赖。其框架指标的实际 HELP 文本和数量以上述抓取样本为准。
