# AutoScaler功能解析

## Collector

1. 一个Metric CRD资源对应一个Revision的Metric信息收集者,在Collector里面对应一个collector对象

2. Metric资源由KPA控制器创建用来收集对应Revision进行扩缩容的Metric统计信息

3. 给Scaler提供扩缩容的依据数据

```
Metric CRD资源: 由KPA Controller创建, Metric资源对应一个Revsion的扩缩容Metric采集通知

Push收集扩缩容Metric指标

    (1). Activator服务主动PushMetric指标给Autoscaler服务的Collector对象
    
    (2). Activator服务监听端口8080,使用Websocket协议
    
Pull收集扩缩容Metric指标

    (1). Collector对象会给每一个Metric资源启动协程每秒定时从Queue-Proxy的9090端口去获取Metric信息
```

具体参考[collector功能解析](./collector/README.md)

## MultiScaler

1. KPA控制器管理的Decider对象对应MultiScaler对象里面的scaler对象

2. scaler对象会根据Autoscaler服务的里的配置间隔定时计算目前Revision下面Pod的个数

3. 如果Revsion下面的Pod个数跟目前的不一致,则通知KPA控制器去进行扩缩容

具体参考[multi-scaler功能解析](./multi-scaler/README.md)

## KPA Controller

1. 创建Metric资源去收集统计信息

2. 创建Decider资源,通知MultiScaler创建对应的scaler,scaler去定时计算对应Revision下面应该有的Pod个数,如果计算的个数跟目前的个数不同则通知出发KPA控制器Reconcile

```
(1). scaler计算出的期望Pod个数会存储在Decider资源的Status.DesiredScale字段
```

3. 根据Decider资源里面的DesiredScale个数去更新Deployment资源的个数,实现资源的AutoScale

具体参考[kpa-controller功能解析](./controllers/kpa-controller/README.md)

## Metric Controller

1. Metric控制器处理Metric资源的创建删除更新对应到Collector对象里面的collector统计信息收集者

具体参考[metric-controller功能解析](./controllers/metric-controller/README.md)

## Stats Server

1. 启动监听8080的Websocket的服务,用来获取Activator服务发送过来的Revision对应的Metric信息

2. 将收集到的信息发送给Collector对象,实现Revision下面的Pod由 0 -> 1 的实现

具体参考[stats-server功能解析](./stats-server/README.md)