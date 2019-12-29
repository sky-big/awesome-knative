# Queue-Proxy SideCar代码解析

## 通过环境变量解析配置信息

从环境变量解析queue-proxy的配置信息(使用github.com/kelseyhightower/envconfig库)

## 作为健康检查可执行文件

```
当命令行参数 -probe-period 设置为大于等于0之后就表明此次是将queue-proxy作为Pod健康检查可执行文件
```

## 作为SideCar转发用户流量给用户容器

转发的流程会经历多个Handler后成功后才会将用户流量转发给用户容器

1. Probe Handler(serving/pkg/network/probe_handler.go)

(1). 如果请求的Header里面有K-Network-Probe = probe则直接立刻返回200给请求客户端
(2). 如果请求的Header里面没有K-Network-Probe = probe则将该请求继续转给后续的Handler进行处理
```
func (h *handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    // 如果请求的Header里面的K-Network-Probe不等于probe则继续讲请求给后续的Handler进行处理
	if ph := r.Header.Get(ProbeHeaderName); ph != ProbeHeaderValue {
		r.Header.Del(HashHeaderName)
		h.next.ServeHTTP(w, r)
		return
	}

	hh := r.Header.Get(HashHeaderName)
	if hh == "" {
		http.Error(w, fmt.Sprintf("a probe request must contain a non-empty %q header", HashHeaderName), http.StatusBadRequest)
		return
	}

    // 如果是probe探活则立刻通知客户端正常
	w.Header().Set(HashHeaderName, hh)
	w.WriteHeader(200)
}
```

2. Tracing Handler

(1). 用的库是go.opencensus.io/trace

3. Queue-Proxy Push Metric Handler

4. Http Log Handler

5. TimeOut Handler

6. Forwarded Shim Handler

7. Main Handler

8. User Container Metric Handler
