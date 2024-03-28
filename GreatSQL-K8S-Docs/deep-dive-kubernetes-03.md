# 第三章 安装部署Kubernetes
## 一、环境配置

**整体架构规划**

| 名称       | 版本       | 备注                  |
| :--------- | :--------- | :-------------------- |
| Kubernetes | V1.23.6    | 1.24版本废除Docker    |
| Docker     | V20.10.9   | 1.23最高兼容20.10版本 |
| GreatSQL   | V8.0.32-24 |                       |

> 请不要安装1.24版本以上的 Kubernetes，否则不兼容 Docker

**Kubernetes架构规划**

| HostName | Ip地址          | 操作系统 | 机器最低配置               |
| :------- | :-------------- | :--------- | :------------------------- |
| master   | 192.168.139.120 | Centos 7.6 | 最低2GBROM、CPU2核心及以上 |
| node1    | 192.168.140.102 | Centos 7.6 | 最低2GBROM、CPU2核心及以上 |
| node2    | 192.168.139.104 | Centos 7.6 | 最低2GBROM、CPU2核心及以上 |

**机器最低配置以及基本需求**

- 最低 2GB ROM
- CPU2 核心及以上
- 集群中的所有机器的网络彼此均能相互连接（公网和内网都可以）
- 节点之中不可以有重复的主机名、MAC 地址或 product_uuid

```bash
$ cat /etc/redhat-release
CentOS Linux release 7.6.1810 (Core) 
```

### 1.1 配置Yum源

安装wget

```bash
$ yum install wget
```

进入Yum源目录

```bash
$ cd /etc/yum.repos.d/
```

备份之前Yum源

```bash
$ mkdir repo_bak
$ mv *.repo repo_bak/
```

下载网易与阿里云的源

```bash
$ wget http://mirrors.aliyun.com/repo/Centos-7.repo
$ wget http://mirrors.163.com/.help/CentOS7-Base-163.repo
```

清理并生成新的Yum缓存

```bash
$ yum clean all
$ yum makecache
```

### 1.2 配置防火墙

因为 Kubernetes 和 Docker 在运行的中会产生大量的 iptables 规则，为了不让系统规则跟它们混淆，直接关闭系统的规则

```sql
$ systemctl stop firewalld;systemctl disable firewalld
```

配置 Iptables防火墙 来允许 Linux系统 的数据包转发，配置成 ACCEPT 表示允许所有数据包的转发

```bash
$ iptables -P FORWARD ACCEPT
```

### 1.3 主机名解析

为了方便集群节点间的直接调用，配置一下主机名解析，企业中推荐使用 内部DNS 服务器

```bash
$ vim /etc/hosts
#当添加以下内容时，请根据具体环境情况替换配置信息
192.168.139.120 master
192.168.140.102 node1
192.168.139.104 node2
```

并设置三台台主机的 hostname

```bash
# master节点上操作
$ cat /etc/hostname
master
# node1节点上操作
$ cat /etc/hostname
node1
# node2节点上操作
$ cat /etc/hostname
node2
```

### 1.4 时间同步

因为 Kubernetes 要求在集群中的节点时间必须精准，这里使用 chronyd 服务从网络同步时间

> chronyd 是一个用于时间同步的守护进程，通常用于 Linux 操作系统中，它的主要功能是确保计算机系统的时间保持准确和同步

```bash
$ systemctl start chronyd
$ systemctl enable chronyd
```

### 1.5 禁用SELinux

尽管 SELinux 在很大程度上可以加强 Linux 的安全性，但是会影响 Kubernetes 某些组件的功能，所以需要将其禁用

```bash
$ setenforce 0 ; sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
```

SELinux 的模式有三种：

- enforcing模式：SELinux 完全启用,安全策略会被强制执行
- permissive模式：SELinux 启用但不强制执行策略,只生成警告日志
- disabled模式：完全禁用 SELinux，不加载安全策略，等同于关闭 SELinux

> 此处将 SELinux 修改为 permissive 模式。建议只在特殊情况下使用 disabled，长期关闭 SELinux 会减少系统安全性

### 1.6 禁用Swap分区

Swap分区 指的是虚拟内存分区，它的作用是物理内存使用完，之后将磁盘空间虚拟成内存来使用，启用 Swap设备 会对系统的性能产生非常负面的影响，因此 Kubernetes 要求每个节点都要禁用 Swap设备，但是如果因为某些原因确实不能关闭 Swap分区，就需要在集群安装过程中通过明确的参数进行配置说明

```bash
$ swapoff -a; sed -i 's/^\(.*swap.*\)$/#\1/' /etc/fstab
```

### 1.7 修改内核参数

修改 Linux 的内核参数，在`/etc/sysctl.d/Kubernetes.conf`文件中写入如下配置

> 如果需要的话，可以根据自己的机器情况自行进行相应修改

```bash
$ cat <<EOF > /etc/sysctl.d/Kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1 
net.bridge.bridge-nf-call-arptables = 1
net.core.somaxconn = 32768
vm.swappiness = 0
net.ipv4.tcp_syncookies = 0
net.ipv4.ip_forward = 1
fs.file-max = 1000000
fs.inotify.max_user_watches = 1048576
fs.inotify.max_user_instances = 1024
net.ipv4.conf.all.rp_filter = 1
net.ipv4.neigh.default.gc_thresh1 = 80000
net.ipv4.neigh.default.gc_thresh2 = 90000
net.ipv4.neigh.default.gc_thresh3 = 100000
EOF
```

- net.bridge.bridge-nf-call-ip6tables：为桥接流量开启 iptables 的 IPv6 过滤
- net.bridge.bridge-nf-call-iptables：为桥接流量开启 iptables 的 IPv4 过滤
- net.bridge.bridge-nf-call-arptables：为桥接流量开启 iptables 的 ARP 过滤
- net.core.somaxconn：增大 Linux 服务器端可监听队列的长度,以容纳更多等待连接的网络连接数
- vm.swappiness：设置 Linux 使用 swap 的优先级,设置为0表示最大限度使用物理内存,避免交换到 swap 空间
- net.ipv4.tcp_syncookies：开启 syn cookies 以防止 SYN 攻击
- net.ipv4.ip_forward：开启 IP 转发
- fs.file-max：增大系统的文件打开数的限制
- fs.inotify.max_user_watches：增大 inotify 可监控的文件数
- fs.inotify.max_user_instances：增大单个用户可创建的 inotify in stance 的数量
- net.ipv4.conf.all.rp_filter：反向路径过滤设置
- net.ipv4.neigh.*：调整 ARP 缓存参数

```bash
# 重新加载配置
$ sysctl --system
# 加载网桥过滤模块
$ modprobe br_netfilter
# 查看网桥过滤模块是否加载成功
$ lsmod | grep br_netfilter
br_netfilter           22256  0 
bridge                151336  1 br_netfilter
```

### 1.8 配置ipvs功能

在 Kubernetes 中 Service 有两种带来模型，一种是基于 iptables 的，一种是基于 ipvs 的两者比较的话，ipvs 的性能明显要高一些，但是如果要使用它，需要手动载入 ipvs 模块

安装 ipset 和 ipvsadm

```bash
$ yum install ipset ipvsadm -y
```

添加需要加载的模块写入脚本文件

```bash
$ cat <<EOF> /etc/sysconfig/modules/ipvs.modules
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF
```

为脚本添加执行权限并执行脚本

```bash
$ chmod +x /etc/sysconfig/modules/ipvs.modules
$ /bin/bash /etc/sysconfig/modules/ipvs.modules
```

查看对应的模块是否加载成功

```bash
$ lsmod | grep -e ip_vs -e nf_conntrack_ipv4
ip_vs_sh               12688  0 
ip_vs_wrr              12697  0 
ip_vs_rr               12600  0 
ip_vs                 145497  6 ip_vs_rr,ip_vs_sh,ip_vs_wrr
nf_conntrack_ipv4      15053  2 
nf_defrag_ipv4         12729  1 nf_conntrack_ipv4
nf_conntrack          133095  6 ip_vs,nf_nat,nf_nat_ipv4,xt_conntrack,nf_nat_masquerade_ipv4,nf_conntrack_ipv4
libcrc32c              12644  4 xfs,ip_vs,nf_nat,nf_conntrack
```

## 二、安装Docker

下载 Docker 的 Yum源，并清理生成新的 Yum缓存

```bash
$ wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
$ yum clean all
$ yum makecache
```

查看 Docker 版本列表，建议选择版本20.10.9

```bash
$ yum list docker-ce --showduplicates | sort -r
```

指定`20.10.9-3.el7`版本安装，其中 el7 指的是 CentOS 的版本

> Kubernetes 对 Docker 版本有要求，所以请按照本文中版本安装，若想更改版本，要去查看对应版本信息

```bash
$ yum install -y docker-ce-20.10.9-3.el7 docker-ce-cli-20.10.9-3.el7 containerd.io docker-compose-plugin
```

启动 Docker 并验证版本

```bash
$ systemctl start docker
$ docker --version
Docker version 20.10.9, build c2ea9bc
```

有需要可以设置为开机自启

```bash
$ systemctl enable docker
```

## 三、安装Kubernetes组件

由于 Kubernetes 的镜像在国外，速度比较慢，这里切换成国内的镜像源

编辑`/etc/yum.repos.d/Kubernetes.repo`,添加下面的配置

```bash
$ cat <<EOF> /etc/yum.repos.d/Kubernetes.repo
#refer: https://developer.aliyun.com/mirror/kubernetes?spm=a2c6h.13651102.0.0.3e221b11fHuReF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```

安装 Kubeadm、Kubelet 和 Kubectl

> 建议v1.23即可，请注意大于1.24版本不支持Docker！

```bash
$ yum install --setopt=obsoletes=0 kubeadm-1.23.6 kubelet-1.23.6 kubectl-1.23.6 -y
```

配置 Kubelet 的 cgroup 和 kube-proxy 的模式，优化 Kubelet 和 kube-proxy 在 CentOS 环境下的组件行为，提高稳定性和效率。

```bash
$ vim /etc/sysconfig/kubelet
KUBELET_EXTRA_ARGS=
KUBELET_CGROUP_ARGS="--cgroup-driver=systemd"
KUBE_PROXY_MODE="ipvs"
```

其中 KUBELET_EXTRA_ARGS 是用来指定 Kubelet 的额外命令行参数，暂时不用配置

设置开机自启`$ systemctl enable kubelet`

## 四、集群初始化

> 此操作只在 master 节点上执行即可，请自行修改下方参数

```bash
$ kubeadm init \
 --apiserver-advertise-address=192.168.139.120 \
 --image-repository registry.aliyuncs.com/google_containers \
 --kubernetes-version=v1.23.6 \
 --service-cidr=10.96.0.0/12 \
 --pod-network-cidr=10.244.0.0/16
```
其中，`192.168.139.120` 是master的网络地址，`10.96.0.0/12`和`10.244.0.0/16` 是kubernetes私有地址，一般不需要调整。

如果出现了`Your Kubernetes control-plane has initialized successfully!`表示已经安装成功了

接着按照提示的步骤创建必要文件即可

```bash
$ mkdir -p $HOME/.kube
$ sudo cp -i /etc/Kubernetes/admin.conf $HOME/.kube/config
$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

记得要保留下屏幕输出的内容，例如以下

> 这是要在两个node节点上执行加入集群的命令

```bash
Then you can join any number of worker nodes by running the following on each as root:
kubeadm join 192.168.139.120:6443 --token j32p61.gur3ktnazmmyy1od \
        --discovery-token-ca-cert-hash sha256:c78a7421beeece067e696d09fb488deb77e96c5a63c266bc6ca4de7b25617dbf 
```

创建完成后要看下 Kubelet 的状态

```bash
$ systemctl status kubelet
```

在master节点上执行`$ kubectl get no`查看是否为 `Ready` 状态

```bash
$ kubectl get no
NAME     STATUS   ROLES                  AGE   VERSION
master   Ready    control-plane,master   42d   v1.23.6
```

同时也要查看下组件是否都正常，都是`Runing`即为正常

```bash
$ kubectl get pod -n kube-system
NAME                                       READY   STATUS    RESTARTS        AGE
calico-kube-controllers-74dbdc644f-lt97p   1/1     Running   0               23m
calico-node-gntbk                          1/1     Running   0               23m
calico-node-mqrld                          1/1     Running   0               23m
calico-node-rt9x2                          1/1     Running   0               23m
coredns-6d8c4cb4d-4rl5z                    1/1     Running   0               46s
coredns-6d8c4cb4d-x6q94                    1/1     Running   0               8s
etcd-master                                1/1     Running   4 (9d ago)      9d
kube-apiserver-master                      1/1     Running   5 (9d ago)      9d
kube-controller-manager-master             1/1     Running   6 (9d ago)      9d
kube-proxy-9znd6                           1/1     Running   2 (7h31m ago)   9d
kube-proxy-lq2cb                           1/1     Running   1 (7h31m ago)   9d
kube-proxy-rk5df                           1/1     Running   2 (9d ago)      9d
kube-scheduler-master                      1/1     Running   4 (9d ago)      9d
```

## 五、node节点加入集群

> 以下操作只在 node 节点执行

在初始化完成 master 节点的时候屏幕会输出以下内容

```bash
Then you can join any number of worker nodes by running the following on each as root:
kubeadm join 192.168.139.120:6443 --token j32p61.gur3ktnazmmyy1od \
        --discovery-token-ca-cert-hash sha256:c78a7421beeece067e696d09fb488deb77e96c5a63c266bc6ca4de7b25617dbf 
```

直接在两个 node 节点上执行即可加入集群，如果不小心清空了，请往下查看：[七、已知问题和解决方案](./#七、已知问题和解决方案)。

## 六、检查集群情况

执行`$ kubectl get no`，三个节点已经加入完毕，并且都是Ready状态

```bash
$ kubectl get no
NAME     STATUS   ROLES                  AGE   VERSION
master   Ready    control-plane,master   48m   v1.23.6
node1    Ready    <none>                 14m   v1.23.6
node2    Ready    <none>                 97s   v1.23.6
```

执行`$ kubectl get pods -n kube-system `，检查 Kubernetes 集群的系统 Pod 状态，确保所有系统 Pod 运行正常。

```bash
$ kubectl get pods -n kube-system 
NAME                                       READY   STATUS    RESTARTS        AGE
calico-kube-controllers-74dbdc644f-lt97p   1/1     Running   0               23m
calico-node-gntbk                          1/1     Running   0               23m
calico-node-mqrld                          1/1     Running   0               23m
calico-node-rt9x2                          1/1     Running   0               23m
coredns-6d8c4cb4d-4rl5z                    1/1     Running   0               46s
coredns-6d8c4cb4d-x6q94                    1/1     Running   0               8s
etcd-master                                1/1     Running   4 (9d ago)      9d
kube-apiserver-master                      1/1     Running   5 (9d ago)      9d
kube-controller-manager-master             1/1     Running   6 (9d ago)      9d
kube-proxy-9znd6                           1/1     Running   2 (7h31m ago)   9d
kube-proxy-lq2cb                           1/1     Running   1 (7h31m ago)   9d
kube-proxy-rk5df                           1/1     Running   2 (9d ago)      9d
kube-scheduler-master                      1/1     Running   4 (9d ago)      9d
```

至此，Kubernetes 集群的搭建完成！

## 七、已知问题和解决方案

> 搭建 Kubernetes 集群出现报错请看此章节内容

### 7.1 CRI连接失败

报错内容如下

```bash
[ERROR CRI]: container runtime is not running: output: time="2023-09-27T15:41:39+08:00" level=fatal msg="validate service connection: CRI v1 runtime API is not implemented for endpoint \"unix:///var/run/containerd/containerd.sock\": rpc error: code = Unimplemented desc = unknown service runtime.v1.RuntimeService"
, error: exit status 1
```

由于 CRI(Container Runtime Interface) 运行时出现连接失败导致的，此时我们对 **三个节点** 做如下操作

```bash
$ rm /etc/containerd/config.toml 
$ systemctl restart containerd
```

如果已经是安装的高版本的containerd，比如1.6.x，那查看`/etc/containerd/config.toml`配置文件，是否是CRI接口被disable了，如：disabled_plugins = ["cri"]，关闭后重启containerd服务后再试试

之后master节点执行`reset`，再执行创建集群

```bash
$ kubeadm reset

$ kubeadm init \
 --apiserver-advertise-address=192.168.139.120 \
 --image-repository registry.aliyuncs.com/google_containers \
 --Kubernetes-version=v1.23.6 \
 --service-cidr=10.96.0.0/12 \
 --pod-network-cidr=10.244.0.0/16
```

### 7.2 获取不到Pause镜像

这个问题应该会比较常见，解决方法是使用阿里云源逐个拉取即可，当然这里也提供了一个脚本

注意镜像的版本需要选择你自己的`kubeadm config images list`中的

```bash
$ kubeadm config images list
k8s.gcr.io/kube-apiserver:v1.23.17
k8s.gcr.io/kube-controller-manager:v1.23.17
k8s.gcr.io/kube-scheduler:v1.23.17
k8s.gcr.io/kube-proxy:v1.23.17
k8s.gcr.io/pause:3.6
k8s.gcr.io/etcd:3.5.1-0
k8s.gcr.io/coredns/coredns:v1.8.6
```

可以使用该脚本拉取Docker镜像，并标签修改为所需的前缀，即`k8s.gcr.io/`

- [点击查看 拉取Pause镜像脚本](../GreatSQL-K8S-Shell/k8s_images_pull.sh)
- [所有脚本详情介绍](../GreatSQL-K8S-Shell/README.md)

下载或复制脚本内容到`/usr/local/`目录，授权并运行`k8s_images_pull.sh`脚本

```bash
$ chmod 755 /usr/local/k8s_images_pull.sh
$ /usr/local/k8s_images_pull.sh
```

之后 master节点 先执行`reset`重置安装的 Kubernetes 集群

master节点 再次执行安装

```bash
$ kubeadm init \
 --apiserver-advertise-address=192.168.139.120 \
 --image-repository registry.aliyuncs.com/google_containers \
 --Kubernetes-version=v1.23.6 \
 --service-cidr=10.96.0.0/12 \
 --pod-network-cidr=10.244.0.0/16
```

### 7.3 Docker cgroup驱动问题

报错信息：

```bash
The HTTP call equal to 'curl -sSL http://localhost:10248/healthz' failed with error: Get "http://localhost:10248/healthz": dial tcp [::1]:10248: connect: connection refused.
```

默认情况下Kubernetes cgroup为systemd，我们需要更改Docker cgroup驱动

```bash
# 重置安装的Kubernetes集群
$ kubeadm reset
# 写入信息
$ cat <<EOF> /etc/docker/daemon.json
{
  "registry-mirrors": ["https://b9pmyelo.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
```

重启Docker

```bash
$ systemctl daemon-reload
$ systemctl restart docker
```

**其余两节点也完成下以上操作** 随后master节点执行

```bash
$ kubeadm init \
 --apiserver-advertise-address=192.168.139.120 \
 --image-repository registry.aliyuncs.com/google_containers \
 --Kubernetes-version=v1.23.6 \
 --service-cidr=10.96.0.0/12 \
 --pod-network-cidr=10.244.0.0/16
```

### 7.4 NotReady状态

虽然前面`$ kubeadm init`没报错，但是`$ kubectl get no`发现状态是NotReady

```bash
$ kubectl get no
NAME     STATUS     ROLES                  AGE   VERSION
master   NotReady   control-plane,master   48m   v1.23.6
```

发现有报错查看`$ journalctl -f -u kubelet`报错信息如下

```bash
Sep 28 14:32:59 master kubelet: I0928 14:32:59.728045   19066 cni.go:240] "Unable to update cni config" err="no valid networks found in /etc/cni/net.d"
Sep 28 14:33:00 master kubelet: E0928 14:33:00.243077   19066 kubelet.go:2386] "Container runtime network not ready" networkReady="NetworkReady=false reason:NetworkPluginNotReady message:docker: network plugin is not ready: cni config uninitialized"
```

这是因为`/etc/cni/net.d`中找不到网络

```bash
#创建cni网络相关配置文件：
$ mkdir -p /etc/cni/net.d/
 
$ cat <<EOF> /etc/cni/net.d/10-flannel.conf
{"name":"cbr0","type":"flannel","delegate": {"isDefaultGateway": true}}
EOF

$ mkdir /usr/share/oci-umount/oci-umount.d -p

$ mkdir /run/flannel/

$ cat <<EOF> /run/flannel/subnet.env
FLANNEL_NETWORK=10.244.0.0/16
FLANNEL_SUBNET=10.244.1.0/24
FLANNEL_MTU=1450
FLANNEL_IPMASQ=true
EOF
```

但这样还是没有转为`Ready`的状态

于是我们去`/opt/cni/bin`目录下，结果发现没有 flannel 文件，一般安装网络插件 flannel 后，会自动生成该 flannel 文件

去Github下载 https://github.com/containernetworking/plugins/releases/tag/v0.8.6

> (在1.0.0版本后CNI Plugins中没有flannel)

解压后复制 flannel 文件到`/opt/cni/bin/`目录下，过一会儿节点状态就变为Ready了

```bash
$ kubectl get no
NAME     STATUS   ROLES                  AGE   VERSION
master   Ready    control-plane,master   48m   v1.23.6
```

请在另外两个node节点也操作以上步骤，否则加入集群时也会出现NotReady

接着查看组件状态

```bash
$ kubectl get cs
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE                         ERROR
controller-manager   Healthy   ok                              
scheduler            Healthy   ok                              
etcd-0               Healthy   {"health":"true","reason":""} 
```

组件功能已经都是ok状态，再查看下pods的情况

```bash
$ kubectl get pod -n kube-system
NAME                             READY   STATUS    RESTARTS        AGE
coredns-6d8c4cb4d-97df6          0/1     Running   0               9d
coredns-6d8c4cb4d-jwm84          0/1     Running   0               9d
etcd-master                      1/1     Running   4 (9d ago)      9d
kube-apiserver-master            1/1     Running   5 (9d ago)      9d
kube-controller-manager-master   1/1     Running   6 (9d ago)      9d
kube-proxy-9znd6                 1/1     Running   2 (6h47m ago)   9d
kube-proxy-lq2cb                 1/1     Running   1 (6h47m ago)   9d
kube-proxy-rk5df                 1/1     Running   2 (9d ago)      9d
kube-scheduler-master            1/1     Running   4 (9d ago)      9d
```

其中`coredns-6d8c4cb4d-97df6 `，`coredns-6d8c4cb4d-jwm84`虽然是Running状态，但是READY却是0/1，这出问题的话一般是网络的原因，接着我们部署一下CNI网络插件，先创建存放的目录

```bash
$ cd /opt
$ mkdir k8s
```

下载calico.yaml（因为网站证书过期了，所以我们加入`--no-check-certificate`）：

```bash
$ wget -c https://docs.projectcalico.org/manifests/calico.yaml --no-check-certificate
```

查看下calico.yaml需要下载的镜像

```bash
$ grep image calico.yaml
          image: docker.io/calico/cni:v3.26.1
          imagePullPolicy: IfNotPresent
          image: docker.io/calico/cni:v3.26.1
          imagePullPolicy: IfNotPresent
          image: docker.io/calico/node:v3.26.1
          imagePullPolicy: IfNotPresent
          image: docker.io/calico/node:v3.26.1
          imagePullPolicy: IfNotPresent
          image: docker.io/calico/kube-controllers:v3.26.1
          imagePullPolicy: IfNotPresent
```

修改镜像仓库地址前缀，避免下载过慢

```bash
$ sed -i 's#docker.io/##g' calico.yaml
```

再执行下`$ grep image calico.yaml`

```bash
$ grep image calico.yaml
          image: calico/cni:v3.26.1
          imagePullPolicy: IfNotPresent
          image: calico/cni:v3.26.1
          imagePullPolicy: IfNotPresent
          image: calico/node:v3.26.1
          imagePullPolicy: IfNotPresent
          image: calico/node:v3.26.1
          imagePullPolicy: IfNotPresent
          image: calico/kube-controllers:v3.26.1
          imagePullPolicy: IfNotPresent
```

直接开始构建

```bash
$ kubectl apply -f calico.yaml
```

如果还有 Pod 显示 0/1 状态，使用`kubectl delete pod 名称 -n kube-system`删除 Pod，将重建 Pod，接下来就一切正常了

```bash
$ kubectl get pod -n kube-system
NAME                                       READY   STATUS    RESTARTS        AGE
calico-kube-controllers-74dbdc644f-lt97p   1/1     Running   0               23m
calico-node-gntbk                          1/1     Running   0               23m
calico-node-mqrld                          1/1     Running   0               23m
calico-node-rt9x2                          1/1     Running   0               23m
coredns-6d8c4cb4d-4rl5z                    1/1     Running   0               46s
coredns-6d8c4cb4d-x6q94                    1/1     Running   0               8s
etcd-master                                1/1     Running   4 (9d ago)      9d
kube-apiserver-master                      1/1     Running   5 (9d ago)      9d
kube-controller-manager-master             1/1     Running   6 (9d ago)      9d
kube-proxy-9znd6                           1/1     Running   2 (7h31m ago)   9d
kube-proxy-lq2cb                           1/1     Running   1 (7h31m ago)   9d
kube-proxy-rk5df                           1/1     Running   2 (9d ago)      9d
kube-scheduler-master                      1/1     Running   4 (9d ago)      9d
```

### 7.5 找不到node节点加入master节点命令

node节点 加入集群格式为

```bash
kubeadm join <master节点IP:6443> --token <mster的token> \
    --discovery-token-ca-cert-hash sha256: <mster的hash>
```

**获取Token值**

再初始化 master节点 的时候会出现 token 的信息，如果不小心清空了记录，可以用以下方式获取或者重新申请

```bash
# 获取token
$ kubeadm token list
TOKEN：j32p61.gur3ktnazmmyy1od
TTL：23h
EXPIRES：2023-09-29T02:47:00Z
USAGES：authentication,signing
DESCRIPTION：The default bootstrap token generated by 'kubeadm init'.
EXTRA GROUPS：system:bootstrappers:kubeadm:default-node-token
```

- `OKEN`: token的值,用于认证
- `TTL`: 该token的生命周期,这里是23小时
- `EXPIRES`: token的过期时间,基于生命周期计算得出
- `USAGES`: 此token的用途,这里包含authentication(认证)和signing(签名)
- `DESCRIPTION`: 对该token的说明,这里表示这是一个kubeadm默认创建的bootstrap token
- `EXTRA GROUPS`: 此token所授予的用户组,这里是system:bootstrappers:kubeadm:default-node-token用户组

如果TTL过期了可以重新申请

```bash
$ kbueadm token create
```

**获取--discovery-token-ca-cert-hash**

SSH证书的一个 Hash值，得到该值后需要在后面拼接上sha256

```bash
$ openssl x509 -pubkey -in /etc/Kubernetes/pki/ca.crt | opensslrsa -pubin -outform der 2>/dev/null |\openssl dgst -sha256 -hex | sed 's/^.* //'
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

如果没有openssl，需要安装下

```bash
$ yum install -y openssl
```

再把的得到的结果拼接在一起即可

```bash
$ kubeadm join 192.168.139.120:6443 --token j32p61.gur3ktnazmmyy1od \
        --discovery-token-ca-cert-hash sha256:c78a7421beeece067e696d09fb488deb77e96c5a63c266bc6ca4de7b25617dbf
```

如果Hash值错了会报错如下

```bash
error execution phase preflight: couldn't validate the identity of the API Server: cluster CA found in cluster-info ConfigMap is invalid: none of the public keys "sha256:4c792bb10c52ddcaa78044f97d4d5325a269363b1e51ec85c2829683c1d6c4ef" are pinned
```

那就直接用它提到的`sha256:4c792bb10c52ddcaa78044f97d4d5325a269363b1e51ec85c2829683c1d6c4ef`替换即可

> 注意不要清屏最方便 :）

## 参考资料

- [Docker与Kubernetes容器运维实战](https://baike.baidu.com/item/Docker与Kubernetes容器运维实战/63475077?fr=ge_ala)

## 免责声明

因个人水平有限，专栏中难免存在错漏之处，请勿直接复制文档中的命令、方法直接应用于线上生产环境。请读者们务必先充分理解并在测试环境验证通过后方可正式实施，避免造成生产环境的破坏或损害。

## 联系我们
---
扫码关注微信公众号

![输入图片说明](../greatsql-wx.jpg)
