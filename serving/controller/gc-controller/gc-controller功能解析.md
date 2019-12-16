# GC Controller功能解析

## Service资源大致定义

```
type Service struct {
	metav1.TypeMeta `json:",inline"`
	// +optional
	metav1.ObjectMeta `json:"metadata,omitempty"`

	// +optional
	Spec ServiceSpec `json:"spec,omitempty"`

	// +optional
	Status ServiceStatus `json:"status,omitempty"`
}

type ServiceSpec struct {
	// ServiceSpec inlines an unrestricted ConfigurationSpec.
	ConfigurationSpec `json:",inline"`

	// ServiceSpec inlines RouteSpec and restricts/defaults its fields
	// via webhook.  In particular, this spec can only reference this
	// Service's configuration and revisions (which also influences
	// defaults).
	RouteSpec `json:",inline"`
}

type ServiceStatus struct {
	duckv1.Status `json:",inline"`

	// In addition to inlining ConfigurationSpec, we also inline the fields
	// specific to ConfigurationStatus.
	ConfigurationStatusFields `json:",inline"`

	// In addition to inlining RouteSpec, we also inline the fields
	// specific to RouteStatus.
	RouteStatusFields `json:",inline"`
}
```

## 创建Configuration资源

```
根据Service资源里的Spec.ConfigurationSpec创建Configuration资源

type ServiceSpec struct {
	// ServiceSpec inlines an unrestricted ConfigurationSpec.
	ConfigurationSpec `json:",inline"`

	// ServiceSpec inlines RouteSpec and restricts/defaults its fields
	// via webhook.  In particular, this spec can only reference this
	// Service's configuration and revisions (which also influences
	// defaults).
	RouteSpec `json:",inline"`
}
```

## 创建Route资源

```
根据Service资源里的Spec.RouteSpec资源创建Route资源

type ServiceSpec struct {
	// ServiceSpec inlines an unrestricted ConfigurationSpec.
	ConfigurationSpec `json:",inline"`

	// ServiceSpec inlines RouteSpec and restricts/defaults its fields
	// via webhook.  In particular, this spec can only reference this
	// Service's configuration and revisions (which also influences
	// defaults).
	RouteSpec `json:",inline"`
}
```

## 更新Service资源的Status字段

```
判断该Service资源下的Route资源是否Ready,如果Ready则更新Service资源的Status为Ready状态
```