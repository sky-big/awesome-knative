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

具体参考[master_handler_chain功能解析](./main-handler-chain/README.md)

## 暴露Metric数据给AutoScaling

具体参考[autoscaling_metric_data功能解析](./autoscaling-metric-data/README.md)
