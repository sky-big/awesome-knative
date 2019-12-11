# listeners目录生成代码解析

## 资源组

### 资源组的版本

#### 资源组的版本的具体资源的Listener

```
路径:serving/pkg/client/listers/serving/v1/service.go

例如: service资源

// ServiceLister helps list Services.
type ServiceLister interface {
	// List lists all Services in the indexer.
	List(selector labels.Selector) (ret []*v1.Service, err error)
	// Services returns an object that can list and get Services.
	Services(namespace string) ServiceNamespaceLister
	ServiceListerExpansion
}

// serviceLister implements the ServiceLister interface.
type serviceLister struct {
	indexer cache.Indexer
}

// ServiceNamespaceLister helps list and get Services.
type ServiceNamespaceLister interface {
	// List lists all Services in the indexer for a given namespace.
	List(selector labels.Selector) (ret []*v1.Service, err error)
	// Get retrieves the Service from the indexer for a given namespace and name.
	Get(name string) (*v1.Service, error)
	ServiceNamespaceListerExpansion
}

// serviceNamespaceLister implements the ServiceNamespaceLister
// interface.
type serviceNamespaceLister struct {
	indexer   cache.Indexer
	namespace string
}
```