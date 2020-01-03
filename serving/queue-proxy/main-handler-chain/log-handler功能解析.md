# Log Handler功能解析

(1). 将日志写到Stdout
(2). 日志模板是从configmap config-observability里面获取的
(3). 需要等后续所有的Handler执行完毕之后在写日志,记录请求话费时间

```
func (h *RequestLogHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    // 获取template,如果不存在则不写日志,直接执行后续的Handler
	t := h.getTemplate()
	if t == nil {
		h.handler.ServeHTTP(w, r)
		return
	}

	rr := NewResponseRecorder(w, http.StatusOK)
	startTime := time.Now()

    // 写日志
	defer func() {
		// Filter probe requests for request logs if disabled.
		// 如果是探活请求则不写日志
		if network.IsProbe(r) && !h.enableProbeRequestLog {
			return
		}

		// If ServeHTTP panics, recover, record the failure and panic again.
		err := recover()
		latency := time.Since(startTime).Seconds()
		if err != nil {
			h.write(t, h.inputGetter(r, &RequestLogResponse{
				Code:    http.StatusInternalServerError,
				Latency: latency,
				Size:    0,
			}))
			panic(err)
		} else {
		    // 记录日志
			h.write(t, h.inputGetter(r, &RequestLogResponse{
				Code:    rr.ResponseCode,
				Latency: latency,
				Size:    (int)(rr.ResponseSize),
			}))
		}
	}()

    // 执行后续的Handler
	h.handler.ServeHTTP(rr, r)
}
```