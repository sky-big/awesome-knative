# Metric功能解析

## Queue-Proxy Request Metric Handler

1. 使用Common Request Metric Handler

2. 将该Handler放在转发给用户流量Handler链条的第一个位置，用来统计该请求从queue-proxy到user-app的整体使用时间和具体执行次数和ResponseCode

## User-App Request Metric Handler

1. 使用Common Request Metric Handler

2. 将该Handler放在转发给用户流量Handler链条的最后一个位置，具体统计用户执行该请求的精确时间和具体执行次数和ResponseCode

## Common Request Metric Handler

serving/pkg/queue/request_metric.go
```
type requestMetricHandler struct {
	handler       http.Handler
	statsReporter stats.StatsReporter
	breaker       *Breaker
}

func (h *requestMetricHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	rr := pkghttp.NewResponseRecorder(w, http.StatusOK)
    // 记录请求开始时间
	startTime := time.Now()
	if h.breaker != nil {
		h.statsReporter.ReportQueueDepth(h.breaker.InFlight())
	}

	defer func() {
		// Filter probe requests for revision metrics.
        // 如果是Probe请求则直接过滤掉
		if network.IsProbe(r) {
			return
		}

		// If ServeHTTP panics, recover, record the failure and panic again.
		err := recover()
        // 获取执行时间
		latency := time.Since(startTime)
		if err != nil {
			h.sendRequestMetrics(http.StatusInternalServerError, latency)
			panic(err)
		}
        // 发送给StatusReporter数据进行上报数据
		h.sendRequestMetrics(rr.ResponseCode, latency)
	}()

	h.handler.ServeHTTP(rr, r)
}
```

## Status Reporter

serving/pkg/queue/stats/stats_reporter.go
```
type Reporter struct {
	initialized     bool
	ctx             context.Context
	countMetric     *stats.Int64Measure
	latencyMetric   *stats.Float64Measure
	queueSizeMetric *stats.Int64Measure // NB: this can be nil, depending on the reporter.
}

// 上报执行次数(App或者Queue-Proxy Metric Handler都会上报)
// ReportRequestCount captures request count metric.
func (r *Reporter) ReportRequestCount(responseCode int) error {
	if !r.initialized {
		return errors.New("StatsReporter is not initialized yet")
	}

	// Note that service names can be an empty string, so it needs a special treatment.
	ctx, err := tag.New(
		r.ctx,
		tag.Insert(metrics.ResponseCodeKey, strconv.Itoa(responseCode)),
		tag.Insert(metrics.ResponseCodeClassKey, responseCodeClass(responseCode)))
	if err != nil {
		return err
	}

	pkgmetrics.Record(ctx, r.countMetric.M(1))
	return nil
}

// 上报Breaker里面的排队请求个数(只有App Metric Handler会上报)
// ReportQueueDepth captures queue depth metric.
func (r *Reporter) ReportQueueDepth(d int) error {
	if !r.initialized {
		return errors.New("StatsReporter is not initialized yet")
	}

	pkgmetrics.Record(r.ctx, r.queueSizeMetric.M(int64(d)))
	return nil
}

// 上报执行执行时间(App或者Queue-Proxy Metric Handler都会上报)
// ReportResponseTime captures response time requests
func (r *Reporter) ReportResponseTime(responseCode int, d time.Duration) error {
	if !r.initialized {
		return errors.New("StatsReporter is not initialized yet")
	}

	// Note that service names can be an empty string, so it needs a special treatment.
	ctx, err := tag.New(
		r.ctx,
		tag.Insert(metrics.ResponseCodeKey, strconv.Itoa(responseCode)),
		tag.Insert(metrics.ResponseCodeClassKey, responseCodeClass(responseCode)))
	if err != nil {
		return err
	}

	pkgmetrics.Record(ctx, r.latencyMetric.M(float64(d.Milliseconds())))
	return nil
}

// responseCodeClass converts response code to a string of response code class.
// e.g. The response code class is "5xx" for response code 503.
func responseCodeClass(responseCode int) string {
	// Get the hundred digit of the response code and concatenate "xx".
	return strconv.Itoa(responseCode/100) + "xx"
}
```