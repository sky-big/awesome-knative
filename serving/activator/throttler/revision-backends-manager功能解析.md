# Revision Backends Manager功能解析

## Revision Watcher

### Data Struct

```
serving/pkg/activator/net/revision_backends.go

// revisionWatcher watches the podIPs and ClusterIP of the service for a revision. It implements the logic
// to supply revisionDestsUpdate events on updateCh
type revisionWatcher struct {
	stopCh   <-chan struct{}
	cancel   context.CancelFunc
	rev      types.NamespacedName
	protocol networking.ProtocolType
	updateCh chan<- revisionDestsUpdate
	done     chan struct{}

	// Stores the list of pods that have been successfully probed.
	healthyPods sets.String
	// Stores whether the service ClusterIP has been seen as healthy
	clusterIPHealthy bool

	transport     http.RoundTripper
	destsCh       chan sets.String
	serviceLister corev1listers.ServiceLister
	logger        *zap.SugaredLogger

	// podsAddressable will be set to false if we cannot
	// probe a pod directly, but its cluster IP has beeen successfully probed.
	podsAddressable bool
}
```

## Revsion Backends Manager

### Data Struct

```
serving/pkg/activator/net/revision_backends.go

type revisionBackendsManager struct {
	ctx            context.Context
	revisionLister servinglisters.RevisionLister
	serviceLister  corev1listers.ServiceLister

	revisionWatchers    map[types.NamespacedName]*revisionWatcher
	revisionWatchersMux sync.RWMutex

	updateCh       chan revisionDestsUpdate
	transport      http.RoundTripper
	logger         *zap.SugaredLogger
	probeFrequency time.Duration
}
```

### Add Revsion Watcher

1. 监听Endpoints资源触发该增加Revision Watcher的操作

```
serving/pkg/activator/net/revision_backends.go

// endpointsUpdated is a handler function to be used by the Endpoints informer.
// It updates the endpoints in the RevisionBackendsManager if the hosts changed
func (rbm *revisionBackendsManager) endpointsUpdated(newObj interface{}) {
	// Ignore the updates when we've terminated.
	select {
	case <-rbm.ctx.Done():
		return
	default:
	}
	rbm.logger.Debugf("Endpoints updated: %#v", newObj)
	endpoints := newObj.(*corev1.Endpoints)
	revID := types.NamespacedName{endpoints.Namespace, endpoints.Labels[serving.RevisionLabelKey]}

	rw, err := rbm.getOrCreateRevisionWatcher(revID)
	if err != nil {
		rbm.logger.With(zap.Error(err)).Errorf("Failed to get revision watcher for revision %q", revID.String())
		return
	}
	dests := endpointsToDests(endpoints, networking.ServicePortName(rw.protocol))
	rbm.logger.Debugf("Updating Endpoints: %q (backends: %d)", revID.String(), len(dests))
	select {
	case <-rbm.ctx.Done():
		return
	case rw.destsCh <- dests:
	}
}
```

### Delete Revsion Watcher

1. 监听Endpoints资源触发该删除Revision Watcher的操作

```
serving/pkg/activator/net/revision_backends.go

// deleteRevisionWatcher deletes the revision watcher for rev if it exists. It expects
// a write lock is held on revisionWatchersMux when calling.
func (rbm *revisionBackendsManager) deleteRevisionWatcher(rev types.NamespacedName) {
	if rw, ok := rbm.revisionWatchers[rev]; ok {
		rw.cancel()
		delete(rbm.revisionWatchers, rev)
	}
}

func (rbm *revisionBackendsManager) endpointsDeleted(obj interface{}) {
	// Ignore the updates when we've terminated.
	select {
	case <-rbm.ctx.Done():
		return
	default:
	}
	ep := obj.(*corev1.Endpoints)
	revID := types.NamespacedName{ep.Namespace, ep.Labels[serving.RevisionLabelKey]}

	rbm.logger.Debugf("Deleting endpoint %q", revID.String())
	rbm.revisionWatchersMux.Lock()
	defer rbm.revisionWatchersMux.Unlock()
	rbm.deleteRevisionWatcher(revID)
}
```