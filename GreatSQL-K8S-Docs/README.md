# 深入浅出Kubernetes

车水马龙,物换星移。在这信息化时代,技术更新迭代之快,令人目不暇接。而作为IT从业者的我们,更有责任去深入理解技术的本质,不断学习新事物,以便更好地适应时代发展的需要。本系列我们要一起探索的主题是Kubernetes。相信对于许多人来说,这还是一个比较陌生的概念。那么它究竟是什么呢?为何近年来备受关注?本系列文章将带大家初识Kubernetes的魅力。

## 专栏目录
### [第一章 Kubernetes 简介](./deep-dive-kubernetes-01.md)

- 1.什么是 Kubernetes
- 2.为什么要用Kubernetes
- 3.Kubernetes与Docker Compose的比较
- 4.Kubernetes核心概念

### [第二章 Kubernetes的核心资源](./deep-dive-kubernetes-02.md)
- 1.Kubectl 命令行工具
- 2.YAML 语法
- 3.Pod 控制器
- 4.Service 服务
- 5.Volume 卷
- 6.Namespace 命名空间
- 7.ConfigMap 配置管理

### [第三章 安装部署Kubernetes](./deep-dive-kubernetes-03.md)

- 1.环境配置
- 2.安装Docker
- 3.安装Kubernetes组件
- 4.集群初始化
- 5.Node节点加入集群
- 6.检查集群情况
- 7.问题汇总

## [第四章 Kubernetes命令行工具](./deep-dive-kubernetes-04.md)

- 1.Kubectl 用法概述
- 2.Kubectl 子命令
- 3.Kubectl 操作例子

## [第五章 Kubernetes中的Pod](./deep-dive-kubernetes-05.md)

- 1.Pod 简介
- 2.Pod 运行
- 3.GreatSQL-Pod 尝试运行 
- 4.Pod 的几种状态
- 5.Pod 错误原因及排查

## [第六章 Kubernetes中的卷](./deep-dive-kubernetes-06.md)

- 1.卷的简介
- 2.临时卷
- 3.持久卷
- 4.持久卷（PV）和持久卷声明（PVC）
- 5.创建持久卷
- 6.NFS卷

## [第七章 Kubernetes中的服务](./deep-dive-kubernetes-07.md)

- 1.服务的基本概念
- 2.Service 的类型
- 3.Headless Service
- 4.如何选择合适的服务类型

## [第八章 有状态与无状态应用](./deep-dive-kubernetes-08.md)

- 1.有状态与无状态应用的基本概念
- 2.无状态应用
- 3.有状态应用
- 4.有状态与无状态应用区别

## [第九章 Kubernetes中的Deployment](./deep-dive-kubernetes-09.md)
- 1.什么是 Deployment
- 2.Deployment 基本概念
- 3.部署单实例无状态 GreatSQL
- 4.测试GreatSQL Pod

## [第十章 部署多StatefulSet的主从复制](./deep-dive-kubernetes-10.md)
- 1.
- 2.
- 3.
- 4.

## 参考资料、文档

- [Docker与Kubernetes容器运维实战](https://baike.baidu.com/item/Docker与Kubernetes容器运维实战/63475077?fr=ge_ala)

## 免责声明
因个人水平有限，专栏中难免存在错漏之处，请勿直接复制文档中的命令、方法直接应用于线上生产环境。请读者们务必先充分理解并在测试环境验证通过后方可正式实施，避免造成生产环境的破坏或损害。

## 联系我们
---
扫码关注微信公众号

![输入图片说明](../greatsql-wx.jpg)
