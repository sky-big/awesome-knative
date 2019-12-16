# informers目录生成代码解析

## Informer Factory

```
路径:serving/pkg/client/informers/externalversions/factory.go

type SharedInformerFactory interface {
	internalinterfaces.SharedInformerFactory
	ForResource(resource schema.GroupVersionResource) (GenericInformer, error)
	WaitForCacheSync(stopCh <-chan struct{}) map[reflect.Type]bool

	Autoscaling() autoscaling.Interface
	Networking() networking.Interface
	Serving() serving.Interface
}

type sharedInformerFactory struct {
	client           versioned.Interface
	namespace        string
	tweakListOptions internalinterfaces.TweakListOptionsFunc
	lock             sync.Mutex
	defaultResync    time.Duration
	customResync     map[reflect.Type]time.Duration

	informers map[reflect.Type]cache.SharedIndexInformer
	// startedInformers is used for tracking which informers have been started.
	// This allows Start() to be called multiple times safely.
	startedInformers map[reflect.Type]bool
}
```

## 具体资源组

```
路径:serving/pkg/client/informers/externalversions/serving/interface.go

例如: serving资源组

// Interface provides access to each of this group's versions.
type Interface interface {
	// V1alpha1 provides access to shared informers for resources in V1alpha1.
	V1alpha1() v1alpha1.Interface
	// V1beta1 provides access to shared informers for resources in V1beta1.
	V1beta1() v1beta1.Interface
	// V1 provides access to shared informers for resources in V1.
	V1() v1.Interface
}

type group struct {
	factory          internalinterfaces.SharedInformerFactory
	namespace        string
	tweakListOptions internalinterfaces.TweakListOptionsFunc
}
```

## 具体资源组下面的具体版本

```
路径:serving/pkg/client/informers/externalversions/serving/v1/interface.go

例如: serving资源组v1版本

type Interface interface {
	// Configurations returns a ConfigurationInformer.
	Configurations() ConfigurationInformer
	// Revisions returns a RevisionInformer.
	Revisions() RevisionInformer
	// Routes returns a RouteInformer.
	Routes() RouteInformer
	// Services returns a ServiceInformer.
	Services() ServiceInformer
}

type version struct {
	factory          internalinterfaces.SharedInformerFactory
	namespace        string
	tweakListOptions internalinterfaces.TweakListOptionsFunc
}
```

## 具体资源组下面的具体版本的具体资源
```
路径:serving/pkg/client/informers/externalversions/serving/v1/service.go

例如: serving资源组v1版本下的service资源

type ServiceInformer interface {
	Informer() cache.SharedIndexInformer
	Lister() v1.ServiceLister
}

type serviceInformer struct {
	factory          internalinterfaces.SharedInformerFactory
	tweakListOptions internalinterfaces.TweakListOptionsFunc
	namespace        string
}
```