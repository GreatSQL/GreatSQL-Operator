# Kubernetes 配置脚本

鉴于Kubernetes中涉及的资源种类繁多,各种资源对象的字段详细程度差异较大,给新入门的同学造成了一定的困扰，也给平时的管理监控带来了一定的操作负担。

为此,专门编写了一些通用的脚本,将频繁使用的查询命令进行了封装，减少在操作过程中浪费的时间。

## 脚本介绍

> 脚本介绍有`危险程度`若危险程度高，请运行时候查看下Shell脚本代码

### 1,k8s_git_api.sh

> 脚本危险程度：⭐

用于获取Kubernetes部署所有在greatsql空间下的资源：

- PV
- PVC
- ConfigMap
- Service
- StatefuSet
- Pod

运行方法：

```bash
$ chmod 755 k8s_git_api.sh
$ sh k8s_git_api.sh
```

### 2,k8s_images_pull.sh

> 脚本危险程度：⭐⭐

用于拉取 Kubernetes 相关的镜像

使用前先执行`$ kubeadm config images list`查看自己集群对应镜像版本号，例如：
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

若版本号和例子不符，请修改`k8s_images_pull.sh`脚本中版本信息

```bash
$ vi k8s_images_pull.sh
images=(
        kube-apiserver:v1.23.17
        kube-controller-manager:v1.23.17
        kube-scheduler:v1.23.17
        kube-proxy:v1.23.17
        pause:3.6
        etcd:3.5.1-0
        coredns:1.8.6
)
```

运行方法：

```bash
$ chmod 755 k8s_images_pull.sh
$ sh k8s_images_pull.sh
```

## 免责声明

因个人水平有限，专栏中难免存在错漏之处，请勿直接复制文档中的命令、方法直接应用于线上生产环境。请读者们务必先充分理解并在测试环境验证通过后方可正式实施，避免造成生产环境的破坏或损害。

## 联系我们
---
扫码关注微信公众号

![输入图片说明](../greatsql-wx.jpg)
