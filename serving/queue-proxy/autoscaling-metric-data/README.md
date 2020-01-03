# Autoscaling Metric Reporter功能解析

## Stats Reporter

```
(1). Queue-Proxy Master Handler向Stats Reporter发送每次转发流量的统计信息

(2). Stats Reporter 定时将统计信息计算后发送给Prometheus Reporter
```

具体参考[stats_reporter功能解析](./stats-reporter功能解析.md)

## Prometheus Reporter

```
(1). Prometheus Reporter定时从Stats Reporter获取统计信息

(2). Prometheus Reporter实现Prometheus Exporter, 暴露端口9090

(3). Prometheus Server定时来获取统计信息
```

具体参考[prometheus-reporter功能解析](./prometheus-reporter功能解析.md)