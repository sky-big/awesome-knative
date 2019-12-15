# Knative Serving

## [client](./client)

该目录下的代码是通过kubernetes的代码生成框架生成的serving服务相关CRD资源的SDK

## [queue](queue-proxy/queue-proxy代码解析.md)

1. 该目录为用户容器的SideCar,为每个用户的POD注入的QUEUE代理容器(queue-proxy)

2. 该服务是用来上报metric数据给autoscaler服务来进行扩缩容

3. 该queue-proxy的sidecar的作用:

```
1. 收集Metrics数据给autoscaler服务实现KPA扩缩容策略

2. 访问日志的管理

3. Pod健康检查机制

4. 实现Pod和Activator服务的交互

5. 判断Ingress是否Ready
```

## [controller](controller/controller代码解析.md)
