# Knative Serving

## client(client目录)

该目录下的代码是通过kubernetes的代码生成框架生成的serving服务相关CRD资源的SDK

## queue(queue目录)

1. 该目录为用户容器的SideCar,为每个用户的POD注入的QUEUE代理容器(queue-proxy)

2. 该服务是用来上报metric数据给autoscaler服务来进行扩缩容
