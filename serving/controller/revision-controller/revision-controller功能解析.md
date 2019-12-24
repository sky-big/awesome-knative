# Revision Controller功能解析

## 解析容器镜像Tag

## 创建Deployment资源

### 插入queue-proxy容器

1. queue-proxy容器的ReadinessProbe检查
```
1. queue-proxy容器的ReadinessProbe执行的是```/ko-app/queue -probe-period 0``

2. 执行的命令就是queue可执行文件,queue一看probe-period的参数是大于等于0就表明自己作为客户端请求queue进程的8012端口去进行probe检查
   (1). Http请求里面Header加入了特殊的键值对(K-Network-Probe=queue)
```

### 组装用户容器

1. 用户容器的ReadinessProbe检查
```
1. revision controller在创建Deployment的时候,将用户在revision资源里设置的ReadinessProbe序列化后通过环境变量传给queue-proxy容器,
   (1). 如果用户没有指定用户的ContainerPort,则ReadinessProbe里面默认请求的是用户容器的8080端口
   (2). Http请求里面加入了特殊的键值对(K-Kubelet-Probe=queue)
   
2. revision controller在创建Deployment的时候,将用户在revision资源里设置的ReadinessProbe的设置清空
```

## 创建容器Image镜像缓存资源

## 创建PodAutoscaler资源