# Master Handler功能解析

## Data Struct

```
serving/pkg/activator/handler/handler.go

// activationHandler will wait for an active endpoint for a revision
// to be available before proxing the request
type activationHandler struct {
	logger    *zap.SugaredLogger
	transport http.RoundTripper
	reporter  activator.StatsReporter
	throttler Throttler

	revisionLister servinglisters.RevisionLister
}
```

## 处理流程

```
serving/pkg/activator/handler/handler.go

// The default time we'll try to probe the revision for activation.
const defaulTimeout = 2 * time.Minute

// New constructs a new http.Handler that deals with revision activation.
func New(ctx context.Context, t Throttler, sr activator.StatsReporter) http.Handler {
	return &activationHandler{
		logger:         logging.FromContext(ctx),
		transport:      pkgnet.AutoTransport,
		reporter:       sr,
		throttler:      t,
		revisionLister: revisioninformer.Get(ctx).Lister(),
	}
}

func (a *activationHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    // 从Header里面获取Revision的Namespace和Name
	namespace := pkghttp.LastHeaderValue(r.Header, activator.RevisionHeaderNamespace)
	name := pkghttp.LastHeaderValue(r.Header, activator.RevisionHeaderName)
	revID := types.NamespacedName{Namespace: namespace, Name: name}
	logger := a.logger.With(zap.String(logkey.Key, revID.String()))

    // 获取Revision资源
	revision, err := a.revisionLister.Revisions(namespace).Get(name)
	if err != nil {
		logger.Errorw("Error while getting revision", zap.Error(err))
		sendError(err, w)
		return
	}

    // 超时事件设置为2分钟
	tryContext, trySpan := trace.StartSpan(r.Context(), "throttler_try")
	tryContext, cancel := context.WithTimeout(tryContext, defaulTimeout)
	defer cancel()

    // 尝试去执行请求
	err = a.throttler.Try(tryContext, revID, func(dest string) error {
		trySpan.End()

		var httpStatus int
		target := url.URL{
			Scheme: "http",
			Host:   dest,
		}

		proxyCtx, proxySpan := trace.StartSpan(r.Context(), "proxy")
		httpStatus = a.proxyRequest(logger, w, r.WithContext(proxyCtx), &target)
		proxySpan.End()

		configurationName := revision.Labels[serving.ConfigurationLabelKey]
		serviceName := revision.Labels[serving.ServiceLabelKey]
		// Do not report response time here. It is reported in pkg/activator/metric_handler.go to
		// sum up all time spent on multiple handlers.
		a.reporter.ReportRequestCount(namespace, serviceName, configurationName, name, httpStatus, 1)

		return nil
	})
	if err != nil {
		// Set error on our capacity waiting span and end it
		trySpan.Annotate([]trace.Attribute{
			trace.StringAttribute("activator.throttler.error", err.Error()),
		}, "ThrottlerTry")
		trySpan.End()

		logger.Errorw("Throttler try error", zap.Error(err))

		switch err {
		case activatornet.ErrActivatorOverload, context.DeadlineExceeded, queue.ErrRequestQueueFull:
			http.Error(w, err.Error(), http.StatusServiceUnavailable)
		default:
			w.WriteHeader(http.StatusInternalServerError)
		}
	}
}

func (a *activationHandler) proxyRequest(logger *zap.SugaredLogger, w http.ResponseWriter, r *http.Request, target *url.URL) int {
	network.RewriteHostIn(r)

	// Setup the reverse proxy.
	proxy := httputil.NewSingleHostReverseProxy(target)
	proxy.Transport = a.transport
	if config := activatorconfig.FromContext(r.Context()); config.Tracing.Backend != tracingconfig.None {
		// When we collect metrics, we're wrapping the RoundTripper
		// the proxy would use inside an annotating transport.
		proxy.Transport = &ochttp.Transport{
			Base: a.transport,
		}
	}
	proxy.FlushInterval = -1
	proxy.ErrorHandler = pkgnet.ErrorHandler(logger)

	r.Header.Set(network.ProxyHeaderName, activator.Name)

	util.SetupHeaderPruning(proxy)

	recorder := pkghttp.NewResponseRecorder(w, http.StatusOK)
	proxy.ServeHTTP(recorder, r)
	return recorder.ResponseCode
}

func sendError(err error, w http.ResponseWriter) {
	msg := fmt.Sprintf("Error getting active endpoint: %v", err)
	if k8serrors.IsNotFound(err) {
		http.Error(w, msg, http.StatusNotFound)
		return
	}
	http.Error(w, msg, http.StatusInternalServerError)
}
```