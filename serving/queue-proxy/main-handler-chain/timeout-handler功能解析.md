# Timeout Handler功能解析

1. 数据结构

```
serving/pkg/queue/timeout.go

// 数据结构
type timeoutHandler struct {
	handler http.Handler            // 后续需要执行的handler
	body    string                  // 超时显示信息
	dt      time.Duration           // 超时时间
}
```

2. Handler
```
func (h *timeoutHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	ctx, cancelCtx := context.WithCancel(r.Context())
	defer cancelCtx()

	done := make(chan struct{})
	// The recovery value of a panic is written to this channel to be
	// propagated (panicked with) again.
	panicChan := make(chan interface{})
	defer close(panicChan)

    // 启动协程处理后续的Handler
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

    // 启动定时器,如果超时
	timeout := time.NewTimer(h.dt)
	defer timeout.Stop()
	for {
		select {
		case p := <-panicChan:
			panic(p)
		case <-done:
			return
		case <-timeout.C:
		    // 超时进行回复超时信息
			if tw.TimeoutAndWriteError(h.body) {
				return
			}
		}
	}
}

// 超时的处理函数
func (tw *timeoutWriter) TimeoutAndWriteError(msg string) bool {
	tw.mu.Lock()
	defer tw.mu.Unlock()

	if !tw.wroteOnce {
		tw.w.WriteHeader(http.StatusServiceUnavailable)
		io.WriteString(tw.w, msg)

		tw.timedOut = true
		return true
	}

	return false
}
```