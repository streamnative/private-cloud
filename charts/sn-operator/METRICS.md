# sn-operator metrics reference

This document describes the sn-operator manager's `/metrics` endpoint. These metrics help diagnose controller reconciliation, work queues, process resource usage, and license status. Components managed by the operator, such as Pulsar Broker, BookKeeper, and ZooKeeper, expose their own metrics endpoints and are outside the scope of this reference.

The descriptions are based on the `v0.20.14` tag of the `sn-operator` source code and a sample scraped from `pulsar/sn-operator` in the `kind-kind` cluster on 2026-09-30. That deployment used `--metrics-bind-address=0.0.0.0:8080` and `--metrics-secure=false`. An HTTP request returned 200, and the sample contained 65 metric families with `TYPE` declarations. The number of controllers, time series, and visible metrics varies with runtime state.

## Scraping the endpoint

Forward the metrics Service in one terminal:

```bash
kubectl --context kind-kind -n pulsar port-forward \
  service/sn-operator-controller-manager-metrics-service 18080:8080
```

Scrape it from another terminal:

```bash
curl --noproxy '*' http://127.0.0.1:18080/metrics
```

With `metrics.secure=false`, the endpoint uses HTTP and requires no bearer token. With `metrics.secure=true`, it uses HTTPS and requires a Kubernetes ServiceAccount token authorized to read `/metrics`. The chart's ServiceMonitor selects the protocol according to this setting. A ServiceMonitor also requires its CRD to be installed; the current kind cluster does not have that CRD.

## Metric sources and counts

The following counts are the metric families present in the sample. A `counter` is cumulative and is commonly viewed with `rate()`. A `gauge` reports a current value. A `histogram` expands into `_bucket`, `_sum`, and `_count` time series.

| Source | Prefix or name | Families | Purpose |
| --- | --- | ---: | --- |
| sn-operator | `streamnative_pulsar_license_*` | 8 | License timestamps, quotas, status, and count |
| controller-runtime | `controller_runtime_*` | 8 | Reconciliation counts, errors, duration, and workers |
| Kubernetes work queue | `workqueue_*` | 7 | Queue depth, retries, and wait or processing time |
| Kubernetes REST client | `rest_client_requests_total` | 1 | API requests made by the operator |
| Leader election | `leader_election_master_status` | 1 | Whether this instance holds the leader lease |
| Certificate watcher | `certwatcher_*` | 2 | Certificate reads and read errors |
| Go runtime | `go_*` | 29 | GC, heap memory, goroutines, and threads |
| Process collector | `process_*` | 9 | CPU, memory, file descriptors, and network bytes |

## License metrics

These metrics are registered in `pkg/monitoring/monitoring.go` and updated by `pkg/license/sn_license.go` when licenses are loaded and checked. Except for `license_valid_licenses`, they have `license_id` and `type` labels. `license_id` comes from the license's `jti` claim, and `type` comes from its license type. Timestamps in the table are Unix seconds; day counts are rounded down in units of 86,400 seconds.

| Metric (omit the shared `streamnative_pulsar_` prefix) | Type | Description |
| --- | --- | --- |
| `license_metrics_issue_time` | gauge | License issue time (`iat`). |
| `license_metrics_not_before_time` | gauge | Time when the license becomes valid (`nbf`). |
| `license_metrics_expire_time` | gauge | License expiration time (`exp`). |
| `license_max_compute_unit` | gauge | Maximum compute unit value declared by the license. |
| `license_max_storage_unit` | gauge | Maximum storage unit value declared by the license. |
| `license_valid_licenses` | gauge | Number of validated licenses; has no `license_id` or `type` labels. |
| `license_valid_status` | gauge | `1` for valid, `0` for expired, and `-1` when no valid license exists. |
| `license_expire_close_days` | gauge | Number of complete days until a valid license expires. |
| `license_expired_days` | gauge | Number of complete days since expiration; registered in the source code but absent from this scrape. |

`license_expire_close_days` is set only when a valid license is checked; `license_expired_days` is set only when an expired license is checked. A registered metric therefore may have no time series in a given scrape. Quota claims are converted to Kubernetes `resource.Quantity` values before `Value()` is read. Do not interpret `license_max_storage_unit` directly as a byte count.

## Controller reconciliation metrics

controller-runtime produces these metrics. The `controller` label identifies the controller for most of them. The sample had 23 distinct `controller` label values; the actual number depends on enabled controllers and runtime activity.

| Metric | Type | Description |
| --- | --- | --- |
| `controller_runtime_reconcile_total` | counter | Total reconciliation calls; also has a `result` label. |
| `controller_runtime_reconcile_errors_total` | counter | Total reconciliation errors. |
| `controller_runtime_terminal_reconcile_errors_total` | counter | Total terminal reconciliation errors. |
| `controller_runtime_reconcile_panics_total` | counter | Total reconciliation panics. |
| `controller_runtime_reconcile_time_seconds` | histogram | Duration of each reconciliation in seconds. |
| `controller_runtime_active_workers` | gauge | Number of workers currently active. |
| `controller_runtime_max_concurrent_reconciles` | gauge | Configured maximum number of concurrent reconciliations. |
| `controller_runtime_webhook_panics_total` | counter | Total webhook panics; has no `controller` label. |

For example, show the error rate and P95 reconciliation duration by controller over the last five minutes:

```promql
sum by (controller) (rate(controller_runtime_reconcile_errors_total[5m]))
histogram_quantile(0.95, sum by (controller, le) (rate(controller_runtime_reconcile_time_seconds_bucket[5m])))
```

## Work queue metrics

`workqueue_*` metrics have `controller` and `name` labels; bucket time series for the two histograms also have an `le` label. Queue depth shows backlog. Retry counts and durations help distinguish time spent waiting in the queue from time spent processing work.

| Metric | Type | Description |
| --- | --- | --- |
| `workqueue_adds_total` | counter | Total requests added to the queue. |
| `workqueue_depth` | gauge | Current queue length. |
| `workqueue_retries_total` | counter | Total retries. |
| `workqueue_queue_duration_seconds` | histogram | Time from enqueueing a request until a worker takes it. |
| `workqueue_work_duration_seconds` | histogram | Time spent processing a request after a worker takes it. |
| `workqueue_longest_running_processor_seconds` | gauge | Elapsed time of the longest currently running processor. |
| `workqueue_unfinished_work_seconds` | gauge | Outstanding work that has not yet been counted in work duration, expressed in seconds. |

For example, show the current depth of each queue:

```promql
max by (controller, name) (workqueue_depth)
```

## Other runtime metrics

- `rest_client_requests_total` counts HTTP requests made by the operator to the Kubernetes API. Its labels are `code`, `method`, and `host`. It does not count requests to `/metrics`.
- `leader_election_master_status` identifies the lease with a `name` label; `1` means this instance holds the leader lease, and `0` means it does not.
- `certwatcher_read_certificate_total` and `certwatcher_read_certificate_errors_total` count certificate reads and read errors, respectively. These registered metric families can appear even when the metrics endpoint uses HTTP.
- `go_*` describes the Go runtime. Common metrics include `go_goroutines`, `go_gc_duration_seconds`, `go_memstats_heap_alloc_bytes`, `go_memstats_heap_objects`, and `go_threads`. Other `go_memstats_*` metrics describe different memory categories.
- `process_*` describes the process. Common metrics include `process_cpu_seconds_total`, `process_resident_memory_bytes`, `process_open_fds`, `process_network_receive_bytes_total`, and `process_network_transmit_bytes_total`.

To see the complete metric names, types, and English HELP text from the endpoint:

```bash
curl --noproxy '*' -s http://127.0.0.1:18080/metrics | grep -E '^# (HELP|TYPE) '
```

## Source references

- [`main.go` at the `v0.20.14` tag](https://github.com/streamnative/sn-operator/blob/v0.20.14/main.go): metrics listen address, `--metrics-secure`, authentication filter, and registration calls.
- [`pkg/monitoring/monitoring.go`](https://github.com/streamnative/sn-operator/blob/v0.20.14/pkg/monitoring/monitoring.go): names, HELP text, types, and labels of the nine license metrics.
- [`pkg/license/sn_license.go`](https://github.com/streamnative/sn-operator/blob/v0.20.14/pkg/license/sn_license.go): mapping from license claims to metric values and behavior for valid, expired, and absent valid licenses.
- [`go.mod`](https://github.com/streamnative/sn-operator/blob/v0.20.14/go.mod): controller-runtime, Kubernetes client-go, and Prometheus Go client dependencies. The framework metric HELP text and counts above come from the scrape sample.
