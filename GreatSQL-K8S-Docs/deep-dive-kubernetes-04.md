# 第四章 Kubernetes命令行工具
在之前的章节中，我们简要介绍了Kubernetes的命令行工具Kubectl。它是用于管理Kubernetes集群的命令行工具，可以通过Kubectl对集群本身进行管理。

## 一、Kubectl 用法概述

Kubectl通常会在集群中的Master节点的安装过程被一同安装上，但是在Node节点是无法使用的，如果需要在任意节点使用，需要将`admin.conf`配置文件发送到Node节点

```bash
# 此命令在Master节点上操作
$ scp /etc/Kubernetes/admin.conf root@192.168.140.102:/etc/Kubernetes/
```

接着设置用户环境变量，并刷新

```bash
$ echo "export KUBECONFIG=/etc/Kubernetes/admin.conf" >> ~/.bash_profile
$ source ~/.bash_profile
```

这样就可以在Node节点上使用Kubectl了，使用以下语法从终端窗口运行 kubectl 命令：

```bash
$ kubectl [command] [TYPE] [NAME] [flags]
```

- command：子命令，用于操作资源对象，例如 create、get、describe、delete 等
- TYPE：资源对象的类型，区分大小写，能以单数、复数或者简写形式表示
- NAME：资源对象的名称，区分大小写。如果不指定名称，系统则将返回属于 TYPE 的全部对象的列表

如果需要更多的帮助信息可以使用`Kubectl help`查看

## 二、Kubectl 子命令

Kubectl作为集群的命令行工具，主要作用是对集群的资源对象进行操作比如对node，pod,service,replicaset、deployment、statefulet、daemonset、job、cronjob这些资源的操作包括但不限于创建、删除和查看等。因此Kubectl提供了非常多的子命令如

在命令行窗格输入`$ kubectl help` 直接回车，就会出现相关子命令

这些子命令使得Kubectl成为一个强大而灵活的工具，可以满足对集群资源的各种操作需求

### 2.1 基础初级：Basic Commands (Beginner)

基础初级：Basic Commands (Beginner)

- create：从'文件'(Yaml文件)或标准输入创建资源
  - 例如`$ kubectl create -f greatsql-single.yaml`
- expose：将已经存在的一个RC、Service、Deployment 或Pod 暴露为一个新的Service
- run：创建并运行一个特定的镜像；
- set：设置资源对象的某个特定信息，目前仅支持修改容器内的镜像

### 2.2 基础中级：Basic Commands (Intermediate)

- explain：对资源对象属性的详细说明
- get：显示一个或者多个资源对象的概要信息
  - 例如`$ kubeclt get pod`

- edit：编辑资源对象的属性，在线更新
  - 例如`$ kubectl edit ConfigMap greatsql`

- delete：根据配置文件、stdin、资源名称或label selector 删除资源对象
  - 例如`$ kubectl delete pod greatsql-0`


### 2.3 部署应用程序相关：Deploy Commands

- rollout：管理资源部署，可管理的资源类型对象包括"deployments","daemonsets","statefulsets"
- scale：扩容、缩容一个deployments、ReplicaSet、RC或者Job中Pod的数量
- autoscale：对deployments、ReplicaSet、或ReplicationController 进行水平自动扩容和缩容的设置

### 2.4 集群管理命令：Cluster Management Commands

- certificate：修改certificate资源
- cluster-info：显示集群Master和内置服务的信息
- top：查看Node或Pod的资源使用情况，需要再集群中运行Metrics Server
- cordon：将Node标记为unschedulable，既"隔离"出居群调度范围
- uncordon：将Node设置为schedulable
- drain：首先将Node设置为unschedulable，然后删除在该Node上运行的所有Pod，但不会删除不由API Server管理的Pod
- taint：设置Node的taint信息，用于将特定的Pod调度到特定的Node的操作，为Alpha版本的功能

### 2.5 故障排除和调试命令：Troubleshooting and Debugging Commands

- describe：描述一个或者多个资源对象的详细熟悉
- logs：显示一个容器的日志
- attach：附着到一个正在运行的容器上
- exec：运行一个容器的命令
- port-forward：将本机某个端口号映射到Pod的端口号，常用于测试
- proxy：将本机某个端口号映射到API Server
- cp：从容器中复制文件/目录到主机 或者反之
- auth：检测RBAC权限设置
- debug：创建调试会话以排除工作负载和节点的故障

### 2.6 高级命令：Advanced Commands

- diff：查看配置文件与当前系统中正在运行的资源对象的差异
- apply：从配置文件或者stdin中对资源对象进行配置更新
  - 例如`$ kubectl apply -f greatsql.yaml`
- patch：以merge形式对资源对象的部分字段的值进行修改
- replace：从配置文件或stdin替换资源对象
- wait：[实验]等待一个或多个资源的特定条件
- kustomize：列出kustomization.yaml配置文件生成的API资源对象，参数必须是包含kustomization.yaml的目录名称或者一个Git库的URL地址

### 2.7 设置命令：Settings Commands

- label：设置或更新资源对象的labels
- annotate：添加或更新资源对象的annotation信息
- completion：输出Shell命令的运行结果码

### 2.8 其它命令：Other Commands

- alpha：显示Alpha版特性的可用命令，例如debug命令

- api-resources：列出服务器上支持的API资源
- api-versions：在服务器上以"组/版本"的形式打印支持的API版本
- config：修改kubeconfig文件
- plugin：在kubectl命令行使用用户自定义的插件
- version：查看系统版本信息

## 三、Kubectl 操作例子

### 3.1 kubectl get

命令描述：列出一个或者多个资源对象信息

以文本格式列出所有的Pod

```bash
$ kubectl get pods
```

以文本格式列出所有 `Pod`，包含附加信息（如 `Node IP`):

```bash
$ kubectl get pods -o wide
```

以文本格式列出指定名称的 `RC`:

```bash
$ kubectl get replicationcontroller  <rc-name>
```

以文本格式列出所有 `RC` 和` Service`:

```bash
$ kubectl get rc,services
```

以文本格式列出所有 `Daemonset`，包括未初始化的 `Daemonset`:

```bash
$ kubectl get ds --include-uninitialized
```

列出在节点 `node01` 上运行的所有` Pod`:

```bash
$ kubectl get pods --field-selector=spec.nodeName=node01
```

### 3.2 kubectl apply

命令描述：可以使用文件或 `stdin` 来部署或更新一个或多个资源

根据 example-service.yaml 文件的定义，您可以创建一个 Service 资源。

```bash
$ kubectl apply -f example-service.yaml
```
根据 example--controller.yaml 文件中的定义，创建一个 Replication Controller 资源。

```bash
$ kubectl apply -f example-controller.yaml
```
根据<directory>目录下的所有yaml、yml和json文件中的定义，进行创建操作。

```bash
$ kubectl apply -f  <directory>
```
kubectl get命令是用于检索一个或多个资源对象的常用命令。它可以用来查看同一类型的资源对象，并且可以使用-o或--output参数来自定义输出格式。此外，还可以通过-w或--watch参数来监控资源对象的更新情况。

### 3.3 kubectl describe
命令描述：显示一个或多个资源的详细信息

显示名称为<node-name>节点的详细信息
```bash
$ kubectl describe nodes  <node-name>
```
显示名称为<pod-name>的 Pod 的详细信息
```bash
$ kubectl describe pods/ <pod-name>
```
显示名称为<rc-name>的RC控制器管理的所有Pod的详细信息
```bash
$ kubectl describe pods  <rc-name>
```
描述所有 Pod 的详细信息
```bash
$ kubectl describe pods
```
kubectl describe命令更加侧重于提供指定资源的详细信息。它通过与API Server进行多个API调用来构建结果视图。举个例子，使用kubectl describe node命令不仅会返回节点的基本信息，还会提供在该节点上运行的Pod的摘要以及节点相关的事件等详细信息。

### 3.4 kubectl delete

命令描述：kubectl delete命令可以使用文件或stdin的输入来删除指定的资源对象。此外，它还支持通过标签选择器、名称、资源选择器等条件来限定待删除的资源范围。这意味着可以根据特定的条件来删除资源，而不仅仅是单个资源对象。

使用在 greatsql.yaml 文件中指定的类型和名称删除 Pod:
```bash
$ kubectl delete -f greatsql.yaml
```
删除所有带有<label-key> = <label-value>: 标签的 Pod 和 Service:
```bash
$ kubectl delete pods, services -1  <label-key> = <label-value>
```
删除所有 Pod，包括未初始化的 Pod
```bash
$ kubectl delete pods -all
```

### 3.5 kubectl exec
命令描述：在 Pod 的容器中运行命令

在名称为<pod-name>Pod 的第 1 个容器中运行 date 命令并打印输出结果
```bash
$ kubectl exec  <pod-name> -- date
```
在指定的容器中运行 date 命令并打印输出结果
```bash
$ kubectl exec  <pod-name> -c  <container-name> -- date
```
在Pod的第 1 个容器中运行bin/bash 命令进入交互式 TTY 终端界面
```bash
$ kubectl exec -ti  <pod-name> /bin/bash
```
### 3.6 kubectl logs
命令描述：打印 Pod 中容器的日志
```bash
$ kubectl logs  <pod-name>
```
显示Pod 中名称为<container-name>的容器输出到 stdout 的日志：
```bash
$ kubectl logs  <pod-name> -c  <container-name>
```
持续监控显示 pod 中第一个容器输出到 stdout 的日志，类似于 tail -f 命令的功能
```bash
$ kubectl logs -f  <pod-name>
```
### 3.7 kubectl edit
命令描述：编辑运行中的资源对象，例如使用下面的命令编辑运行中的一个 Deployment
```bash
$ kubectl edit deploy greatsql
```
命令运行后，将以YAML格式展示该对象的文本格式定义，用户可以对代码进行编辑和保存，以实现对在线资源的直接修改
### 3.8 kubectl port-forward
命令描述：将 Pod 的端口号映射到宿主机
将Pod的80端口映射到宿主机的3306端口，客户端可以通过"http://<NodeIP>:3306"来访问容器服务
```bash
$ kubectl port-forward --address 0.0.0.0 \ pod/greatsql-0 3306:80
```

### 3.9 kubectl cp
命令描述：在容器和 Node之间复制文件
把Pod中的/etc/my.cnf文件复制到宿主机的/uer/local 目录下
```bash
$ kubectl cp greatsql-0:/etc/fstab /uer/local
```
### 3.10 kubectl label
命令描述：设置资源对象的标签
名为greatsql的命名空间设置"testing=true"标签：
```bash
$ kubectl label namespaces greatsql testing=true
```
如果要覆盖现有的 label，可以使用 --overwrite 参数
```bash
$ kubectl label --overwrite namespaces greatsql testing=true
```

## 参考资料

- [Docker与Kubernetes容器运维实战](https://baike.baidu.com/item/Docker与Kubernetes容器运维实战/63475077?fr=ge_ala)

## 免责声明

因个人水平有限，专栏中难免存在错漏之处，请勿直接复制文档中的命令、方法直接应用于线上生产环境。请读者们务必先充分理解并在测试环境验证通过后方可正式实施，避免造成生产环境的破坏或损害。

## 联系我们
---
扫码关注微信公众号

![输入图片说明](../greatsql-wx.jpg)
