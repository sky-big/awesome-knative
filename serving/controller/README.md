# Controller服务代码解析

## service-controller

```
1. 创建Configuration和Route资源
2. Service更新Template,则Controller会同时更新Configuration资源, 然后Configuration Controller创建新版本Revision资源
```

具体参考[Serving-Controller](service-controller/service-controller功能解析.md)

## configuration-controller

```
1. 根据Configuration资源的Spec定义创建Revision资源
```

具体参考[configuration-controller](configuration-controller/configuration-controller功能解析.md)

## labeler-controller

具体参考[labeler-controller](labeler-controller/labeler-controller功能解析.md)

## revision-controller

具体参考[revision-controller](revision-controller/revision-controller功能解析.md)

## route-controller

具体参考[route-controller](route-controller/route-controller功能解析.md)

## serverlessservice-controller

具体参考[serverlessservice-controller](serverlessservice-controller/serverlessservice-controller功能解析.md)

## gc-controller

具体参考[gc-controller](gc-controller/gc-controller功能解析.md)