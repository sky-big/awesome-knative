# Throttler功能解析

## Data Struct

```
serving/pkg/activator/net/throttler.go

type Throttler struct {
	revisionThrottlers      map[types.NamespacedName]*revisionThrottler
	revisionThrottlersMutex sync.RWMutex
	breakerParams           queue.BreakerParams                         // 队列配置,队列长度最大为10000,最大的并发上限为1000
	revisionLister          servinglisters.RevisionLister               // revision资源的informer组成的Lister
	numActivators           int32  // Total number of activators.
	activatorIndex          int32  // The assigned index of this activator, -1 is Activator is not expected to receive traffic.
	ipAddress               string // The IP address of this activator.
	logger                  *zap.SugaredLogger
}
```

## Init Throttler

```
serving/pkg/activator/net/throttler.go

func NewThrottler(ctx context.Context,
	breakerParams queue.BreakerParams,
	ipAddr string) *Throttler {
	// 从Context获取revision Informer
	revisionInformer := revisioninformer.Get(ctx)
	t := &Throttler{
		revisionThrottlers: make(map[types.NamespacedName]*revisionThrottler),
		breakerParams:      breakerParams,
		revisionLister:     revisionInformer.Lister(),
		ipAddress:          ipAddr,
		activatorIndex:     -1, // Unset yet.
		logger:             logging.FromContext(ctx),
	}

    // 监听Revision资源的创建删除事件然后创建对应Revsion的Throttler对象
	// Watch revisions to create throttler with backlog immediately and delete
	// throttlers on revision delete
	revisionInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
		AddFunc:    t.revisionUpdated,
		UpdateFunc: controller.PassNew(t.revisionUpdated),
		DeleteFunc: t.revisionDeleted,
	})

    // 监听kubernetes资源endpoint
	// Watch activator endpoint to maintain activator count
	endpointsInformer := endpointsinformer.Get(ctx)
	endpointsInformer.Informer().AddEventHandler(cache.FilteringResourceEventHandler{
		FilterFunc: reconciler.ChainFilterFuncs(
			reconciler.NameFilterFunc(networking.ActivatorServiceName),
			reconciler.NamespaceFilterFunc(system.Namespace()),
		),
		Handler: cache.ResourceEventHandlerFuncs{
			AddFunc:    t.activatorEndpointsUpdated,
			UpdateFunc: controller.PassNew(t.activatorEndpointsUpdated),
		},
	})

	return t
}
```