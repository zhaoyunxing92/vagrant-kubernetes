# k8s中的service

 将运行在一组 [Pods](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/) 上的应用程序公开为网络服务的抽象方法.

## 使用

### 定义service

```yaml
kind: Service
apiVersion: v1
metadata:
  name: nginx-service
  labels:
    name: nginx-deployment-svc
spec:
  selector:
    name: nginx-deployment-svc
  type: NodePort # LoadBalancer | ClusterIP | NodePort |ExternalName
  ports:
  - name: nginx-80
    port: 80
    protocol: TCP
    targetPort: 80 # pod 端口
```

### 定义一个deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment-svc
spec:
  replicas: 4
  selector:
    matchLabels:
      name: nginx-deployment-svc #跟service匹配
  revisionHistoryLimit: 3 # 保存旧的副本数，如果设置为0则无法执行回滚
  template:
    metadata:
      labels:
        name: nginx-deployment-svc
    spec:
      containers:
      - name: nginx # 容器名称
        image: nginx:1.15.4 # 容器镜像
        imagePullPolicy: IfNotPresent # 镜像拉去策略 Always、Naver、IfNotPresent（默认）
        ports:
        - containerPort: 80 # 端口
```

## headless Service

有时候不需要负载均衡或不需要，以及单独的`service ip`,这个时候只需要将`spec.type: None`来创建，这类service不会分配ip，并且kube-proxy不会处理，也不会分配负载和路由

```yaml
kind: Service
apiVersion: v1
metadata:
  name:  headless-service
  labels:
    name: headless-svc # 对应上面的
spec:
  selector:
    name:  headless-svc
  clusterIP: "None"  # LoadBalancer | ClusterIP | NodePort
  ports:
  - name:  nginx-80
    port:  80
    protocol: TCP
    targetPort:  80 # pod 端口
```

## cordedns

每次创建一个service会在coredns创建一条对应的关系规则`serviceName+namespaces+.svc.cluster.local`

例如要看nginx某个pod的`resolv.conf`

```shell
[vagrant@kube-master service]$ kubectl exec -it nginx-deployment-svc-757db4bd48-w6tvz -- cat /etc/resolv.conf 
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

使用`dig`查看域名解析

```shell
sudo yum -y install bind-utils
```

```shell
[vagrant@kube-master service]$ dig -t A nginx-svc.default.svc.cluster.local @10.244.0.5

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-9.P2.el7 <<>> -t A nginx-svc.default.svc.cluster.local @10.244.0.5
;; global options: +cmd
;; Got answer:
;; WARNING: .local is reserved for Multicast DNS
;; You are currently testing what happens when an mDNS query is leaked to DNS
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 51107
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;nginx-svc.default.svc.cluster.local. IN	A

;; ANSWER SECTION:
nginx-svc.default.svc.cluster.local. 30	IN A	10.96.54.110

;; Query time: 0 msec
;; SERVER: 10.244.0.5#53(10.244.0.5)
;; WHEN: Thu Jan 02 23:59:20 CST 2020
;; MSG SIZE  rcvd: 115
```

