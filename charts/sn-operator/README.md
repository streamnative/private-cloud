# StreamNative Private Cloud

StreamNative Private Cloud is an enterprise product which brings specific controllers for Kubernetes by providing specific Custom Resource Definitions (CRDs) that extend the basic Kubernetes orchestration capabilities to support the setup and management of StreamNative components.
    
### Capabilities

With StreamNative Private Cloud, you can simplify operations and maintenance, including:
- Provisioning and managing multiple Pulsar clusters
- Scaling Pulsar clusters through rolling upgrades
- Managing the Pulsar cluster configurations through declarative APIs
- Simplify the cluster operation with Auto-Scaling
- Cost efficiency with the Lakehouse tiered storage

### Apply for trial

Before installing StreamNative Private Cloud, you need to import a valid license. You can contact StreamNative to apply for a [free trial](https://streamnative.io/deployment/start-free-trial). 

### Quick Start

Follow our [Quick Start](https://docs.streamnative.io/private/private-cloud-quickstart) guide to quickly provision and manage Pulsar clusters with the StreamNative Private Cloud.

### Operator metrics

The manager exposes `/metrics` on `0.0.0.0:8080` by default. With
`metrics.secure: true`, the v0.20.14 image serves HTTPS and requires an
authorized Kubernetes ServiceAccount bearer token. The chart creates
a `sn-operator-controller-manager-metrics-service` Service on the same port.
It also binds the operator ServiceAccount to `system:auth-delegator` so the
operator can validate tokens and authorize requests.
You can enable a ServiceMonitor when the Prometheus Operator CRD is installed
and your Prometheus instance selects ServiceMonitors in the operator namespace:

```yaml
metrics:
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prometheus
    tlsConfig:
      insecureSkipVerify: true
    authorization:
      type: Bearer
      credentials:
        name: sn-operator-metrics-token
        key: token
  reader:
    enabled: true
    serviceAccountName: prometheus
    serviceAccountNamespace: monitoring
```

Set `metrics.service.annotations` if your scraper discovers Services through
annotations.

To use a different metrics port, change `metrics.port`; the manager, Service,
and ServiceMonitor will stay aligned. For example, port 8443 only requires:

```yaml
metrics:
  port: 8443
```

The Secret named in `authorization.credentials` must exist in the
ServiceMonitor namespace and contain a valid token for the reader
ServiceAccount. The optional `metrics.reader` settings create a ClusterRole
and ClusterRoleBinding that grant only GET access to the `/metrics`
non-resource URL. Use a trusted CA in `tlsConfig` instead of
`insecureSkipVerify` when one is available.

Kubernetes issues the bearer token for the reader ServiceAccount. For a
short-lived manual check, use `kubectl -n monitoring create token prometheus`.
That command does not create the Secret referenced by ServiceMonitor; a
long-running scraper needs a token source that it can refresh.

To disable token authentication, set:

```yaml
metrics:
  secure: false
  serviceMonitor:
    enabled: true
```

This serves `/metrics` over unauthenticated HTTP. The ServiceMonitor selects
HTTP automatically and omits TLS and authorization settings; the metrics
authorization RBAC resources are also omitted. Any client that can reach the
metrics Service can then read the endpoint.
