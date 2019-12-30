# Health Check功能解析

该健康检查主要是queue-proxy和Activator服务进行探活,该探活入口统一收到queue-proxy,queue-proxy再调用用户的探活配置去探活UserContainer是否活着来判断是否健康

## Health

1. 数据结构

```
// serving/pkg/queue/health/health_state.go

type State struct {
	alive        bool               // 是否存活, 如果probe.PeriodSeconds设置的不为0,则一旦probe出现一次Success,则就再也不会去探测user-container
	shuttingDown bool               // 是否关闭
	mutex        sync.RWMutex

	drainCh        chan struct{}
	drainCompleted bool
}
```

2. 处理过程

```
func (h *State) HandleHealthProbe(prober func() bool, isAggressive bool, w http.ResponseWriter) {
	sendAlive := func() {
		io.WriteString(w, aliveBody)
	}

	sendNotAlive := func() {
		w.WriteHeader(http.StatusServiceUnavailable)
		io.WriteString(w, notAliveBody)
	}

	switch {
	// 如果设置啦PeriodSeconds则一旦出现一次Success则再也不会去探测user-container
	case !isAggressive && h.IsAlive():
		sendAlive()
	// 关闭则探活失败
	case h.IsShuttingDown():
		sendNotAlive()
	// 调用prober进行探测(serving/pkg/queue/readiness/probe.go)
	case prober != nil && !prober():
		sendNotAlive()
	// 探测成功或者默认是健康的
	default:
		h.setAlive()
		sendAlive()
	}
}
```

## Probe

1. 数据结构

```
// serving/pkg/queue/readiness/probe.go

type Probe struct {
	*corev1.Probe
	count int32
}
```

2. 处理过程

```
// ProbeContainer executes the defined Probe against the user-container
func (p *Probe) ProbeContainer() bool {
	var err error

	switch {
	case p.HTTPGet != nil:
		err = p.httpProbe()
	case p.TCPSocket != nil:
		err = p.tcpProbe()
	case p.Exec != nil:
		// Should never be reachable. Exec probes to be translated to
		// TCP probes when container is built.
		// Using Fprintf for a concise error message in the event log.
		fmt.Fprintln(os.Stderr, "exec probe not supported")
		return false
	default:
		// Using Fprintf for a concise error message in the event log.
		fmt.Fprintln(os.Stderr, "no probe found")
		return false
	}

	if err != nil {
		// Using Fprintf for a concise error message in the event log.
		fmt.Fprint(os.Stderr, err.Error())
		return false
	}
	return true
}

func (p *Probe) doProbe(probe func(time.Duration) error) error {
	if p.IsAggressive() {
		return wait.PollImmediate(retryInterval, PollTimeout, func() (bool, error) {
			if tcpErr := probe(aggressiveProbeTimeout); tcpErr != nil {
				// reset count of consecutive successes to zero
				p.count = 0
				return false, nil
			}

			p.count++

			// return success if count of consecutive successes is equal to or greater
			// than the probe's SuccessThreshold.
			return p.Count() >= p.SuccessThreshold, nil
		})
	}

	return probe(time.Duration(p.TimeoutSeconds) * time.Second)
}

// tcpProbe function executes TCP probe once if its standard probe
// otherwise TCP probe polls condition function which returns true
// if the probe count is greater than success threshold and false if TCP probe fails
func (p *Probe) tcpProbe() error {
	config := health.TCPProbeConfigOptions{
		Address: p.TCPSocket.Host + ":" + p.TCPSocket.Port.String(),
	}

	return p.doProbe(func(to time.Duration) error {
		config.SocketTimeout = to
		return health.TCPProbe(config)
	})
}

// httpProbe function executes HTTP probe once if its standard probe
// otherwise HTTP probe polls condition function which returns true
// if the probe count is greater than success threshold and false if HTTP probe fails
func (p *Probe) httpProbe() error {
	config := health.HTTPProbeConfigOptions{
		HTTPGetAction: p.HTTPGet,
	}

	return p.doProbe(func(to time.Duration) error {
		config.Timeout = to
		return health.HTTPProbe(config)
	})
}
```

## 实际的执行过程

1. TCP Probe

```
// serving/pkg/queue/health/probe.go

// 判断健康的条件是tcp请求正常返回
func TCPProbe(config TCPProbeConfigOptions) error {
	conn, err := net.DialTimeout("tcp", config.Address, config.SocketTimeout)
	if err != nil {
		return err
	}
	conn.Close()
	return nil
}
```

2. HTTP Probe

```
// serving/pkg/queue/health/probe.go

// HTTPProbe checks that HTTP connection can be established to the address.
func HTTPProbe(config HTTPProbeConfigOptions) error {
	httpClient := &http.Client{
		Transport: &http.Transport{
			DisableKeepAlives: true,
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: true,
			},
		},
		Timeout: config.Timeout,
	}
	url := url.URL{
		Scheme: string(config.Scheme),
		Host:   net.JoinHostPort(config.Host, config.Port.String()),
		Path:   config.Path,
	}
	req, err := http.NewRequest(http.MethodGet, url.String(), nil)
	if err != nil {
		return fmt.Errorf("error constructing probe request %w", err)
	}

	req.Header.Add(network.UserAgentKey, network.KubeProbeUAPrefix+config.KubeMajor+"/"+config.KubeMinor)

	for _, header := range config.HTTPHeaders {
		req.Header.Add(header.Name, header.Value)
	}

	res, err := httpClient.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()

	if !IsHTTPProbeReady(res) {
		return fmt.Errorf("HTTP probe did not respond Ready, got status code: %d", res.StatusCode)
	}

	return nil
}

// 判断http返回是否是正常
// IsHTTPProbeReady checks whether we received a successful Response
func IsHTTPProbeReady(res *http.Response) bool {
	if res == nil {
		return false
	}

	// response status code between 200-399 indicates success
	return res.StatusCode >= 200 && res.StatusCode < 400
}
```