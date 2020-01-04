# Infinite Breaker功能解析

## Data Struct

1. broadcast字段是阻塞channel

2. concurrency字段只有两个值:

```
    (1). 0值: 表示没有空间所有请求阻塞等待broadcast这个channel
    
    (2). 1值: 表示有无穷的空间，会关闭broadcast这个channel，所有阻塞的请求立刻获得向下转发流量的权限
              同时后续的请求直接不阻塞能立刻获取向下转发流量的请求
```

3. infinite: 无穷

```
serving/pkg/activator/net/throttler.go

// infiniteBreaker is basically a short circuit.
// infiniteBreaker provides us capability to send unlimited number
// of requests to the downstream system.
// This is to be used only when the container concurrency is unset
// (i.e. infinity).
// The infiniteBreaker will, though, block the requests when
// downstream capacity is 0.
type infiniteBreaker struct {
	// mu guards `broadcast` channel.
	mu sync.RWMutex

	// broadcast channel is used notify the waiting requests that
	// downstream capacity showed up.
	// When the downstream capacity switches from 0 to 1, the channel is closed.
	// When the downstream capacity disappears, the a new channel is created.
	// Reads/Writes to the `broadcast` must be guarded by `mu`.
	broadcast chan struct{}

	// concurrency in the infinite breaker takes only two values
	// 0 (no downstream capacity) and 1 (infinite downstream capacity).
	// `Maybe` checks this value to determine whether to proxy the request
	// immediately or wait for capacity to appear.
	// `concurrency` should only be manipulated by `sync/atomic` methods.
	concurrency int32

	logger *zap.SugaredLogger
}
```

## 具体功能

```
serving/pkg/activator/net/throttler.go

// newInfiniteBreaker creates an infiniteBreaker
func newInfiniteBreaker(logger *zap.SugaredLogger) *infiniteBreaker {
	return &infiniteBreaker{
		broadcast: make(chan struct{}),
		logger:    logger,
	}
}

// Capacity returns the current capacity of the breaker
func (ib *infiniteBreaker) Capacity() int {
	return int(atomic.LoadInt32(&ib.concurrency))
}

func zeroOrOne(x int) int32 {
	if x == 0 {
		return 0
	}
	return 1
}

// UpdateConcurrency sets the concurrency of the breaker
func (ib *infiniteBreaker) UpdateConcurrency(cc int) error {
	rcc := zeroOrOne(cc)
	// We lock here to make sure two scale up events don't
	// stomp on each other's feet.
	ib.mu.Lock()
	defer ib.mu.Unlock()
	old := atomic.SwapInt32(&ib.concurrency, rcc)

	// Scale up/down event.
	if old != rcc {
		if rcc == 0 {
			// Scaled to 0.
            // 如果concurrency等于0表示此刻没有流量，创建新的broadcast这个channel，所有的用户阻塞等待该channel
			ib.broadcast = make(chan struct{})
		} else {
            // 如果concurrency等于1则将broadcast这个channel关闭掉，让等待的请求能够获得往下执行的权限
			close(ib.broadcast)
		}
	}
	return nil
}

// Maybe executes thunk when capacity is available
func (ib *infiniteBreaker) Maybe(ctx context.Context, thunk func()) error {
	has := ib.Capacity()
	// We're scaled to serve.
    // 如果concurrency等于1表示有无穷的空间，所以立刻获得往下执行的权限
	if has > 0 {
		thunk()
		return nil
	}

	// Make sure we lock to get the channel, to avoid
	// race between Maybe and UpdateConcurrency.
	var ch chan struct{}
	ib.mu.RLock()
	ch = ib.broadcast
	ib.mu.RUnlock()
	select {
	case <-ch:
        // 阻塞等待broadcast这个channel,只有UpdateConcurrency()方法调用的时候讲concurrency更新为1则会关闭该channel
        // 则会能够从该channel获得信号，然后往下执行
		// Scaled up.
		thunk()
		return nil
	case <-ctx.Done():
        // 超时没有获得往下执行的权限
		ib.logger.Infof("Context is closed: %v", ctx.Err())
		return ctx.Err()
	}
}

func (ib *infiniteBreaker) Reserve(context.Context) (func(), bool) { return noop, true }
```