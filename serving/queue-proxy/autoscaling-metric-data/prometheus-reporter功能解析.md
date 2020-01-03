# AutoScaling Prometheus Reporter功能解析

1. Stats Reporter定时将当前负载统计数据发布到Prometheus Reporter

2. Prometheus Reporter就是Prometheus Exporter

## Prometheus Exporter

1. 启动9090端口的Prometheus Exporter服务供Prometheus Server定时来获取统计信息

```
serving/cmd/queue/main.go

func buildMetricsServer(promStatReporter *queue.PrometheusStatsReporter) *http.Server {
	metricsMux := http.NewServeMux()
	metricsMux.Handle("/metrics", promStatReporter.Handler())
	return &http.Server{
		Addr:    ":" + strconv.Itoa(networking.AutoscalingQueueMetricsPort),
		Handler: metricsMux,
	}
}
```

## Prometheus Reporter

1. 数据结构

```
// serving/pkg/queue/prometheus_stats_reporter.go

type PrometheusStatsReporter struct {
	handler         http.Handler
	reportingPeriod time.Duration

	requestsPerSecond                prometheus.Gauge
	proxiedRequestsPerSecond         prometheus.Gauge
	averageConcurrentRequests        prometheus.Gauge
	averageProxiedConcurrentRequests prometheus.Gauge
}
```

2. 处理过程

```
// NewPrometheusStatsReporter creates a reporter that collects and reports queue metrics.
func NewPrometheusStatsReporter(namespace, config, revision, pod string, reportingPeriod time.Duration) (*PrometheusStatsReporter, error) {
	if namespace == "" {
		return nil, errors.New("namespace must not be empty")
	}
	if config == "" {
		return nil, errors.New("config must not be empty")
	}
	if revision == "" {
		return nil, errors.New("revision must not be empty")
	}
	if pod == "" {
		return nil, errors.New("pod must not be empty")
	}

	registry := prometheus.NewRegistry()
	for _, gv := range []*prometheus.GaugeVec{requestsPerSecondGV, proxiedRequestsPerSecondGV, averageConcurrentRequestsGV, averageProxiedConcurrentRequestsGV} {
		if err := registry.Register(gv); err != nil {
			return nil, fmt.Errorf("register metric failed: %w", err)
		}
	}

	labels := prometheus.Labels{
		destinationNsLabel:     namespace,
		destinationConfigLabel: config,
		destinationRevLabel:    revision,
		destinationPodLabel:    pod,
	}

	return &PrometheusStatsReporter{
		handler:         promhttp.HandlerFor(registry, promhttp.HandlerOpts{}),
		reportingPeriod: reportingPeriod,

		requestsPerSecond:                requestsPerSecondGV.With(labels),
		proxiedRequestsPerSecond:         proxiedRequestsPerSecondGV.With(labels),
		averageConcurrentRequests:        averageConcurrentRequestsGV.With(labels),
		averageProxiedConcurrentRequests: averageProxiedConcurrentRequestsGV.With(labels),
	}, nil
}

// stats协程上报接口
// Report captures request metrics.
func (r *PrometheusStatsReporter) Report(acr float64, apcr float64, rc float64, prc float64) {
	// Requests per second is a rate over time while concurrency is not.
	r.requestsPerSecond.Set(rc / r.reportingPeriod.Seconds())
	r.proxiedRequestsPerSecond.Set(prc / r.reportingPeriod.Seconds())
	r.averageConcurrentRequests.Set(acr)
	r.averageProxiedConcurrentRequests.Set(apcr)
}

// 通过9090端口暴露出的Prometheus Exporter端口服务处理Handler
// Handler returns an uninstrumented http.Handler used to serve stats registered by this
// PrometheusStatsReporter.
func (r *PrometheusStatsReporter) Handler() http.Handler {
	return r.handler
}
```