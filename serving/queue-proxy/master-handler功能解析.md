# Master Handler功能解析

(1). 如果是kubelet的探活请求,则立刻将请求让后续的Handler进行处理

(2). 处理Knative的探活

(3). 发送统计信息用来进行autoscaling

(4). 如果breaker里面等待排队的超过最大并发上限则不让将请求转发给用户Container

(5). 将请求转发给用户Container

```
/serving/cmd/queue/main.go

func handler(reqChan chan queue.ReqEvent, breaker *queue.Breaker, handler http.Handler,
	healthState *health.State, prober func() bool, isAggressive bool) func(http.ResponseWriter, *http.Request) {
	return func(w http.ResponseWriter, r *http.Request) {
	    // 如果是kubelet的探活请求,则立刻将请求让后续的Handler进行处理
		if network.IsKubeletProbe(r) {
			handler.ServeHTTP(w, r)
			return
		}

		// TODO: Move probe part to network.NewProbeHandler if possible or another handler.
		if ph := network.KnativeProbeHeader(r); ph != "" {
			handleKnativeProbe(w, r, ph, healthState, prober, isAggressive)
			return
		}

		proxyCtx, proxySpan := trace.StartSpan(r.Context(), "proxy")
		defer proxySpan.End()

		// Metrics for autoscaling.
		in, out := queue.ReqIn, queue.ReqOut
		if activator.Name == network.KnativeProxyHeader(r) {
			in, out = queue.ProxiedIn, queue.ProxiedOut
		}
		reqChan <- queue.ReqEvent{Time: time.Now(), EventType: in}
		defer func() {
			reqChan <- queue.ReqEvent{Time: time.Now(), EventType: out}
		}()
		network.RewriteHostOut(r)

		// Enforce queuing and concurrency limits.
		if breaker != nil {
			if err := breaker.Maybe(r.Context(), func() {
				handler.ServeHTTP(w, r.WithContext(proxyCtx))
			}); err != nil {
				switch err {
				case context.DeadlineExceeded, queue.ErrRequestQueueFull:
					http.Error(w, err.Error(), http.StatusServiceUnavailable)
				default:
					w.WriteHeader(http.StatusInternalServerError)
				}
			}
		} else {
			handler.ServeHTTP(w, r.WithContext(proxyCtx))
		}
	}
}
```