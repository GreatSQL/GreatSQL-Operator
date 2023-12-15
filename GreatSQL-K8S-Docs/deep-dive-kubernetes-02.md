# 第二章 Kubernetes的核心概念
## 一、Kubectl 命令行工具
Kubectl是使用Kubernetes API 与 Kubernetes集群的控制面进行通讯的命令行工具 [点击查看参考网址](Kubernetes.io/docs/reference/generated/kubectl/kubectl-commands)

使用以下语法从终端窗口运行 kubectl 命令：

```bash
$ kubectl [command] [TYPE] [NAME] [flags]
```
其中 command、TYPE、NAME 和 flags 分别是：

- command：指定要对一个或多个资源执行的操作，例如 create、get、describe、delete。

- TYPE：指定资源类型。资源类型不区分大小写， 可以指定单数、复数或缩写形式。例如，以下命令输出相同的结果：

- NAME：指定资源的名称。名称区分大小写。 如果省略名称，则显示所有资源的详细信息。例如：`kubectl get pods`。
  - 在对多个资源执行操作时，你可以按类型和名称指定每个资源，或指定一个或多个文件要对所有类型相同的资源进行分组：
  ```bash
  例子：
  $ kubectl get pod example-pod1 example-pod2
  ```
  - 分别指定多个资源类型：

  ```bash
  例子：
  $ kubectl get pod/example-pod1 replicationcontroller/example-rc1
  ```

- flags： 指定可选的参数。例如，可以使用 -s 或 --server 参数指定 Kubernetes API 服务器的地址和端口。但是要注意从命令行指定的参数会覆盖默认值和任何相应的环境变量

Kubectl中的资源类型及其别名和简单用法如下:

- pods (po) - 容器组,如:`kubectl get po`
- nodes (no) - 节点,如:`kubectl get no`
- services (svc) - 服务,如:`kubectl get svc`
- replicasets (rs) - 副本集,如:`kubectl get rs`
- deployments (deploy) - 部署,如:`kubectl get deploy`
- configmaps (cm) - 配置文件,如:`kubectl get cm`
- secrets - 密钥,如:`kubectl get secrets`
- jobs - 任务,如:`kubectl get jobs`
- cronjobs - 定时任务,如:`kubectl get cronjobs`
- daemonsets (ds) - 守护进程集,如:`kubectl get ds`
- statefulsets - 有状态集,如:`kubectl get statefulsets`
- namespaces (ns) - 命名空间,如:`kubectl get ns`
- events (ev) - 事件,如:`kubectl get ev`
- ingresses (ing) - 入口规则,如:`kubectl get ing`

## 二、YAML 语法

Kubernetes使用yaml文件来描述Kubernetes对象，所以对于yaml语法的了解也是十分重要

- 缩进代表上下级关系
- 重要！！**缩进时不允许使用Tab键，只允许使用空格，通常缩进2个空格**
- `: `键值对，后面必须有空格
- `-`列表，后面必须有空格
- `[ ]`数组
- `#`注释
- `|` 多行文本块
- `---`表示文档的开始，多用于分割多个资源对象

## 三、Pod 控制器

Pod是Kubernetes中最小的调度单元，Pod里面可以定义一个或多个容器，如果在一个Pod中存在多个容器，以便它们可以共享网络和存储资源，并且可以协同工作来完成一个任务。

在Kubernetes中，有很多类型的Pod控制器，每种都有自己的适合的场景，常见的有下面这些：

- ReplicationController：比较原始的Pod控制器，已经被废弃，由ReplicaSet替代
- ReplicaSet：保证副本数量一直维持在期望值，并支持Pod数量扩缩容，镜像版本升级
- Deployment：通过控制ReplicaSet来控制Pod，并支持滚动升级、回退版本
- DaemonSet：在集群中的指定Node上运行且仅运行一个副本，一般用于守护进程类的任务
- Job：它创建出来的Pod只要完成任务就立即退出，不需要重启或重建，用于执行一次性任务
- CronJob：它创建的Pod负责周期性任务控制，不需要持续后台运行
- StatefulSet：管理有状态应用

## 四、Service 服务

使用kubernetes集群运行工作负载时，由于Pod经常处于用后即焚状态，Pod经常被重新生成，因此Pod对应的IP地址也会经常变化，导致无法直接访问Pod提供的服务

Kubernetes中使用了Service来解决这一问题，即在Pod前面使用Service对Pod进行代理，无论Pod怎样变化 ，只要有Label，就可以让Service能够联系上Pod，把PodIP地址添加到Service对应的端点列表（Endpoints）实现对Pod IP跟踪，进而实现通过Service访问Pod目的。

- 通过service为pod客户端提供访问pod方法，即可客户端访问pod入口
- 通过标签动态感知pod IP地址变化等
- 防止pod失联
- 定义访问pod访问策略
- 通过label-selector相关联
- 通过Service实现Pod的负载均衡（TCP/UDP 4层）
- 底层实现由kube-proxy通过userspace、iptables、ipvs三种代理模式

## 五、Volume 卷

知道 Pod 是由容器组成的，当容器宕机或停止之后数据就会随之丢失。这可能会给在容器中运行的应用程序带来了一些问题，例如，当容器崩溃时由 kubelet 重新启动的容器是一个全新的，之前的文件数据都丢失了。对于这种情况我们可以使用 Volume（卷）来解决。

Kubernetes 支持多种类型的卷，一个 Pod 可以同时使用任意数量的卷。

卷的类型有很多，例如 emptyDir、hostPath、NFS、分布式存储（ceph、glasterfs）、云存储（AWS EBS）等，下面就简单介绍几种

### 1、emptyDir

emptyDir 类型卷是在 Pod 分配到 Node 时创建的。顾名思义，它的初始内容为空，并且无须指定宿主机上对应的目录文件，因为这是 Kubernetes 自动分配的一个目录，当 Pod 从 Node 上移除时，emptyDir 中的数据也会被永久删除。

注意容器崩溃不会从节点上移除 Pod，所以 emptyDir 卷中的数据在容器崩溃时是安全的,emptyDir 一些用途：

- 临时空间，例如用于某些应用程序运行时所需的临时目录，且无须永久保留
- 长时间任务的中间过程检查点的临时保存目录，以便能从从崩溃中快速恢复 
- 一个容器需要从另一个容器中获取数据的目录（多容器共享目录〉 

根据你的环境，emptyDir 卷可以存储在支持节点的任何介质上，例如hdd、sdd、网络存储。

### 2、hostPath

hostPath 类型用于挂载宿主机上的文件或目录到 Pod 上。

官方建议是 HostPath 卷存在许多安全风险，最佳做法是尽可能避免使用 HostPath。当必须使用 HostPath 卷时，它的范围应仅限于所需的文件或目录，并以只读方式挂载。而且我们要知道的是在不同的 Node 上具有相同配置（例如从 PodTemplate 创建）的 Pod 可能会因为宿主机上的目录和文件不同而导致对 Volume 上目录和文件的访问结果不一致。

如果要挂载的文件或目录只能由 root 用户写入，那需要在特权容器中以 root 身份运行进程，或者修改主机上的文件权限才能写入 hostPath 卷中。在使用 hostPath 卷时，可以设置 type 字段，支持的类型有以下几种：

|类型|	含义|
|--|--|
||空字符串（默认）是为了向后兼容，这意味着在挂载 hostPath 卷之前不会执行任何检查。|
|DirectoryOrCreate|	如果给定路径中不存在任何内容，则会根据需要在那里创建一个空目录，其权限设置为 0755，与 Kubelet 具有相同的组和所有权。|
|Directory	|给定路径中必须存在目录|
|FileOrCreate|	如果给定路径中不存在任何内容，则会根据需要在那里创建一个空文件，其权限设置为 0644，与 Kubelet 具有相同的组和所有权。|
|File	|文件必须存在于给定路径|
|Socket	|给定路径中必须存在 UNIX 套接字|
|CharDevice	|字符设备必须存在于给定的路径中|
|BlockDevice	|块设备必须存在于给定的路径|

### 3、NFS

NFS 类型卷用于将现有 NFS（网络文件系统）挂载到 Pod 中。当从节点移除 Pod 时，与会擦除的 emptyDir 卷不同，NFS 卷的内容会被保留仅仅只是卸载。这意味着 nfs 卷可以预先填充数据，并且数据可以在 Pod 之间共享，也可以同时被多个 Pod 挂载并进行读写。

可以使用`yum install -y nfs-utils`安装NFS，配置NFS在后续章节会讲解

## 六、Namespace 命名空间

**命名空间(Namespace)**是一种资源隔离机制，将同一集群中的资源划分为相互隔离的组。

命名空间可以在多个用户之间划分集群资源（通过资源配额）。

- 例如我们可以设置**开发、测试、生产**等多个命名空间。

同一命名空间内的资源名称要唯一，但跨命名空间时没有这个要求。

命名空间作用域仅针对带有名字空间的对象，例如 Deployment、Service 等。

这种作用域对集群访问的对象不适用，例如 StorageClass、Node、PersistentVolume 等。

**Kubernetes 会创建四个初始命名空间：**

- `default` 默认的命名空间，不可删除，未指定命名空间的对象都会被分配到default中。
- `kube-system` Kubernetes 系统对象(控制平面和Node组件)所使用的命名空间。
- `kube-public` 自动创建的公共命名空间，所有用户（包括未经过身份验证的用户）都可以读取它。通常我们约定，将整个集群中公用的可见和可读的资源放在这个空间中。
- `kube-node-lease` 租约（Lease）对象使用的命名空间。每个节点都有一个关联的 lease 对象，lease 是一种轻量级资源。lease对象通过发送心跳，检测集群中的每个节点是否发生故障

## 七、ConfigMap 配置管理

工作中，在几乎所有的应用开发中，都会涉及到配置文件的变更，比如服务需要配置GreatSQL相关信息。而业务上线一般要经历开发环境、测试环境、预发布环境只到最终的线上环境，每一个环境一般都需要其独立的配置。如果我们不能很好的管理这些配置文件，运维工作将顿时变的无比的繁琐而且很容易出错。工作中最佳实践是将应用所需的配置信息于程序进行分离，这样可以使得应用程序被更好的复用，如将应用打包为容器镜像后，可以通过环境变量或外挂文件的方式在创建容器时进行配置注入。我们可以使用如nacos这样的配置管理中心，kubernetes自身也提供了自己的一套方案，即ConfigMap，来实现对容器中应用的配置管理。

ConfigMap 是一种 API 对象，用来将非机密性的数据保存到键值对中。使用时，Pod可以将其用作环境变量、命令行参数或者存储卷中的配置文件。ConfigMap 将你的环境配置信息和容器镜像解耦，便于应用配置的修改。

ConfigMap 是一个让你可以存储其他对象所需要使用的配置的 API 对象。 和其他 Kubernetes 对象都有一个 `spec` 不同的是，ConfigMap 使用 `data` 和 `binaryData` 字段。这些字段能够接收键-值对作为其取值。`data` 和 `binaryData` 字段都是可选的。`data` 字段设计用来保存 UTF-8 字符串，而 `binaryData` 则被设计用来保存二进制数据作为 base64 编码的字串。

## 参考资料

- [Docker与Kubernetes容器运维实战](https://baike.baidu.com/item/Docker与Kubernetes容器运维实战/63475077?fr=ge_ala)

## 免责声明

因个人水平有限，专栏中难免存在错漏之处，请勿直接复制文档中的命令、方法直接应用于线上生产环境。请读者们务必先充分理解并在测试环境验证通过后方可正式实施，避免造成生产环境的破坏或损害。

## 联系我们

---
扫码关注微信公众号

![输入图片说明](../greatsql-wx.jpg)
