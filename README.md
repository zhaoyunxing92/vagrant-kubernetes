# vagrant-kubernetes

利用vagrant构建本地k8s环境

multi-repo vs mono-repo

## 基本目录说明

* 本项目使用到的全部yaml都在`k8s`目录下

* 网络原因下载不到`flannel`网络插件,所以我保存了`k8s/flannel`目录下，并且在`lin:192`添加了指定网卡

* `windows`是vagrant的目录，也就是k8s容器所在

## pod控制器

### Deployments
[Deployments](https://kubernetes.io/zh/docs/concepts/workloads/controllers/deployment)是提供一个`声明式`更新pod和[ReplicaSet](https://kubernetes.io/zh/docs/concepts/workloads/controllers/replicaset/),你只用编写你要的结果，交给Deployment去实现创建,可以挂起、滚动、回滚应用

> * 声明式编程 ：只给计算机说想要的结果，计算机自己实现
> * 命令式编程：编写执行的步骤交给计算机，计算机按照步骤执行

### ReplicaSet & ReplicationController

ReplicaSet(rs)支持选择器，ReplicationController(rc)不支持，建议使用deployment

### StatefulSets

[StatefulSet](https://kubernetes.io/zh/docs/concepts/workloads/controllers/statefulset)是用来部署有状态的服务的，比如数据库、zookeeper等,它为每个容器维护一个固定的id，不会跟谁调度改变

#### 特点

* 稳定的、唯一的网络标识符。
* 稳定的、持久的存储。
* 有序的、优雅的部署和缩放。
* 有序的、自动的滚动更新。