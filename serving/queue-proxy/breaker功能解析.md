# Breaker功能解析

## Breaker结构

1. 数据结构
```
type Breaker struct {
	pendingRequests chan struct{}
	sem             *semaphore
}
```

2. queue-proxy容器获取token然后将请求转发给用户容器
(1). 如果breaker的排队队列已满则立刻返回告诉调用方并发队列已满
(2). 如果用户正常进入到排队队列后，从semaphore里获取token，如果获取成功则执行转发请求，
     否则获取token超时，则返回调用方获取token超时
```
func (b *Breaker) Maybe(ctx context.Context, thunk func()) error {
	select {
	default:
		// Pending request queue is full.  Report failure.
		return ErrRequestQueueFull
	case b.pendingRequests <- struct{}{}:
		// Pending request has capacity.
		// Defer releasing pending request queue.
		defer func() {
			<-b.pendingRequests
		}()

		// Wait for capacity in the active queue.
        // 从semaphore对象获取token
		if err := b.sem.acquire(ctx); err != nil {
			return err
		}
		// Defer releasing capacity in the active.
		// It's safe to ignore the error returned by release since we
		// make sure the semaphore is only manipulated here and acquire
		// + release calls are equally paired.
        // 向semaphore释放token
		defer b.sem.release()

		// Do the thing.
        // 执行转发请求操作
		thunk()
		// Report success
		return nil
	}
}
```

## Semaphore结构

1. 数据结构(serving/pkg/queue/breaker.go)
```
type semaphore struct {
	queue    chan struct{}  // token的channel,增加token向该channel发送数据，减少token从channel里面消费数据
	reducers int            // 缩小空间的时候若queue里的token不足，则将减少的空间存储在此处
	capacity int            // token空间大小
	mux      sync.RWMutex
}
```

2. 更新空间
(1). 空间初始化原始大小后只能从大往小缩小;
(2). 减少空间，如果channel中的token不足的话，先将减少的数字存储在reducers字段中
```
func (s *semaphore) updateCapacity(size int) error {
    // 空间只能缩小
	if size < 0 || size > cap(s.queue) {
		return ErrUpdateCapacity
	}

	s.mux.Lock()
	defer s.mux.Unlock()

	if s.effectiveCapacity() == size {
		return nil
	}

	// Add capacity until we reach size, potentially consuming
	// outstanding reducers first.
    // 增加空间，只会在初始化的时候才会进行增加空间操作
	for s.effectiveCapacity() < size {
		if s.reducers > 0 {
			s.reducers--
		} else {
			select {
			case s.queue <- struct{}{}:
				s.capacity++
			default:
				// This indicates that we're operating close to
				// MaxCapacity and returned more tokens than we
				// acquired.
				return ErrUpdateCapacity
			}
		}
	}

	// Reduce capacity until we reach size, potentially adding
	// new reducers if the queue channel is empty because of
	// requests in-flight.
    // 减少空间，如果channel中的token不足的话，先将减少的数字存储在reducers字段中
	for s.effectiveCapacity() > size {
		select {
		case <-s.queue:
			s.capacity--
		default:
			s.reducers++
		}
	}

	return nil
}
```
