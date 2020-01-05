# Stats Server功能解析

1. 监听8080端口，启动Websocket服务

2. Activator服务会向该Websocket服务发送Pod里面执行统计数据

## 接收的数据结构

```
serving/pkg/autoscaler/collector.go

// StatMessage wraps a Stat with identifying information so it can be routed
// to the correct receiver.
type StatMessage struct {
	Key  types.NamespacedName
	Stat Stat
}

// Stat defines a single measurement at a point in time
type Stat struct {
	// The time the data point was received by autoscaler.
	Time time.Time

	// The unique identity of this pod.  Used to count how many pods
	// are contributing to the metrics.
	PodName string

	// Average number of requests currently being handled by this pod.
	AverageConcurrentRequests float64

	// Part of AverageConcurrentRequests, for requests going through a proxy.
	AverageProxiedConcurrentRequests float64

	// Number of requests received since last Stat (approximately requests per second).
	RequestCount float64

	// Part of RequestCount, for requests going through a proxy.
	ProxiedRequestCount float64
}
```

## 监听接收数据

```
serving/pkg/autoscaler/statserver/server.go

// Handler exposes a websocket handler for receiving stats from queue
// sidecar containers.
func (s *Server) Handler(w http.ResponseWriter, r *http.Request) {
	s.logger.Debug("Handle entered")
	if handleHealthz(w, r) {
		return
	}
	var upgrader websocket.Upgrader
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		s.logger.Errorw("error upgrading websocket", zap.Error(err))
		return
	}

	handlerCh := make(chan struct{})

	s.openClients.Add(1)
	go func() {
		defer s.openClients.Done()
		select {
		case <-s.stopCh:
			// Send a close message to tell the client to immediately reconnect
			s.logger.Debug("Sending close message to client")
			err := conn.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(closeCodeServiceRestart, "Restarting"))
			if err != nil {
				s.logger.Errorf("Failed to send close message to client: %#v", err)
			}
			conn.Close()
		case <-handlerCh:
			s.logger.Debug("Handler exit complete")
		}
	}()

	s.logger.Debug("Connection upgraded to WebSocket. Entering receive loop.")

	for {
		messageType, msg, err := conn.ReadMessage()
		if err != nil {
			// We close abnormally, because we're just closing the connection in the client,
			// which is okay. There's no value delaying closure of the connection unnecessarily.
			if websocket.IsCloseError(err, websocket.CloseAbnormalClosure) {
				s.logger.Debug("Handler disconnected")
			} else {
				s.logger.Errorf("Handler exiting on error: %#v", err)
			}
			close(handlerCh)
			return
		}
		if messageType != websocket.BinaryMessage {
			s.logger.Error("Dropping non-binary message.")
			continue
		}
		dec := gob.NewDecoder(bytes.NewBuffer(msg))
		var sm autoscaler.StatMessage
		err = dec.Decode(&sm)
		if err != nil {
			s.logger.Error(err)
			continue
		}
		sm.Stat.Time = time.Now()

		s.logger.Debugf("Received stat message: %+v", sm)
		s.statsCh <- sm
	}
}
```