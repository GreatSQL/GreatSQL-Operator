
# 第七章 Kubernetes中的服务

## 一、服务的基本概念
 
服务（Service）是Kubernetes系统中的一个重要概念。它提供了一种抽象的方式来公开应用程序的网络服务，并实现了服务发现和负载均衡的功能。通过服务，用户可以方便地将应用程序暴露给集群内部或外部的其他组件或用户。

服务的主要作用有两个方面：

1. 服务发现：服务允许应用程序通过服务名称来访问其他应用程序。无论其他应用程序在集群中的具体位置如何变化，服务都可以提供一个稳定的网络地址。这样，应用程序可以通过服务名称来发现和访问其他应用程序，而无需关心它们的具体IP地址或端口号。

2. 负载均衡：服务可以将流量分发到多个后端Pod实例上，以实现负载均衡。当多个Pod实例提供相同的服务时，服务会自动将流量分发到这些实例之间，以确保请求能够得到平衡地处理。

此外，服务还可以通过标签选择器与Pod进行关联，以便自动管理服务与后端Pod实例之间的关系。服务还可以与Ingress结合使用，实现应用程序的外部访问和安全升级等功能。

Kubernetes中的Pod是有生命周期的，它们可以被创建也可以被销毁，然而一旦被销毁，生命就永远结束了，用户可以动态的创建和销毁Pod，例如需要进行扩容和缩容，或执行滚动升级，另外，Pod也有可能会发生意外，发生意外退出的情况。在这种情况下，Kubernetes会自动创建一个新的Pod副本来代替故障Pod。

每当新的Pod被创建的时候，会获取自己的IP地址，这就意味着Pod的IP地址是不稳定的。这就会导致一个问题，在Kubernetes集群中，如果一组运行后台服务的Pod为其他运行前台服务的Pod提供服务，那么那些提供前台服务的Pod该如何发现并连接到这组提供后台服务的Pod呢？这就需要Kubernetes中的Service。

而且Kubernetes的Service实现了以下功能：

- Pod 中的容器通过环回网络；
- 集群网络提供不同 Pod 之间的通信；
- Service 资源应用程序从集群外部访问；
- Service用于集群内的访问。

### 1.1 为什么不能用Pod IP 进行访问
虽然每个Pod都有分配的IP，但通过PodIP进行访问会出现很多问题：

- Pod是一种临时资源，它可能在任何时间点被删除或被其他Pod替换。例如，当需要为优先级更高的Pod提供资源时，它可能会被节点驱逐；当节点发生故障时；或者当应用程序的副本数减少而不再需要该Pod时。

- pod的IP在其被分配到Node时才会被指定。这也意味着没有办法提前得知他的IP。

- 在水平扩展中，多个Pod副本提供相同的服务。每个副本都有自己的IP地址。如果另一个Pod需要连接到这些副本，它可以使用单个IP地址或DNS名称来进行连接。该DNS名称指向一个负载均衡器，该负载均衡器将请求分发到所有副本中，实现负载均衡的效果。

## 二、Service 的类型

Kubernetes中的服务类型有四种：
1. **ClusterIP Service**：创建一个在集群内部可用的虚拟IP，只能在该集群内部进行访问，对外不可见。适用场景：用于内部服务通信。
2. **NodePort Service**：在每个节点上选择一个端口，映射到Service上。这样，可以从集群外部通过节点IP和NodePort访问服务。
3. **LoadBalancer Service**：根据云提供商的网络负载均衡器创建外部负载均衡器，并将负载均衡器配置到Service上。它将自动分配外部IP地址，外部请求将通过该IP地址访问服务。
4. **ExternalName Service**：将外部服务映射到集群内部服务的Service。它通过DNS CNAME记录，将Service的名称转发到外部服务的名称。

### 2.1 Cluster IP模式

最常用的模式，通常用在集群内的两个服务相互访问
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  namespace: dev
spec:
  selector:
    app: my-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
```
各参数详解
- apiVersion: 资源版本
- kind: 资源类型
- metadata: 元数据
- name: 资源名称
- namesapace: 命名空间
- spec: 描述
- selector: 标签选择器，用于确定当前service代理哪些Pod
- app: 指定带有标签的Pod
- ports: 端口信息
- port: service端口
- targetPort: Pod端口

这个配置创建了一个名为"my-service"的服务对象。该服务可以将来自"my-service:80"的流量转发到具有标签"app=MyApp"且端口为9376的Pod上。Kubernetes会为该服务分配一个IP地址，也称为"Cluster IP"。我们可以使用Cluster IP或服务名称来访问该服务。这种访问方式仅限于集群内部，无法从集群外部进行访问。通过这个服务，我们可以实现在集群内部的应用程序之间进行流量转发和通信。

### 2.2 NodePort Service模式
NodePort Service是Kubernetes中一种常见的服务类型，它允许我们从集群外部通过节点IP和NodePort访问服务。这种服务类型在每个节点上选择一个端口，并将其映射到Service上。

NodePort Service适用于需要从集群外部访问服务的场景。例如，如果你有一个应用程序运行在Kubernetes集群中，并且你希望用户能够通过浏览器访问这个应用程序，那么你可以创建一个NodePort Service来实现这个需求。

下面是一个创建NodePort Service的YAML配置示例：
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  namespace: dev
spec:
  type: NodePort
  selector:
    app: my-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
```
在这个示例中，我们创建了一个名为my-service的NodePort Service，它将流量路由到带有app: my-app标签的Pod上的9376端口。Kubernetes会自动为这个Service分配一个NodePort，我们可以通过这个NodePort从任意节点访问这个Service。

### 2.3 LoadBalancer Service模式
LoadBalancer Service是Kubernetes中一种常见的服务类型，它允许我们从集群外部通过负载均衡器访问服务。这种服务类型会根据云提供商的网络负载均衡器创建外部负载均衡器，并将负载均衡器配置到Service上。LoadBalancer Service适用于需要从集群外部访问服务的场景，特别是在云环境中。

下面是一个创建LoadBalancer Service的YAML配置示例：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  namespace: dev
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
```
在这个示例中，我们创建了一个名为my-service的LoadBalancer Service，它将流量路由到带有app: my-app标签的Pod上的9376端口。Kubernetes会自动为这个Service创建一个负载均衡器，并分配一个外部IP地址，我们可以通过这个IP地址从任意地方访问这个Service。

### 2.4 ExternalName Service模式
ExternalName Service是Kubernetes中一种特殊的服务类型，它允许我们将外部服务映射到集群内部服务的Service。这种服务类型通过DNS CNAME记录，将Service的名称转发到外部服务的名称。

在Kubernetes中，当一个Service的类型被定义为ExternalName时，Kubernetes会创建一个特殊的Service，这个Service没有任何选择器，也没有定义任何端口或协议。相反，它有一个特殊的字段externalName，这个字段在DNS查询时会返回一个CNAME记录，指向这个externalName。

这种服务类型的主要用途是作为服务发现的一种手段，允许Kubernetes的Pods通过Service的名称来访问外部服务。

下面是一个创建ExternalName Service的YAML配置示例：
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-greatsql
spec:
  type: ExternalName
  externalName: my.database.example.com
```
在这个示例中，我们创建了一个名为my-greatsql的ExternalName Service，它将所有对my-greatsql的DNS查询转发到my.database.example.com。这样，我们的应用程序就可以通过访问my-greatsql来访问外部数据库。

## 三、Headless Service

Headless Service是Kubernetes中一种特殊的服务类型。与其他类型的服务不同，Headless Service并不会为服务分配一个集群IP，而是直接暴露Pod的IP地址

当一个Service的类型被定义为Headless时，Kubernetes会创建一个特殊的Service，这个Service没有任何选择器，也没有定义任何端口或协议。相反，它有一个特殊的字段externalName，这个字段在DNS查询时会返回一个CNAME记录，指向这个externalName

Headless Service的主要用途是作为服务发现的一种手段，允许Kubernetes的Pods通过Service的名称来访问外部服务

Headless Service非常适用于需要从集群内部访问外部服务的场景。例如，如果你的应用程序需要访问一个外部数据库，那么你可以创建一个Headless Service来实现这个需求

下面是一个创建Headless Service的YAML配置示例：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: db
  labels:
    app: database
spec:
  ports:
  - name: greatsql
    port: 3306
  # 设置Headless Service
  clusterIP: None
  selector:
    app: greatsql
```
在这个示例中，我们创建了一个名为db的Headless Service。这个Service的主要作用是为StatefulSet成员提供稳定的网络标识，以便其他Pod可以找到它。这是通过DNS查询实现的，当Pod查询db时，它会返回与app: greatsql标签匹配的所有Pod的IP地址，而不是返回一个集群IP。这样，Pod就可以直接与其他Pod通信，而不需要经过负载均衡。

这种类型的Service特别适用于有状态应用，如数据库。在这个示例中，db Service可能用于访问运行在Kubernetes集群中的数据库。数据库可能有多个副本，每个副本都运行在自己的Pod中，并带有app: greatsql标签。通过使用Headless Service，应用程序可以直接访问每个数据库副本，而不需要经过额外的负载均衡。这对于需要读写分离或需要直接访问特定数据库副本的应用程序非常有用。

## 四、如何选择合适的服务类型

在Kubernetes中，选择合适的服务类型主要取决于你的应用程序的需求和运行环境。以下是一些考虑因素：

1. 集群内部还是外部访问：如果你的服务只需要在集群内部访问，那么ClusterIP服务可能是最好的选择。如果你需要从集群外部访问你的服务，那么你可能需要使用NodePort或LoadBalancer服务。

2. 是否运行在云环境中：如果你的Kubernetes集群运行在云环境中，那么LoadBalancer服务可能是一个好选择，因为它可以利用云提供商的负载均衡器。如果你的集群运行在本地或者没有云负载均衡器，那么你可能需要使用NodePort服务。

4. 是否需要稳定的网络标识：对于有状态应用，如数据库，可能需要一个稳定的网络标识，以便其他Pod可以找到它。在这种情况下，Headless Service可能是一个好选择。

3. 是否需要访问外部服务：如果你的应用程序需要访问一个外部服务，那么你可以使用ExternalName服务。这种服务类型通过DNS CNAME记录，将Service的名称转发到外部服务的名称。

## 参考资料

- [Docker与Kubernetes容器运维实战](https://baike.baidu.com/item/Docker与Kubernetes容器运维实战/63475077?fr=ge_ala)

## 免责声明

因个人水平有限，专栏中难免存在错漏之处，请勿直接复制文档中的命令、方法直接应用于线上生产环境。请读者们务必先充分理解并在测试环境验证通过后方可正式实施，避免造成生产环境的破坏或损害。

## 联系我们
---
扫码关注微信公众号

![输入图片说明](../greatsql-wx.jpg)
