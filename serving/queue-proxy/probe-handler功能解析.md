# Probe Handler功能解析

## Probe Handler(serving/pkg/network/probe_handler.go)

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
