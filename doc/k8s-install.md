# centos安装k8s

## 名词解释

* `kubelet`  在pord上允许负责将`kube-apiserver`下发的指令交给docker执行，如果docker没有起来会拉起
* `kube-proxy` 提供服务发现和负载
* `kubeadm` 安装k8s工具
* `kubectl` 操作k8s客户端工具
* `etcd` 可以理解为数据库，保存集群状态数据
* `apiserver` 提供资源操作入口、授权、访问控制、api注册和发现
* `scheduler` 资源调度器按照调度策略将pod调度到对应的机器上
* `controller manager` 负责维护集群状态，比如滚动更新、故障检测、自动扩展、副本数
* `coredns` 为集群中的server提供域名ip对应解析关系的，可以了解为dns
* `dashboard` 提供b/s结构访问
* `ingress controller` 提供七层代理，可以根据域名或者主机名称负载
* `federation` 可以管理多个k8s集群
* `prometheus` 提供k8s的监控能力

## 基础设置

* 设置镜像源为阿里云

  ```shell
  sudo sh -c 'cat <<EOF > /etc/yum.repos.d/kubernetes.repo
  [kubernetes]
  name=Kubernetes
  baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
  enabled=1
  gpgcheck=0
  repo_gpgcheck=0
  gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
         http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
  EOF'
  ```

* 时间同步

  ```shell
  sudo yum install -y ntp && sudo systemctl start ntpd && sudo systemctl enable ntpd
  ```

* 关闭网络防火墙（不关闭可以放开对应的端口）

  ```shell
  sudo systemctl stop firewalld && sudo systemctl disable firewalld
  ```

* 关闭swap

  ```shell
  sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
  ```

* 修改网卡配置文件 `sudo vi /etc/sysctl.conf` 修改完成后执行`sysctl -p`

  ```shell
  net.ipv4.ip_forward=1
  vm.swappiness = 0
  net.bridge.bridge-nf-call-ip6tables = 1
  net.bridge.bridge-nf-call-iptables = 1
  ```
  
* 关闭selinux

  ```sh
  sudo sed -i "s/SELINUX=enforcing/SELINUX=desabled/g" /etc/selinux/config
  ```

* hosts配置 `sudo vi /etc/hosts`

  ```shell
  192.168.56.100 kube-master
  192.168.56.101 kube-node1
  192.168.56.102 kube-node2
  ```

* docker 配置 主要是是替换docker默认的 `cgroup`为`systemd`

  ```shell
  sudo sh -c 'cat <<EOF > /etc/docker/daemon.json
  {
      "registry-mirrors": [
          "https://75lag9v5.mirror.aliyuncs.com"
      ],
      "exec-opts": [
          "native.cgroupdriver=systemd"
      ],
      "log-driver": "json-file",
      "log-opts": {
          "max-size": "10m",
          "max-file": "1"
      }
  }
  EOF'
  ```

## 软件安装

### 全部节点配置

* 全部节点安装

  ```shell
  sudo yum install -y kubelet kubeadm kubectl
  ```

* 设置开机启动`kubelet`

  ```shell
  sudo systemctl enable kubelet
  ```


### master节点

####    初始化

```shell
sudo kubeadm init \
    --apiserver-advertise-address=192.168.56.100 \
    --image-repository registry.aliyuncs.com/google_containers \
    --kubernetes-version v1.17.0 \
    --pod-network-cidr=10.244.0.0/16
```

* `apiserver-advertise-address`： k8s api地址，一般写master节点的ip

* `image-repository` ：镜像仓库地址,默认是`k8s.gcr.io`，可以配置阿里云（`kubeadm config images list` 查看需要的镜像）

* `kubernetes-version`： k8s版本

* `pod-network-cidr` ：pod网络ip范围，由于网络采用[flannel]( https://github.com/coreos/flannel )它默认的网段就是`10.244.0.0/16` 保持一致

#### 安装flannel

* 下载`kube-flannel.yml`文件

  ```shell
  sudo curl -o ~/flannel/kube-flannel.yml --create-dirs https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml && sudo chown -R $(id -u):$(id -g) ~/flannel
  ```

* 网络原因修改`kube-flannel.yml`文件 vi `~/flannel/kube-flannel.yml`全局替换`quay.io`为`quay-mirror.qiniu.com`

  ```shell
  :%s#quay.io#quay-mirror.qiniu.com#g
  ```

### node节点

* 在master节点执行join命令,在node节点上执行即可

  ```shell
  kubeadm token create --print-join-command
  ```


### ~~etcd~~

* 安装

  ```shell
  sudo yum install -y etcd
  ```

* 修改配置 `sudo vi /etc/etcd/etcd.conf`

  ```shell
  #[Member]
  ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379" # 其他docker通信使用的端口
  #[Clustering]
  ETCD_ADVERTISE_CLIENT_URLS="http://192.168.56.100:2379" # 设置为当前机器ip
  ```

* 启动etcd

  ```shell
  sudo systemctl start etcd && sudo systemctl enable etcd
  ```

* 验证

  ```shell
  [vagrant@k8s-master ~]$ etcdctl set test sunny
  sunny
  [vagrant@k8s-master ~]$ etcdctl get test
  sunny
  ```

  