# Controller服务代码解析

## [service-controller](service-controller/service-controller功能解析.md)

```
1. 创建Configuration和Route资源
2. Service更新Template,则Controller会同时更新Configuration资源, 然后Configuration Controller创建新版本Revision资源
```

## [configuration-controller](configuration-controller/configuration-controller功能解析.md)

```
1. 根据Configuration资源的Spec定义创建Revision资源
```

## [labeler-controller](labeler-controller/labeler-controller功能解析.md)

## [revision-controller](revision-controller/revision-controller功能解析.md)

## [route-controller](route-controller/route-controller功能解析.md)

## [serverlessservice-controller](serverlessservice-controller/serverlessservice-controller功能解析.md)

## [gc-controller](gc-controller/gc-controller功能解析.md)