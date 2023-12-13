[![](https://img.shields.io/badge/GreatSQL-官网-orange.svg)](https://greatsql.cn/)
[![](https://img.shields.io/badge/GreatSQL-论坛-brightgreen.svg)](https://greatsql.cn/forum.php)
[![](https://img.shields.io/badge/GreatSQL-博客-brightgreen.svg)](https://greatsql.cn/home.php?mod=space&uid=10&do=blog&view=me&from=space)

# GreatSQL 部署 Kubernetes 操作手册
最后更新：2023-12-30

## 前置条件
---
本文档适用于:
- GreatSQL 8.0.32
- Kubernetes V1.23.6
  -  1.24版本废除Docker
- Docker V20.10.9
  -  Kubernetes 1.23最高兼容20.10版本

> 请严格按照手册指定版本安装部署，避免出现不兼容等情况

全文代码符号介绍：

- `$` 此符号为在命令行窗口中执行

- `greatsql>` 此符号为在GreatSQL数据库中执行

## 关于GreatSQL

---
GreatSQL是适用于金融级应用的国内自主开源数据库，具备高性能、高可靠、高易用性、高安全等多个核心特性，可以作为MySQL或Percona Server的可选替换，用于线上生产环境，且完全免费并兼容MySQL或Percona Server。

GreatSQL具备**高性能、高可靠、高易用性、高安全**等多个核心特性。

## 关于Kubernetes
---
Kubernetes(通常简称为K8s)是一个开源的容器编排平台,用于自动部署、扩缩容和管理容器化的应用程序。随着容器技术的流行,Kubernetes已然成为事实上的容器编排标准。

Kubernetes有助于实现容器化应用的高可用性、扩展性和声明式管理。它提供了诸如服务发现、负载均衡、故障自恢复、自动伸缩等优秀特性。用户可以很方便地部署和管理由微服务构成的分布式系统。

## 优势特性
---
- **高可用性**：Kubernetes可以帮助GreatSQL实现高可用部署,比如通过配置多个副本,做主从复制,实现自动故障转移等。保证服务的持续可用。
- **可扩展性**：通过Kubernetes的弹性伸缩能力,可以根据负载动态调整GreatSQL实例数量,实现资源的合理分配,大大提高扩展性。
- **自动恢复**：当GreatSQL实例出现故障时,Kubernetes会自动重新调度新实例,替换故障实例,实现自动恢复。
- **统一管理**：在Kubernetes上可以将GreatSQL与其他服务一起集中管理,无需单独管理数据库实例。可以通过部署,升级,回滚等操作统一管控。
- **资源隔离**：Kubernetes提供了namespace,限制资源等隔离能力,可以建立GreatSQL实例组,按项目或业务逻辑分配资源。
- **部署方便**：基于Kubernetes原生支持的配置文件,可以通过声明式部署来简化GreatSQL的部署和管理。
- **安全加密**：可以对GreatSQL的连接加密,通过Secret对象来管理密码、证书等安全配置。

## 深入浅出Kubernetes
---
尽管Kubernetes作为容器编排引擎,拥有自动化部署、扩缩容、负载均衡等强大功能,但其本身组件复杂、配置繁多,初学者并不容易上手。因此,在着手运行Kubernetes进行服务部署之前,我们强烈建议首先系统地学习一遍完整的官方文档。
- [Kubernetes官方文档](https://kubernetes.io/zh-cn/docs/home/)

也可以阅读我们的深入浅出Kubernetes系列

- [深入浅出Kubernetes](./GreatSQL-K8S-Docs/README.md)

## 最佳实践
---
- [Kubernetes搭建GreatSQL主从复制（多StatefulSet）]()
- [Kubernetes搭建GreatSQL主从复制（单StatefulSet）]()

## 配置脚本
---
鉴于Kubernetes系统中涉及的资源种类繁多,各种资源对象的字段详细程度差异较大,这给平时的管理监控带来了一定的操作负担。专门编写一份通用的资源查询脚本，将频繁使用的查询命令进行了封装。
- [Kubernetes脚本介绍](./GreatSQL-K8S-Shell/README.md)

## 已知问题和解决方案
---
暂无

## 联系我们
---
扫码关注微信公众号

![输入图片说明](./greatsql-wx.jpg)