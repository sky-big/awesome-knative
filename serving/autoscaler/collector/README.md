# Collector功能解析

## Data Struct

```
serving/pkg/autoscaler/collector.go

// MetricCollector manages collection of metrics for many entities.
type MetricCollector struct {
	logger *zap.SugaredLogger

	statsScraperFactory StatsScraperFactory
	tickProvider        func(time.Duration) *time.Ticker

	collections      map[types.NamespacedName]*collection
	collectionsMutex sync.RWMutex
}
```