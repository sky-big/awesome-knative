# Queue-Proxy SideCar功能解析

## Queue Proxy暴露的服务端口

```
8012端口:
    (1). 处理Activator服务探活请求
    
    (2). 处理Kubernetes服务的探活请求
    
    (3). 转发流量给user-container服务
    
8022端口:
    (1). 处理user-container容器退出Kubernetes的PreStop事件,用来保证所有正在处理的请求处理完毕,同时不再接收新的请求
    
9090端口
    (1). Prometheus Exporter服务监听端口,用来让Prometheus服务来该服务主动拉取信息用来判断是否需要进行Atutoscaling
    
9091端口:
    (1). go.opencensus.io Metric信息获取服务
```

## 通过环境变量解析配置信息

从环境变量解析queue-proxy的配置信息(使用github.com/kelseyhightower/envconfig库)

## 作为健康检查可执行文件

```
当命令行参数 -probe-period 设置为大于等于0之后就表明此次是将queue-proxy作为Pod健康检查可执行文件
```

## 作为SideCar转发用户流量给用户容器

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
