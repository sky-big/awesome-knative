# Revision Throttler功能解析

## Data Struct

```
serving/pkg/activator/net/throttler.go

type revisionThrottler struct {
	revID                types.NamespacedName
	containerConcurrency int

	// Holds the current number of backends. This is used for when we get an activatorCount update and
	// therefore need to recalculate capacity
	backendCount int

	// This is a breaker for the revision as a whole. try calls first pass through
	// this breaker and are either called with clusterIPDest or go through selecting
	// a podIPTracker and are then called.
	breaker breaker

	// This will be non empty when we're able to use pod addressing.
	podTrackers []*podTracker

	// Effective trackers that are assigned to this Activator.
	// This is a subset of podIPTrackers.
	assignedTrackers []*podTracker

	// If we dont have a healthy clusterIPTracker this is set to nil, otherwise
	// it is the l4dest for this revision's private clusterIP.
	clusterIPTracker *podTracker

	// mux guards "throttle state" which is the state we use during the request path. This
	// is trackers, clusterIPDest.
	mux sync.RWMutex

	// used to atomically calculate and set capacity
	capacityMux sync.Mutex

	logger *zap.SugaredLogger
}
```