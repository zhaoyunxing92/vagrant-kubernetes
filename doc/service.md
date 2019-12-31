# k8s中的service

 将运行在一组 [Pods](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/) 上的应用程序公开为网络服务的抽象方法。 

## 定义service

```she
kind: Service
apiVersion: v1
metadata:
  name:  nginx-service
  labels:
    name: nginx-deployment-svc
spec:
  selector:
    name:  nginx-deployment-svc
  type:  NodePort # LoadBalancer | ClusterIP | NodePort
  ports:
  - name:  nginx-80
    port:  80
    protocol: TCP
    targetPort:  80 # pod 端口
```

