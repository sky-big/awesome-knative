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
(3). 具体功能参考[probe功能解析](./probe-handler功能解析.md)

2. Tracing Handler

(1). 用的库是go.opencensus.io/trace

3. Queue-Proxy Push Metric Handler

(1). 会上报每个请求从进入queue-proxy到user-app的整体执行时间和次数

(2). 具体参考[metric功能解析](metric-handler功能解析.md)

4. Http Log Handler

5. TimeOut Handler

6. Forwarded Shim Handler

7. Main Handler

8. User Container Metric Handler

(1). 会上报每个请求在user-app里面精确的执行时间和具体执行次数

(2). 具体参考[metric功能解析](metric-handler功能解析.md)
