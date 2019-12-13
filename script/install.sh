#!/usr/bin/env bash
# change time zone
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
timedatectl set-timezone Asia/Shanghai

# using socat to port forward in helm tiller
# install  wget ntp
sudo yum install -y wget ntp
kubernetes_release="/vagrant/kubernetes.tar.gz"
# Download Kubernetes
if [[ ! -f "$kubernetes_release" ]]; then
    wget https://github.com/kubernetes/kubernetes/releases/download/v1.16.4/kubernetes.tar.gz -P /vagrant/
fi

# enable ntp to sync time
echo 'sync time'
systemctl start ntpd
systemctl enable ntpd
echo 'disable selinux'
setenforce 0
sed -i 's/=enforcing/=disabled/g' /etc/selinux/config

echo 'enable iptable kernel parameter'
cat >> /etc/sysctl.conf <<EOF
net.ipv4.ip_forward=1
EOF
sysctl -p

echo 'set nameserver'
echo "nameserver 8.8.8.8">/etc/resolv.conf
cat /etc/resolv.conf

echo 'disable swap'
swapoff -a
sed -i '/swap/s/^/#/' /etc/fstab

#create group if not exists
egrep "^docker" /etc/group >& /dev/null
if [ $? -ne 0 ]
then
  groupadd docker
fi


# install docker
echo 'install docker'

sudo yum remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine

sudo yum install -y yum-utils device-mapper-persistent-data lvm2

sudo yum install docker-ce docker-ce-cli containerd.io  

sudo usermod -aG docker $USER

newgrp docker

cat > /etc/docker/daemon.json <<EOF
{
  "stry-mirrors":["https://75lag9v5.mirror.aliyuncs.com"]
}
EOF

sudo systemctl enable docker

sudo systemctl daemon-reload

sudo systemctl restart docker

if [[ $1 -eq 1 ]]
then
    yum install -y etcd
cat > /etc/etcd/etcd.conf <<EOF
#[Member]
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="http://$2:2380"
ETCD_LISTEN_CLIENT_URLS="http://$2:2379,http://localhost:2379"
ETCD_NAME="node$1"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://$2:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://$2:2379"
ETCD_INITIAL_CLUSTER="$3"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF
    cat /etc/etcd/etcd.conf
    echo 'create network config in etcd'
cat > /etc/etcd/etcd-init.sh<<EOF
#!/bin/bash
etcdctl mkdir /kube-centos/network
etcdctl mk /kube-centos/network/config '{"Network":"172.33.0.0/16","SubnetLen":24,"Backend":{"Type":"host-gw"}}'
EOF
    chmod +x /etc/etcd/etcd-init.sh
    echo 'start etcd...'
    systemctl daemon-reload
    systemctl enable etcd
    systemctl start etcd

    echo 'create kubernetes ip range for flannel on 172.33.0.0/16'
    /etc/etcd/etcd-init.sh
    etcdctl cluster-health
    etcdctl ls /
fi

echo 'install flannel...'
yum install -y flannel

echo 'create flannel config file...'

cat > /etc/sysconfig/flanneld <<EOF
# Flanneld configuration options
FLANNEL_ETCD_ENDPOINTS="http://172.17.8.101:2379"
FLANNEL_ETCD_PREFIX="/kube-centos/network"
FLANNEL_OPTIONS="-iface=eth1"
EOF

echo 'enable flannel with host-gw backend'
rm -rf /run/flannel/
systemctl daemon-reload


echo 'enable docker'
systemctl daemon-reload
systemctl enable docker
systemctl start docker

echo "copy pem, token files"
mkdir -p /etc/kubernetes/ssl
cp /vagrant/pki/* /etc/kubernetes/ssl/
cp /vagrant/conf/token.csv /etc/kubernetes/
cp /vagrant/conf/bootstrap.kubeconfig /etc/kubernetes/
cp /vagrant/conf/kube-proxy.kubeconfig /etc/kubernetes/
cp /vagrant/conf/kubelet.kubeconfig /etc/kubernetes/

tar -xzvf /vagrant/kubernetes-server-linux-amd64.tar.gz --no-same-owner -C /vagrant
cp /vagrant/kubernetes/server/bin/* /usr/bin

dos2unix -q /vagrant/systemd/*.service
cp /vagrant/systemd/*.service /usr/lib/systemd/system/
mkdir -p /var/lib/kubelet
mkdir -p ~/.kube
cp /vagrant/conf/admin.kubeconfig ~/.kube/config

if [[ $1 -eq 1 ]]
then
    echo "configure master and node1"

    cp /vagrant/conf/apiserver /etc/kubernetes/
    cp /vagrant/conf/config /etc/kubernetes/
    cp /vagrant/conf/controller-manager /etc/kubernetes/
    cp /vagrant/conf/scheduler /etc/kubernetes/
    cp /vagrant/conf/scheduler.conf /etc/kubernetes/
    cp /vagrant/node1/* /etc/kubernetes/

    systemctl daemon-reload
    systemctl enable kube-apiserver
    systemctl start kube-apiserver

    systemctl enable kube-controller-manager
    systemctl start kube-controller-manager

    systemctl enable kube-scheduler
    systemctl start kube-scheduler

    systemctl enable kubelet
    systemctl start kubelet

    systemctl enable kube-proxy
    systemctl start kube-proxy
fi

if [[ $1 -eq 2 ]]
then
    echo "configure node2"
    cp /vagrant/node2/* /etc/kubernetes/

    systemctl daemon-reload
    systemctl enable kubelet
    systemctl start kubelet
    systemctl enable kube-proxy
    systemctl start kube-proxy
fi

if [[ $1 -eq 3 ]]
then
    echo "configure node3"
    cp /vagrant/node3/* /etc/kubernetes/

    systemctl daemon-reload

    systemctl enable kubelet
    systemctl start kubelet
    systemctl enable kube-proxy
    systemctl start kube-proxy

    echo "deploy coredns"
    cd /vagrant/addon/dns/
    ./dns-deploy.sh -r 10.254.0.0/16 -i 10.254.0.2 |kubectl apply -f -
    cd -

    echo "deploy kubernetes dashboard"
    kubectl apply -f /vagrant/addon/dashboard/kubernetes-dashboard.yaml
    echo "create admin role token"
    kubectl apply -f /vagrant/yaml/admin-role.yaml
    echo "the admin role token is:"
    kubectl -n kube-system describe secret `kubectl -n kube-system get secret|grep admin-token|cut -d " " -f1`|grep "token:"|tr -s " "|cut -d " " -f2
    echo "login to dashboard with the above token"
    echo https://172.17.8.101:`kubectl -n kube-system get svc kubernetes-dashboard -o=jsonpath='{.spec.ports[0].port}'`
    echo "install traefik ingress controller"
    kubectl apply -f /vagrant/addon/traefik-ingress/
fi

echo "Configure Kubectl to autocomplete"
source <(kubectl completion bash) # setup autocomplete in bash into the current shell, bash-completion package should be installed first.
echo "source <(kubectl completion bash)" >> ~/.bashrc # add autocomplete permanently to your bash shell.

