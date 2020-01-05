# Stats Scraper功能解析

## Data Struct

```
serving/pkg/autoscaler/stats_scraper.go

// ServiceScraper scrapes Revision metrics via a K8S service by sampling. Which
// pod to be picked up to serve the request is decided by K8S. Please see
// https://kubernetes.io/docs/concepts/services-networking/network-policies/
// for details.
type ServiceScraper struct {
	sClient scrapeClient
	counter resources.ReadyPodCounter
	url     string
}
```