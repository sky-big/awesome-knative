# AutoScaling Metric Reporter功能解析

## 收取统计信息,定时上报给Prometheus Reporter

```
// serving/pkg/queue/stats.go

(1). queue-proxy Master Handler向reqCh发送每次执行的信息

(2). stats协程定时reportingPeriod = 1 * time.Second将统计信息上报给Prometheus Reporter(serving/pkg/queue/prometheus_stats_reporter.go)

(3). 在Master Handler处理中,该统计信息是先发送stats协程,再调用Breaker来判断是否能够处理该请求

// NewStats instantiates a new instance of Stats.
func NewStats(startedAt time.Time, reqCh chan ReqEvent, reportCh <-chan time.Time, report func(float64, float64, float64, float64)) {
	go func() {
		var (
			requestCount       float64
			proxiedCount       float64
			concurrency        int32
			proxiedConcurrency int32
		)

		lastChange := startedAt
		timeOnConcurrency := make(map[int32]time.Duration)
		timeOnProxiedConcurrency := make(map[int32]time.Duration)

		// Updates the lastChanged/timeOnConcurrency state
		// Note: Due to nature of the channels used below, the ReportChan
		// can race the ReqChan, thus an event can arrive that has a lower
		// timestamp than `lastChange`. This is ignored, since it only makes
		// for very slight differences.
		updateState := func(time time.Time) {
			if time.After(lastChange) {
				durationSinceChange := time.Sub(lastChange)
				timeOnConcurrency[concurrency] += durationSinceChange
				timeOnProxiedConcurrency[proxiedConcurrency] += durationSinceChange
				lastChange = time
			}
		}

		for {
			select {
			case event := <-reqCh:
				updateState(event.Time)

				switch event.EventType {
				case ProxiedIn:
					proxiedConcurrency++
					proxiedCount++
					fallthrough
				case ReqIn:
					requestCount++
					concurrency++
				case ProxiedOut:
					proxiedConcurrency--
					fallthrough
				case ReqOut:
					concurrency--
				}
			case now := <-reportCh:
				updateState(now)

				report(weightedAverage(timeOnConcurrency), weightedAverage(timeOnProxiedConcurrency), requestCount, proxiedCount)

				// Reset the stat counts which have been reported.
				timeOnConcurrency = make(map[int32]time.Duration)
				timeOnProxiedConcurrency = make(map[int32]time.Duration)
				requestCount = 0
				proxiedCount = 0
			}
		}
	}()
}

func weightedAverage(times map[int32]time.Duration) float64 {
	var totalTimeUsed time.Duration
	for _, val := range times {
		totalTimeUsed += val
	}
	avg := 0.0
	if totalTimeUsed > 0 {
		sum := 0.0
		for c, val := range times {
			sum += float64(c) * val.Seconds()
		}
		avg = sum / totalTimeUsed.Seconds()
	}
	return avg
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