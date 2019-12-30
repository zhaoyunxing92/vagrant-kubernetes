# Deployments使用

> 主要是对官方的案例实践

### 开始之前检查

* 检查集群组件状态

  ```shell
  kubectl get componentstatuses
  # 简写
  kubectl get cs
  ```

  ```shell
  [vagrant@kube-master nginx]$ kubectl get cs
  NAME                 STATUS    MESSAGE             ERROR
  controller-manager   Healthy   ok                  
  scheduler            Healthy   ok                  
  etcd-0               Healthy   {"health":"true"}   
  [vagrant@kube-master nginx]$ 
  ```

* 检查node节点状态

  ```shell
  kubectl get nodes
  ```

  ```shell
  [vagrant@kube-master nginx]$ kubectl get nodes
  NAME          STATUS   ROLES    AGE    VERSION
  kube-master   Ready    master   5d3h   v1.17.0
  kube-node1    Ready    <none>   5d1h   v1.17.0
  kube-node2    Ready    <none>   5d1h   v1.17.0
  ```

### 创建deployment

```yaml
cat <<EOF > nginx-deploy.yaml
apiVersion: apps/v1
kind: Deployment            # 声明资源角色deployment
metadata:                   # 元数据
  name: nginx-deployment    # 定义pod
  labels:
    app: nginx
spec:
  replicas: 3 # 副本个数
  selector:
    matchLabels:
      app: nginx
  revisionHistoryLimit: 3 # 保存旧的副本数，如果设置为0则无法执行回滚
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx # 容器名称
        image: nginx:1.15.4 # 容器镜像
        imagePullPolicy: ifNotPresent # 镜像拉去策略 Always、Naver、ifNotPresent（默认）
        ports:
        - containerPort: 80 # 端口
EOF
```

#### 启动

```shel
kubectl apply -f nginx-deploy.yaml --record
```

* `record` 可以记录简单的操作日志

#### 查看部署状态

```shell
[vagrant@kube-master ~]$ kubectl rollout status deploy nginx-deploy
deployment "nginx-deploy" successfully rolled out
```

#### 查看运行状态

```shell
[vagrant@kube-master deployment]$ kubectl get deploy -o wide
NAME           READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES         SELECTOR
nginx-deploy   3/3     3            3           16s   nginx        nginx:1.15.4   app=nginx
```

* `name` deploy名称
* `ready` 运行的副本数和总副本数

* `up-to-date` 更新完成副本数
* `available` 可用副本数
* `age` 运行时间

#### 更新部署

```shell
[vagrant@kube-master k8s]$ kubectl set image deploy/nginx-deploy nginx=nginx:1.9.1
deployment.apps/nginx-deploy image updated
```

查看部署状态

```shell
[vagrant@kube-master k8s]$ kubectl rollout status deploy/nginx-deploy
Waiting for deployment "nginx-deploy" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "nginx-deploy" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "nginx-deploy" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "nginx-deploy" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "nginx-deploy" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "nginx-deploy" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "nginx-deploy" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "nginx-deploy" rollout to finish: 1 old replicas are pending termination...
deployment "nginx-deploy" successfully rolled out
```

#### 查看历史

```shell
[vagrant@kube-master k8s]$ kubectl rollout history deploy nginx-deploy 
deployment.apps/nginx-deploy 
REVISION  CHANGE-CAUSE
1         kubectl apply --filename=nginx-deploy.yaml --record=true
2         kubectl apply --filename=nginx-deploy.yaml --record=true
```

如果想看具体一个历史版本详情

```shell
[vagrant@kube-master k8s]$ kubectl rollout history deploy/nginx-deploy --revision=2
deployment.apps/nginx-deploy with revision #2
Pod Template:
  Labels:	app=nginx
	pod-template-hash=56f8998dbc
  Annotations:	kubernetes.io/change-cause: kubectl apply --filename=nginx-deploy.yaml --record=true
  Containers:
   nginx:
    Image:	nginx:1.9.1
    Port:	80/TCP
    Host Port:	0/TCP
    Environment:	<none>
    Mounts:	<none>
  Volumes:	<none>
```

#### 回滚到之前版本和指定版本

```shell
[vagrant@kube-master k8s]$ kubectl rollout undo deploy nginx-deploy
deployment.apps/nginx-deploy rolled back
```

> 如果想回滚到指定版本后面可加`--to-revision=1`

#### 扩展部署

```shell
[vagrant@kube-master k8s]$ kubectl scale deployment nginx-deploy --replicas=5
deployment.apps/nginx-deploy scaled
[vagrant@kube-master k8s]$ kubectl get pods
NAME                            READY   STATUS    RESTARTS   AGE
nginx-deploy-67656986d9-27gvh   1/1     Running   0          5m8s
nginx-deploy-67656986d9-6pb7q   1/1     Running   0          5m12s
nginx-deploy-67656986d9-74t7l   1/1     Running   0          5m10s
nginx-deploy-67656986d9-nsb5w   1/1     Running   0          99s
nginx-deploy-67656986d9-z7rcj   1/1     Running   0          99s
```

#### 自动缩放

```shell
[vagrant@kube-master k8s]$ kubectl autoscale deployment nginx-deploy --max=10 --min=3 --cpu-percent=80
horizontalpodautoscaler.autoscaling/nginx-deploy autoscaled
```

> 等cpu到80%时候开始扩，最多10个pod，小于80%开始缩，最小保留3个

#### 暂停和恢复部署

```shel
[vagrant@kube-master k8s]$ kubectl rollout pause deploy nginx-deploy 
deployment.apps/nginx-deploy paused
[vagrant@kube-master k8s]$ kubectl rollout pause deploy nginx-deploy 
deployment.apps/nginx-deploy paused
```

#### 删除

```shell
[vagrant@kube-master k8s]$ kubectl delete deploy nginx-deploy 
deployment.apps "nginx-deploy" deleted
```