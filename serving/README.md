# Knative Serving

## Client

该目录下的代码是通过kubernetes的代码生成框架生成的serving服务相关CRD资源的SDK

具体参考[Client](./client)

## Queue

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

具体参考[Queue](./queue-proxy/README.md)

## Controller

```
一. 计算资源
1. 根据Service资源创建Configuration资源
2. 根据Configuration资源创建Revision资源
3. Revision则创建Pod资源

二. 网络资源
1. 根据Service资源创建Route资源
```

具体参考[Controller](./controller/README.md)

```
(1). 
```

## Activator

具体参考[Activator](./activator/README.md)

## AutoScaler-HPA

具体参考[AutoScaler](./autoscaler-hpa/README.md)
