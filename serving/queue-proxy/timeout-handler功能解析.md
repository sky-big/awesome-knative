# Timeout Handler功能解析

```
serving/pkg/queue/timeout.go

// 数据结构
type timeoutHandler struct {
	handler http.Handler            // 后续需要执行的handler
	body    string                  // 超时显示信息
	dt      time.Duration           // 超时时间
}

func (h *timeoutHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	ctx, cancelCtx := context.WithCancel(r.Context())
	defer cancelCtx()

	done := make(chan struct{})
	// The recovery value of a panic is written to this channel to be
	// propagated (panicked with) again.
	panicChan := make(chan interface{})
	defer close(panicChan)

	tw := &timeoutWriter{w: w}
	go func() {
		// The defer statements are executed in LIFO order,
		// so recover will execute first, then only, the channel will be closed.
		defer close(done)
		defer func() {
			if p := recover(); p != nil {
				panicChan <- p
			}
		}()
		h.handler.ServeHTTP(tw, r.WithContext(ctx))
	}()

	timeout := time.NewTimer(h.dt)
	defer timeout.Stop()
	for {
		select {
		case p := <-panicChan:
			panic(p)
		case <-done:
			return
		case <-timeout.C:
			if tw.TimeoutAndWriteError(h.body) {
				return
			}
		}
	}
}
```