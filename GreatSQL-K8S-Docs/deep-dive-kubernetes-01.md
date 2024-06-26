# 第一章 Kubernetes 简介
Kubernetes 是容器技术快速发展的产物。Kubernetes的出现让大量服务器的运维变得便捷、高效起来，它极大地简化了大规模容器集群的部署和管理,提供了诸如服务发现、负载均衡、故障自恢复等重要功能。

## 一、应用部署方式演变

从部署应用程序的方式上，主要经历了三个时代：

1. 传统部署：在早期的互联网，会直接将应用程序部署在物理机上

- 优点：简单，不需要其它技术的参与
- 缺点：不能为应用程序定义资源使用边界，很难合理地分配计算资源，而且程序之间容易产生影响

2. 虚拟化部署：可以在一台物理机上运行多个虚拟机，每个虚拟机都是独立的一个环境

- 优点：程序环境不会相互产生影响，提供了一定程度的安全性
- 缺点：增加了操作系统，浪费了部分资源

3. 容器化部署：与虚拟化类似，但是共享了操作系统

- 优点：可以保证每个容器拥有自己的文件系统、CPU、内存、进程空间等，运行应用程序所需要的资源都被容器包装，并和底层基础架构解耦，容器化的应用程序可以跨云服务商、跨Linux操作系统发行版进行部署
- 缺点：容器故障停机，如何让新容器立即去替补故障机器，并发大时如何做到横向拓展

## 二、什么是Kubernetes
Kubernetes是一套自动化容器运维的开源平台，这些运维操作包括部署、调度和节点集群的扩展。可以把Docker看作是Kubernetes内部使用的低级别的组件，而Kubernetes则是管理Docker容器的工具。

## 三、为什么要用Kubernetes
Kubernetes是一个可自动化部署的，具有可伸缩性的，用于操作应用程序容器的开源平台，使用Kubernetes可以快速、高效的满足用户，Kubernetes具有以下明显优势：
- 自我修复：一旦某一个容器崩溃，能够在 1秒 中左右迅速启动新的容器
- 弹性伸缩：可以根据需要，自动对集群中正在运行的容器数量进行调整
- 服务发现：服务可以通过自动发现的形式找到它所依赖的服务
- 负载均衡：如果一个服务起动了多个容器，能够自动实现请求的负载均衡
- 版本回退：如果发现新发布的程序版本有问题，可以立即回退到原来的版本
- 存储编排：可以根据容器自身的需求自动创建存储卷

> 为什么需要Kubernetes？Kubernetes能做什么？

Kubernetes 能在物理机或虚拟机集群上调度和运行程序容器，而且 Kubernetes 能让开发者斩断联系物理机或虚拟机的“枷锁”，从以主机为中心的架构跃升到以容器为中心的架构。该架构最终提供给开发者诸多内在的优势和便利。Kubernetes 提供了在基础架构上真正的以容器为中心得开发环境

Kubernetes 满足一系列产品内运行程序得普通需求，提供如下一些功能：
- 挂载存储系统
- 检查程序状态
- 复制应用实例
- 负载均衡
- 滚动更新
- 资源监控
- ...

## 四、Kubernetes与Docker Compose的比较
Docker Compose 和 Kubernetes 都具有将它们彼此区分开来的独特功能。Docker Compose 是一个基于 Docker 的单主机容器编排工具而 Kubernetes 是一个跨主机的集群部署工具。

Docker Compose 非常适合在单个主机上创建和管理多容器 Docker 应用程序，而 Kubernetes 非常适合需要高可用性和可扩展性的大规模部署。

## 五、Kubernetes重要概念简介

1. Cluster 集群
在 Kubernetes 中，集群是计算、存储和网络资源的集合。Kubernetes 利用这些基础资源来运行各种应用程序。所以，集群是整个 Kubernetes 容器集群的基础环境。

2. Master 控制节点
Master 控制节点指的是集群的控制节点，在每个 Kubernetes 集群中，都至少要有一个 Master 控制节点来负责整个集群的控制和管理，几乎所有的集群控制命令都是 Master 上执行的，为了实现高可用性，用户可以部署多个 Master 节点，Master 节点可以是物理机，也可以是虚拟机。

3. Node 工作节点
在 Kubernetes 中，除了 Master 节点外，其它都是 Node 节点，整个 Kubernetes 中的所有 Node 节点协同工作，Master节点会根据实际情况将某些负载均衡分配给各个 Node 节点，当某个 Node 节点出现故障的时候，其它Node节点会代替其功能。

4. Pod 最小控制单元
kubernetes 的最小控制单元，容器都是运行在 Pod 中的，一个 Pod 中可以有1个或者多个容器

5. Controller 控制器
通过 Controller 来实现对pod的管理，比如启动 Pod 、停止 Pod、伸缩 Pod 的数量等等

6. Namespace 命名空间
命名空间(Namespace) 是一种资源隔离机制，将同一集群中的资源划分为相互隔离的组。命名空间可以在多个用户之间划分集群资源（通过资源配额）

7. Service 服务入口
Pod 对外服务的统一入口，Service 下面可以维护者同一类的多个 Pod

8. Label 标签
用于对 Pod 进行分类，同一类 Pod 会拥有相同的标签

## 参考资料

- [Docker与Kubernetes容器运维实战](https://baike.baidu.com/item/Docker与Kubernetes容器运维实战/63475077?fr=ge_ala)

## 免责声明
因个人水平有限，专栏中难免存在错漏之处，请勿直接复制文档中的命令、方法直接应用于线上生产环境。请读者们务必先充分理解并在测试环境验证通过后方可正式实施，避免造成生产环境的破坏或损害。

## 联系我们
---
扫码关注微信公众号

![输入图片说明](../greatsql-wx.jpg)
