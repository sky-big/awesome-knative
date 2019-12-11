# injection目录生成代码解析

该目录下的作用是:将各种资源的Client,InformerFactory,Informer,Duck对象注入到Contenxt对象中,这样项目代码就能够从Context获取到想要的资源

## Client注入

```
路径:serving/pkg/client/injection/client/client.go

func init() {
	injection.Default.RegisterClient(withClient)
}

// Key is used as the key for associating information with a context.Context.
type Key struct{}

func withClient(ctx context.Context, cfg *rest.Config) context.Context {
	return context.WithValue(ctx, Key{}, versioned.NewForConfigOrDie(cfg))
}

// Get extracts the versioned.Interface client from the context.
func Get(ctx context.Context) versioned.Interface {
	untyped := ctx.Value(Key{})
	if untyped == nil {
		logging.FromContext(ctx).Panic(
			"Unable to fetch knative.dev/serving/pkg/client/clientset/versioned.Interface from context.")
	}
	return untyped.(versioned.Interface)
}
```

## Ducks注入

## Informers注入

### InformerFactory注入

```
路径:serving/pkg/client/injection/informers/factory/factory.go

InformerFactory对象依赖Client对象,需要从Context中获取Client对象

func init() {
	injection.Default.RegisterInformerFactory(withInformerFactory)
}

// Key is used as the key for associating information with a context.Context.
type Key struct{}

func withInformerFactory(ctx context.Context) context.Context {
	c := client.Get(ctx)
	opts := make([]externalversions.SharedInformerOption, 0, 1)
	if injection.HasNamespaceScope(ctx) {
		opts = append(opts, externalversions.WithNamespace(injection.GetNamespaceScope(ctx)))
	}
	return context.WithValue(ctx, Key{},
		externalversions.NewSharedInformerFactoryWithOptions(c, controller.GetResyncPeriod(ctx), opts...))
}

// Get extracts the InformerFactory from the context.
func Get(ctx context.Context) externalversions.SharedInformerFactory {
	untyped := ctx.Value(Key{})
	if untyped == nil {
		logging.FromContext(ctx).Panic(
			"Unable to fetch knative.dev/serving/pkg/client/informers/externalversions.SharedInformerFactory from context.")
	}
	return untyped.(externalversions.SharedInformerFactory)
}
```

### 具体资源的Informers注入

```
路径:serving/pkg/client/injection/informers/serving/v1/service.go

例如: service资源

service资源的Informer依赖于InformerFactory对象,需要从Context中获取InformerFactory对象

func init() {
	injection.Default.RegisterInformer(withInformer)
}

// Key is used for associating the Informer inside the context.Context.
type Key struct{}

func withInformer(ctx context.Context) (context.Context, controller.Informer) {
	f := factory.Get(ctx)
	inf := f.Serving().V1().Services()
	return context.WithValue(ctx, Key{}, inf), inf.Informer()
}

// Get extracts the typed informer from the context.
func Get(ctx context.Context) v1.ServiceInformer {
	untyped := ctx.Value(Key{})
	if untyped == nil {
		logging.FromContext(ctx).Panic(
			"Unable to fetch knative.dev/serving/pkg/client/informers/externalversions/serving/v1.ServiceInformer from context.")
	}
	return untyped.(v1.ServiceInformer)
}
```