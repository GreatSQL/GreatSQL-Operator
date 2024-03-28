
# 第六章 Kubernetes中的卷

## 一、卷的简介

容器中的文件在磁盘上是临时存放的，这给在容器中运行较重要的应用带来一些问题。当容器崩溃或停止时会出现一个问题。此时容器状态未保存，因此在容器生命周期内创建或修改的所有文件都将丢失。

在崩溃期间，Kubelet会以干净的状态重新启动容器。当多个容器在一个 Pod 中运行并且需要共享文件时，会出现另一个问题。 跨所有容器设置和访问共享文件系统具有一定的挑战性。Kubernetes 卷（Volume）这一抽象概念能够解决这两个问题。

在前面搭建Pod的时候就使用的是HostPath卷但是它存在许多安全风险

来介绍一下常见的卷类型：

- 临时卷（Ephemeral Volume）：与Pod一起创建和删除，生命周期和Pod相同
  - emptyDor - 作为缓存或者存储日志
  - configMap（卷类型）、secret（卷类型）、downwardAPI - 给Pod注入数据
- 持久卷（Persistent Volume,PV）：删除Pod后，持久卷不会被删除
  - 本地存储 - hostPath、local
  - 网络存储 - NFS
  - 分布式存储 - Ceph（cephfs文件存储、rbd块存储）
- 投射卷（Projected Volumes）：可以将多个卷映射到同一个目录上

## 二、临时卷
与Pod一起创建和删除，生命周期和Pod相同

- emptyDir - 初始内容为空的本地临时目录
会创建一个初始状态为空的目录，存储空间来自本地的kubelet根目录或内存，通常使用本地临时存储来设置缓存、保存日志等。
- configMap - 为Pod注入配置文件
- secret - 为Pod注入加密数据

## 三、持久卷
删除Pod后，卷不会被删除

- 本地存储
  - hostPath - 节点主机上的目录或文件
  - local - 节点上挂载的本地存储设备（不支持动态创建）
- 网络存储
  - NFS - 网络文件系统（NFS）
- 分布式存储
  - Caph（cephfs文件存储、rbd块存储）

## 四、持久卷（PV）和持久卷声明（PVC）

持久卷是集群中的一块存储，就好像是一块虚拟硬盘。是由管理员事先创建的，或者是使用存储类（Storage Class）根据用户请求来动态创建的，持久卷是属于公共资源，并不是属于某个namespace

持久卷声明表达的是用户对存储的请求，好比是一个申请单，使用资源时候先申请，便于统计，Pod将PVC声明当做存储卷来使用，PVC可以请求指定容量的存储空间和访问模式，PVC对象是带有namespace的

HostPath卷只能单节点的测试使用，当Pod被重新创建的时候，可能会被调度到与原先不同的节点上，导致新的Pod没数据，所以多节点集群使用本地存储，可以使用local卷，创建local类型的持久卷，需要先创建存储类（StorageClass）

简单来说持久卷声明是用户端的行为，因为用户在创建Pod的时候并不知道PV的状态，用户也无需去关心这些内容，只需要在声明中提出申请。此时集群就会自动匹配符合要求的持久卷PV

### 4.1 简单尝试
为了更好理解，这里给大家简单操作下

创建一个local-storage.yaml的文件，写入以下内容
```bash
$ vim /opt/k8s/greatsql/local-storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: Kubernetes.io/aws-ebs
volumeBindingMode: Immediate
```
volumeBindingMode主要有以下几个选项:

- Immediate（默认）:立即绑定,Volume 在 Pod 被调度前就必须被创建和绑定,否则调度会失败。
- WaitForFirstConsumer:延迟绑定,Volume 会在第一个 Pod 请求绑定时被创建和绑定。
- WaitForFirstConsumer:多实例类应用会优先调度,Volume 会在任一 Pod 请求时创建。

local卷不支持动态创建，必须手动创建持久卷(PV)。

创建local类型的持久卷，必须设置nodeAffinity(节点亲和性)。

调度器使用nodeAffinity信息来将使用local卷的 Pod 调度到持久卷所在的节点上，不会出现Pod被调度到别的节点上的情况。

下面是一个使用local卷和nodeAffinity的持久卷示例，追加写入到local-storage.yaml文件并使用---分割

```bash
$ vim /opt/k8s/greatsql/local-storage.yaml
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: example-pv
spec:
  capacity:
    storage: 2Gi # 定义PV的容量
  volumeMode: Filesystem # 卷的模式
  accessModes: # 访问模式
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage # StorageClass的名称,用于PV分类
  local:
    path: /data/storage # 本地存储的挂载路径
  nodeAffinity: # 节点亲和性设置
    required: # 硬性约束
      nodeSelectorTerms: # 节点选择条件的集合
      - matchExpressions: # 基于节点标签的匹配表达式
        - key: kubernetes.io/hostname # 节点标签的键
          operator: In # 匹配运算符,可为In、NotIn等
          values: # 标签值列表
          - node1 # 这里将节点修改为node1，这样就只会调度到node1节点上
```
> path的目录是不会被自动创建的，需要手动创建。请注意是在Node1节点上创建此目录！

```bash
# 请在Node1节点上创建
$ mkdir -p /data/storage
```
接在Master节点上使用`$ kubectl apply -f`命令让配置文件生效
```bash
$ kubectl apply -f /opt/k8s/greatsql/local-storage.yaml
storageclass.storage.k8s.io/local-storage created
persistentvolume/example-pv created
```
创建了local-storage的存储类和example-pv的持久卷

可以使用`$ kubectl get pv`查看持久卷
```bash
$ kubectl get pv
NAME          CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS    REASON   AGE
example-pv    2Gi        RWO            Delete           Available           local-storage            10s
```
现在此PV的状态是Available但是声明CLAIM为空，接下来我们一起创建持久卷声明（PVC）

首先要创建一个pvc.yaml文件

```bash
$ vim /opt/k8s/greatsql/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-pv-claim
spec:
  storageClassName: local-storage # 与PV中的storageClassName一致
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```
Master节点上使用`$ kubectl apply -f`命令让配置文件生效，并`$ kubectl get pvc`查看持久卷声明
```bash
$ kubectl apply -f /opt/k8s/greatsql/pvc.yaml
persistentvolumeclaim/local-pv-claim created
$ kubectl get pvc
NAME             STATUS   VOLUME       CAPACITY   ACCESS MODES   STORAGECLASS    AGE
local-pv-claim   Bound    example-pv   2Gi        RWO            local-storage   15s
```
可以看到目前是处于绑定的状态，绑定的卷为example-pv也就是我们刚刚创的

此时再看一下持久卷，就可以看到STATUS为Bound状态，且声明CLAIM由空变为了local-pv-claim

```bash
$ kubectl get pv
...... STATUS    CLAIM
...... Bound     default/local-pv-claim
```

集群根据用户请求将example-pv自动绑定上了local-pv-claim这个持久卷声明中

在我们的Pod中是指定PVC的，并不指定PV，对Pod而言，PVC就是一个存储卷

所以我们这时候就不需要再使用HostPath了，可以把上篇中的`greatsql-pod.yaml`文件修改一下

```bash
$ vim /opt/k8s/greatsql/greatsql-pod.yaml
   volumes:
    - name : conf-volume
      configMap: 
        name: greatsql-config
    - name: data-volume
      persistentVolumeClaim:
        claimName: local-pv-claim
     # 去除以下部分
     # hostPath:
     #   path: /data/GreatSQL
     #   type: DirectoryOrCreate
```
删掉上篇创建的Pod和ConfigMap重新再创建下
```bash
$ kubectl delete pod greatsql
$ kubectl delete cm greatsql-config
$ kubectl apply -f /opt/k8s/greatsql/greatsql-pod.yaml
```
使用kubectl describe pod greatsql-pod查看Pod的详细信息
```bash
$ kubectl describe po greatsql-pod
data-volume:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  local-pv-claim
    ReadOnly:   false
```
可以看到data-volume数据卷对于一个PVC数据卷名字是local-pv-claim

> 注意：local卷也存在自身的问题，当Pod所在节点上的存储出现故障或者整个节点不可用时，Pod和卷都会失效，仍然会丢失数据，因此最安全的做法还是将数据存储到集群之外的存储或云存储上。

### 4.2 绑定

创建持久卷声明(PVC)之后，集群会查找满足要求的持久卷(PV)，将 PVC 绑定到该 PV上。

PVC与PV之间的绑定是一对一的映射关系，绑定具有排它性，一旦绑定关系建立，该PV无法被其他PVC使用。

PVC可能会匹配到比声明容量大的持久卷，但是不会匹配比声明容量小的持久卷。

例如，即使集群上存在多个50G大小的PV ，他们加起来的容量大于100G，也无法匹配100G大小的 PVC。

找不到满足要求的PV，PVC会无限期地处于未绑定状态(Pending) , 直到出现了满足要求的PV时，PVC才会被绑定。

### 4.3 卷的状态

卷有四种状态，刚创建时

- Available（可用）-- 卷是一个空闲资源，尚未绑定到任何；
被绑定到PVC声明之后

- Bound（已绑定）-- 该卷已经绑定到某个持久卷声明上；
删除PVC声明之后

- Released（已释放）-- 所绑定的声明已被删除，但是资源尚未被集群回收；
如果被集群自动回收失败

- Failed（失败）-- 卷的自动回收操作失败。

此时我们如果删掉GreatSQL的Pod，PV和PVC都不会被删除，需要手动的删除持久卷声明

```bash
$ kubectl delete pod greatsql-pod
pod "greatsql-pod" deleted
$ kubectl get pvc
NAME             STATUS   VOLUME       CAPACITY   ACCESS MODES   STORAGECLASS    AGE
local-pv-claim   Bound    example-pv   2Gi        RWO            local-storage   63m
$ kubectl get pv # pv太长，只截取部分
NAME         CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                    STORAGECLASS 
example-pv   2Gi        RWO            Delete           Bound    default/local-pv-claim   local-storage 
# 下方手动删除pvc
$ kubectl delete pvc local-pv-claim
persistentvolumeclaim "local-pv-claim" deleted
```
再来查看下PV的状态，因为PV是不支持自动回收的，所以状态变为了Failed
```bash
$ kubectl get pv
NAME         CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                    STORAGECLASS 
example-pv   2Gi        RWO            Delete           Failed   default/local-pv-claim   local-storage
```
需要手动的去删除这个持久卷
```bash
$ kubectl delete pv example-pv
```

## 五、创建持久卷

在刚刚的例子中使用的是静态创建PV

- 静态创建

  - 管理员预先手动创建
  - 手动创建麻烦、不够灵活（local卷不支持动态创建，必须手动创建PV）
  - 资源浪费（例如一个PVC可能匹配到比声明容量大的卷）
  - 对自动化工具不够友好
- 动态创建

  - 根据用户请求按需创建持久卷，在用户请求时自动创建
  - 动态创建需要使用存储类（StorageClass）
  - 用户需要在持久卷声明(PVC)中指定存储类来自动创建声明中的卷
  - 如果没有指定存储类，使用集群中默认的存储类

### 5.1 存储类(StorageClass)

一个集群可以存在多个存储类（StorageClass）来创建和管理不同类型的存储。

每个 StorageClass 都有一个制备器（Provisioner），用来决定使用哪个卷插件创建持久卷。 该字段必须指定。

```bash
$ kubectl get sc
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
local-storage   Kubernetes.io/aws-ebs   Delete          Immediate           false                  132m
```
如果是使用的K3S的话，是会有一个自带local-path的存储类(StorageClass)，它支持动态创建基于hostPath或local的持久卷。创建PVC后，会自动创建PV，不需要再去手动的创建PV，删除PVC，PV也会被自动删除
### 5.2 卷绑定模式
volumeBindingMode用于控制什么时候动态创建卷和绑定卷

- Immediate立即创建
  - 创建PVC后，立即创建PV并完成绑定。
- WaitForFirstConsumer 延迟创建
  - 当使用该PVC的 Pod 被创建时，才会自动创建PV并完成绑定

## 六、NFS卷

NFS卷能将NFS网络文件系统挂载到我的Pod中，不像emptyDir那样会在删除Pod的同时也会被删除，NFS卷的内容在删除Pod的时候会被保存，卷只是被卸载，意味着NFS卷可以预先填充数据，并且这些数据可以在Pod之间共享
> 不过NFS卷不适合频繁读写的应用,因为NFS是一种基于TCP/IP传输的网络文件系统协议

### 6.1 部署方式
三台服务器安装NFS服务，提供NFS存储功能
> 注意master、node1、node2都要安装

```bash
$ yum install -y nfs-utils
```

启动NFS并设置开机自启

```bash
$ systemctl start nfs-server
$ systemctl enable nfs-server
```

在mstaer节点上创建三个文件夹，作为数据的存放

```bash
$ mkdir -p /data/nfs/greatsql-master
$ mkdir -p /data/nfs/greatsql-slaver-01
$ mkdir -p /data/nfs/greatsql-slaver-02
```

并写入到`/etc/exports` 文件中，只在主节点上操作
语法格式：共享文件路径 客户机地址（权限）#这里的客户机地址可以是IP,网段，域名,也可以是任意*
```bash
$ cat >> /etc/exports << EOF
/data/nfs/greatsql-master *(rw,sync,no_root_squash)
/data/nfs/greatsql-slaver-01 *(rw,sync,no_root_squash)
/data/nfs/greatsql-slaver-02 *(rw,sync,no_root_squash)
EOF
```
接下来我们可以直接在主服务器上重启NFS服务器

```bash
$ systemctl restart nfs-server
```

执行后我们可以通过这行命令来检查目录是否暴露成功

> 注意在三个节点中都要检查一下

```bash
$ showmount -e 192.168.139.120
Export list for 192.168.139.120:
/data/nfs/greatsql-slaver-02 *
/data/nfs/greatsql-slaver-01 *
/data/nfs/greatsql-master    *
```

到此NFS服务器就已经配置完成了



## 参考资料

- [Docker与Kubernetes容器运维实战](https://baike.baidu.com/item/Docker与Kubernetes容器运维实战/63475077?fr=ge_ala)

## 免责声明

因个人水平有限，专栏中难免存在错漏之处，请勿直接复制文档中的命令、方法直接应用于线上生产环境。请读者们务必先充分理解并在测试环境验证通过后方可正式实施，避免造成生产环境的破坏或损害。

## 联系我们
---
扫码关注微信公众号

![输入图片说明](../greatsql-wx.jpg)
