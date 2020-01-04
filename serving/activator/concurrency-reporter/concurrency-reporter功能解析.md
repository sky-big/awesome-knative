# Concurrency Reporter功能解析

## Data Struct

```
serving/pkg/activator/handler/concurrency_reporter.go

// ConcurrencyReporter reports stats based on incoming requests and ticks.
type ConcurrencyReporter struct {
	logger  *zap.SugaredLogger
	podName string

	// Ticks with every request arrived/completed respectively
	reqCh chan ReqEvent
	// Ticks with every stat report request
	reportCh <-chan time.Time
	// Stat reporting channel
	statCh chan []autoscaler.StatMessage

	rl servinglisters.RevisionLister
	sr activator.StatsReporter
}
```

## 处理流程

```
serving/pkg/activator/handler/concurrency_reporter.go

// Run runs until stopCh is closed and processes events on all incoming channels
func (cr *ConcurrencyReporter) Run(stopCh <-chan struct{}) {
	// Contains the number of in-flight requests per-key
	outstandingRequestsPerKey := make(map[types.NamespacedName]int64)
	// Contains the number of incoming requests in the current
	// reporting period, per key.
	incomingRequestsPerKey := make(map[types.NamespacedName]int64)

	for {
		select {
		case event := <-cr.reqCh:
			switch event.EventType {
			case ReqIn:
				incomingRequestsPerKey[event.Key]++

				// Report the first request for a key immediately.
				if _, ok := outstandingRequestsPerKey[event.Key]; !ok {
					cr.statCh <- []autoscaler.StatMessage{{
						Key: event.Key,
						Stat: autoscaler.Stat{
							// Stat time is unset by design. The receiver will set the time.
							PodName:                   cr.podName,
							AverageConcurrentRequests: 1,
							RequestCount:              float64(incomingRequestsPerKey[event.Key]),
						},
					}}
				}
				outstandingRequestsPerKey[event.Key]++
			case ReqOut:
				outstandingRequestsPerKey[event.Key]--
			}
		case <-cr.reportCh:
			messages := make([]autoscaler.StatMessage, 0, len(outstandingRequestsPerKey))
			for key, concurrency := range outstandingRequestsPerKey {
				if concurrency == 0 {
					delete(outstandingRequestsPerKey, key)
				} else {
					messages = append(messages, autoscaler.StatMessage{
						Key: key,
						Stat: autoscaler.Stat{
							// Stat time is unset by design. The receiver will set the time.
							PodName:                   cr.podName,
							AverageConcurrentRequests: float64(concurrency),
							RequestCount:              float64(incomingRequestsPerKey[key]),
						},
					})
				}
				cr.reportToMetricsBackend(key, concurrency)
			}
			cr.statCh <- messages

			incomingRequestsPerKey = make(map[types.NamespacedName]int64)
		case <-stopCh:
			return
		}
	}
}
```