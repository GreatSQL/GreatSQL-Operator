# Kubernetes 配置文件

鉴于Kubernetes系统的管理主要是通过声明式的Yaml配置文件来实现的,而Yaml作为一种数据序列化格式,对块式内容的语法格式有较为严格的缩进要求。一次简单的缩进错误就可能导致配置失败。

为减少此类低级错误影响,专门建立存放平台相关的所有Kubernetes配置文件。

## 简单体验 - pod

仅作为Kubernetes学习创建GreatSQL数据库的入门操作，此资源清单只包含创建一个`ConfigMap`和一个`Pod`

- [greatsql-pod 资源清单](./greatsql-pod/greatsql-pod.yaml)

使用如下命令，即可快速创建并应用：
```bash
$ kubectl apply -f greatsql-pod.yaml
```
## 部署单实例无状态 - deployment

在学习初期可以用Deployment部署一个单实例无状态GreatSQL作为尝试，此资源清单下包含各创建一个Service、ConfigMap、PersistentVolume、PersistentVolumeClaim、Deployment

使用如下命令，即可快速创建并应用：
```bash
$ kubectl apply -f greatsql-deployment-service.yaml
$ kubectl apply -f greatsql-deployment-configmap.yaml
$ kubectl apply -f greatsql-deployment-pv.yaml
$ kubectl apply -f greatsql-deployment.yaml
```

## 部署主从复制 - 多StatefulSet

## 部署主从复制 - 单StatefulSet

## 免责声明
因个人水平有限，专栏中难免存在错漏之处，请勿直接复制文档中的命令、方法直接应用于线上生产环境。请读者们务必先充分理解并在测试环境验证通过后方可正式实施，避免造成生产环境的破坏或损害。

## 联系我们
---
扫码关注微信公众号

![输入图片说明](../greatsql-wx.jpg)
