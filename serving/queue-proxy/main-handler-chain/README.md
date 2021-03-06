# Master Handler Chain功能解析

## Handler Chain

转发的流程会经历多个Handler后成功后才会将用户流量转发给用户容器

### Probe Handler(serving/pkg/network/probe_handler.go)

```
(1). 如果请求的Header里面有K-Network-Probe = probe则直接立刻返回200给请求客户端

(2). 如果请求的Header里面没有K-Network-Probe = probe则将该请求继续转给后续的Handler进行处理

(3). 该探活主要是Istio Ingress Controller来判断VritualService是否Ready来进行探活后端的容器是否活着
```

具体功能参考[probe-handler功能解析](./probe-handler功能解析.md)

### Tracing Handler

```
(1). 用的库是go.opencensus.io/trace
```

### Queue-Proxy Push Metric Handler

```
(1). 会上报每个请求从进入queue-proxy到user-app的整体执行时间和次数
```

具体参考[metric-handler功能解析](./metric-handler功能解析.md)

### Http Log Handler

```
(1). 记录每次请求的日志
```

具体参考[log-handler功能解析](./log-handler功能解析.md)

### TimeOut Handler

```
(1). 处理用户请求超时,如果超时报超时给客户端
```

具体参考[timeout-hanler功能解析](./timeout-handler功能解析.md)

### Forwarded Shim Handler

具体参考[forwarded-shim-handler功能解析](./forwarded-shim-handler功能解析.md)

### Main Handler

```
(1). 处理Activator服务的探活

(2). 处理queue-proxy容器的Kubernetes的探活

(3). 发送统计数据给Prometheus Exporter,Prometheus服务来拉取该信息,然后Autoscaling服务根据Prometheus服务的统计信息去做扩缩容策略

(4). 将超过并发上限的请求直接拒绝返回,让客户端继续请求到没有超过并发上限的容器

(5). 最终将流量转发给user-container容器
```

具体参考[master-handler功能解析](./master-handler功能解析.md)

### User Container Metric Handler

```
(1). 会上报每个请求在user-app里面精确的执行时间和具体执行次数
```

具体参考[metric功能解析](metric-handler功能解析.md)

## Health Check

```
(1). 处理Activator服务来的probe请求,用来判断第一个pod是否ready,如果ready就把流量倒过来

(2). 处理queue-proxy容器的kubernetes探活

(3). 上述两种流量过来到queue-proxy容器,queue-proxy容器在将用户配置的user-container的探活配置去探活user-container
```

具体参考[health-check功能解析](./health-check功能解析.md)

## AutoScaling Metric Reporter功能解析

```
(1). 实现Prometheus Exporter服务,端口是9090

(2). AutoScaling服务从Prometheus获取到数据来判断实现扩缩容
```

具体参考[autoscaling-metric-reporter功能解析](./autoscaling-metric-reporter功能解析.md)
