
# 第五章 Kubernetes中的Pod

## 一、Pod 简介
Pod的直译是豆荚，可以将容器想象成豆荚中的豆子。将一个或多个密切相关的豆子包裹在一起形成一个豆荚（即一个Pod）。在Kubernetes中，我们不直接操作容器，而是将容器封装在Pod中进行管理。

Pod 是 Kubernetes 项目中最小的 API 对象。如果换一个更专业的说法，可以这样描述：Pod，是 Kubernetes 项目的原子调度单位

## 二、Pod 运行
为了更好地理解，我们将使用一个最简单的例子来介绍如何运行Pod
> 注意！这里仅为举例学习，并不能作为生产使用
```bash
$ kubectl run greatsql-pod --image=greatsql/greatsql:8.0.32-25 --env=MYSQL_ROOT_PASSWORD=1 --env=MAXPERF=0
pod/greatsql-pod created
```
在上面的命令中，greatsql-pod是要创建Pod的名称
> 此处只能字母数字开头或者结尾，只能由小写字母和数字或'-'or'.'符号组成，其余会报错
--image=greatsql/greatsql:8.0.32-25 是用来指定容器所使用的镜像
--env=MYSQL_ROOT_PASSWORD=1 是用来指定初始化密码为空
--env=MAXPERF=0 是用来指定不以MAXPERF=1模式运行

执行完成命令之后，可以通过 get pod 命令查看刚才运行的Pod
```bash
$ kubectl get pod                                                                            
NAME           READY   STATUS    RESTARTS   AGE
greatsql-pod   1/1     Running   0          5s
```
- NAME：Pod 的名称。在这个例子中，Pod 的名称是 greatsql-pod
- READY：Pod 中运行正常的容器的数量和 Pod 中总的容器的数量。在这个例子中，1/1 表示 Pod 中有 1 个容器，而且这个容器都在运行正常。
- STATUS：Pod 的状态。在这个例子中，Pod 的状态是 Running，表示 Pod 中的所有容器都在运行正常。
- RESTARTS：Pod 中的容器重启的次数。在这个例子中，0 表示 Pod 中的容器没有重启过。
- AGE：Pod 创建的时间。在这个例子中，Pod 创建了 59m，即 59 秒。

## 三、GreatSQL-pod 尝试运行
> 此处建议动手实践一下，以便更好地理解和掌握。

首先我们创建一个GreatSQL的文件夹，用来存储GreatSQL Pod的yaml配置文件，文件路径位置可自行设置

```bash
$ mkdir -p /opt/k8s/greatsql
$ cd /opt/k8s/greatsql
```
创建并编辑 `greatsql-pod.yaml`
> 小提示： 
1.greatsql-pod.yaml使用的是HostPath卷，仅作为学习部署
2.因为Kubernetes集群中容器可能会被调度到任意节点，且配置文件可能需要在任意节点中更新，故使用ConfigMap

```bash
$ vim /opt/k8s/greatsql/greatsql-pod.yaml
```
因代码篇幅过长，将配置yaml存放到GreatSQL-K8S-Config/greatsql-pod目录下
- [点击此处查看greatsql-pod.yaml](../GreatSQL-K8S-Config/greatsql-pod/greatsql-pod.yaml)

镜像拉取策略，有Always、Never、IfNotPresent

- Always(默认):每次都尝试重新拉取镜像
- Never：仅适用本地镜像
- IfNotPresent：如果本地有就使用本地，如果本地没有就拉取在线

hostPath的type值

- DirectoryOrCreate:目录不存在则自动创建
- Directory:挂载已存在的目录，不存在会报错
- FileOrCreate：文件不存在则自动创建，不会自动创建文件的父目录，必须确保文件路径已存在
- File：挂载已存在的文件，不存在会报错
- Socket：挂载UNIX套接字，例如挂载sock进程

重启策略，有Always(默认值)、OnFailure、Never

- Always(默认值):Pod一旦终止，无论容器是如何终止，kubelet都将重启它
- OnFailure:只有Pod以非零退出码终止时，kubelet才会重启它，如果正常退出，则kubelet不会重启
- Never:Pod终止后，kubelet将退出码报告master，不会重启该Pod

下载或复制 [greatsql-pod.yaml](../GreatSQL-K8S-Config/greatsql-pod/greatsql-pod.yaml) 内容后使用`kubectl apply -f`使文件创建并生效
```bash
$ kubectl apply -f /opt/k8s/greatsql/greatsql-pod.yaml
pod/greatsql-pod created
configmap/greatsql-config unchanged
```
要查看这个Pod的信息，可以使用以下命令：`$ kubectl get pod`，如果想要查看更详细的信息，可以使用命令：`$ kubectl get po -owide`
```bash
$ kubectl get pod                   
NAME           READY   STATUS    RESTARTS   AGE
greatsql-pod   1/1     Running   0          7s
```
如果发现greatsql-pod这个pod一直处于ContainerCreating状态，可以使用以下方法来排查错误：首先，使用命令`kubectl describe pod greatsql-pod`来查看该pod的详细信息，以便了解具体的错误原因。其次，还可以使用命令`kubectl logs greatsql-pod`来查看该pod的日志，以便更深入地排查错误。

可以看到这个Pod创建在node1节点上，此时可以去node1节点上看数据目录是否生成
```bash
# 注意此时是在node1主机上查看
$ ls /data/GreatSQL/
auto.cnf       binlog.index     client-key.pem     ib_buffer_pool  innodb_status.1  mysql.pid           private_key.pem  slow.log   undo_002
binlog.000001  ca-key.pem       error.log          ibdata1         #innodb_temp     mysql.sock          public_key.pem   sys
binlog.000002  ca.pem           #ib_16384_0.dblwr  ibtmp1          mysql            mysql.sock.lock     server-cert.pem  sys_audit
binlog.000003  client-cert.pem  #ib_16384_1.dblwr  #innodb_redo    mysql.ibd        performance_schema  server-key.pem   undo_001
```
进入GreatSQL数据库查看cnf文件是否生效

```bash
$ kubectl exec -it greatsql-pod -- bash
$ mysql
#进入数据库后查看，发现server_id修改成功
greatsql> show global variables like "server_id";
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| server_id     | 33066 |
+---------------+-------+
1 row in set (0.00 sec)
```
使用`$ kubectl edit cm greatsql-config`可以修改cnf配置文件

## 四、Pod 的几种状态

在Pod中的STATUS有以下几个状态：

- Pending（挂起）：Pod已被Kubernetes系统接受，但是其中一个或多个容器尚未被创建。这可能是因为调度器正在寻找适合运行容器的节点，或者正在等待容器镜像下载或其他初始化操作。
- Running（运行中）：Pod已经被绑定到一个节点上，并且所有的容器都已经被创建。至少有一个容器处于运行状态，或者正在启动或重启过程中。
- Succeeded（成功）：所有容器已经成功执行并终止，并且不会再次重启。
- Failed（失败）：所有容器都已经终止，并且至少有一个容器以失败的方式终止。这意味着该容器以非0状态退出，或者被系统终止。
- Unknown（未知）：无法获取Pod的状态。这种情况通常是由于与Pod相关的API调用失败或Pod控制器处于错误状态所导致的。

此外，Pod 还有一些特殊的条件状态，它们记录了 Pod 的一些细节信息，例如 Pod 是否处于调度中、容器镜像是否拉取成功等。这些状态和条件状态可以通过`kubectl describe pod`命令获取。例如，PodScheduled 表示 Pod 是否已经被调度到了节点上，ContainersReady 表示 Pod 中的所有容器是否已经准备就绪，Initialized 表示 Pod 中的所有容器是否已经初始化

## 五、Pod 错误原因及排查

### 5.1 Pending（挂起）

在 Kubernetes 中，Pending 状态的 Pod 通常是由于调度器无法将该 Pod 调度到可用的节点上。可能的原因包括：

- 节点资源不足：当节点上的资源（如CPU、内存、存储等）已被其他Pod占用时，节点资源不足。在这种情况下，调度器无法将新的Pod调度到该节点上。

- 节点标签不匹配：如果Pod的调度要求某些特定的节点标签，而当前可用节点上没有符合要求的标签，调度器将无法将该Pod调度到该节点上。调度器会根据Pod的调度要求和节点的标签进行匹配，以确定最适合的节点来部署Pod。如果没有节点符合Pod的标签要求，调度器将无法找到合适的节点来调度Pod。因此，Pod可能会处于未调度状态，直到有符合要求的节点可用为止。

- 网络问题：如果节点之间的网络连接不稳定或存在故障，调度器将无法将Pod调度到可用的节点上。这是因为调度器需要通过网络连接来与节点进行通信和协调，以确保Pod能够正确地部署和运行。如果网络连接不可靠或存在故障，调度器将无法正常工作，从而影响Pod的调度过程。

为了排查 Pending 状态的 Pod，可以执行以下步骤：

- 要确认节点资源是否足够，可以使用以下命令来查看节点的资源使用情况 `$ kubectl describe node <node-name> -n xxx ` 将<node-name>替换为节点的名称，<namespace>替换为Pod所在的命名空间。命令查看节点的资源使用情况，确保节点上有足够的资源来运行该 Pod。
- 确认节点标签是否匹配：要查看节点的标签以确保符合Pod调度要求的标签已设置，可以使用以下命令 `$ kubectl describe node <node-name> -n xxx ` 这个命令将显示节点的详细信息，包括节点上设置的标签。通过查看这些标签，可以确认节点是否具有符合Pod调度要求的标签。如果节点上没有所需的标签，可能需要为节点添加或修改标签，以满足Pod的调度要求。
- 检查网络连接是否正常：使用`$ kubectl get nodes` 命令查看所有节点的状态，确保节点之间的网络连接正常。
- 查看调度器日志：要查看调度器的日志以了解为什么无法将Pod调度到可用节点上，可以使用以下命令 `$ kubectl logs -n kube-system <scheduler-pod-name> ` 这个命令将显示调度器的日志信息，其中可能包含有关调度器无法将Pod调度到可用节点的详细信息和错误消息。通过查看这些日志，可以获取更多关于调度器的运行情况和问题的信息，以便进一步排查和解决调度问题。
- 手动指定节点：如果无法解决调度问题，可以考虑手动指定节点来运行Pod。可以使用以下命令来指定节点`$ kubectl apply -f <pod-file.yaml> --node-name=<node-name>`这个命令将根据Pod配置文件创建Pod，并将其手动调度到指定的节点上。请确保指定的节点具有足够的资源来运行Pod，并且符合Pod的调度要求。这样，就可以绕过调度器的自动调度过程，直接将Pod部署到指定的节点上。

总的来说，Pending状态的Pod可能是由于多种原因引起的，例如节点资源不足、节点标签不匹配、网络连接不稳定等。要解决这些问题，您需要根据具体情况进行排查和解决。您可以使用kubectl命令来查看节点和Pod的详细信息，以了解问题的根本原因。

### 5.2 CrashLoopBackOff （重启循环）

当Pod的状态显示为CrashLoopBackOff时，这通常意味着容器在启动后立即崩溃或退出。这种情况可能由多种原因引起，包括容器配置错误、应用程序错误、内存不足、权限问题等。

以下是一些排查 Pod 状态异常的建议：

- 查看 Pod 的日志：可以使用 `$ kubectl logs` 命令来查看Pod的日志，以了解容器启动时发生了什么错误。该命令将显示容器的标准输出和标准错误输出。可以通过指定Pod的名称和容器名称来查看特定容器的日志。
- 检查容器配置：确保容器的配置正确是解决CrashLoopBackOff问题的一种方法。您可以检查容器的入口点、环境变量、端口、卷等，以确保它们正确配置。
- 检查应用程序错误：如果容器配置正确，则可能是应用程序错误导致容器崩溃。可以使用 `$ kubectl exec` 命令进入容器，然后检查应用程序的日志和状态。
- 检查系统资源：如果容器在启动后立即崩溃，可能是由于系统资源问题导致的，如内存不足、CPU 不足或磁盘空间不足等。
- 检查权限问题：如果容器需要特定的权限才能运行，则可能是权限问题导致容器崩溃。例如，容器需要访问宿主机的某些文件或网络资源，但没有足够的权限。

总之，要排查Pod状态异常，需要仔细检查容器的配置、应用程序的错误、系统资源以及权限问题。找到问题后，可以尝试修复它，并重新启动Pod。这包括确保容器的配置正确，检查应用程序的日志和状态，检查系统资源是否足够，以及检查权限是否正确。一旦问题解决，可以重新启动Pod，以确保容器能够正常运行。

### 5.3 Failed（失败）
Pod 状态为Failed通常表示所有容器都已终止，并且至少有一个容器以失败的方式终止，也就是说这个容器 要么以非零状态退出，要么被系统终止。

为了排查 Failed 状态的 Pod，可以执行以下步骤：

- 查看 Pod 的日志：使用 kubectl logs 命令查看 Pod 的日志，以了解容器启动时发生了什么错误。
- 查看Pod建立情况：使用kubectl describe命令查看Pod建立情况
### 5.4 ImagePullBackOff 和 ErrImagePull （拉取镜像失败）

Pod 状态为 ImagePullBackOff ErrImagePull 通常表示镜像拉取失败，一般是由于镜像不存在、网络不通或者需要登录认证引起的。

为了排查 ImagePullBackOff ErrImagePull 状态的 Pod，可以执行以下步骤：

- 查看 Pod 的日志：使用 kubectl logs 命令查看 Pod 的日志，以了解容器启动时发生了什么错误。
- 查看Pod建立情况：使用kubectl describe命令查看Pod建立情况

### 5.5 OOMKilled （容器内存溢出）
Pod 状态为 OOMKilled 通常表示容器内存溢出，一般是容器的内存 Limit 设置的过小，或者程序本身有内存溢出

为了排查 OOMKilled 状态的 Pod，可以执行以下步骤：

- 查看 Pod 的日志：使用 kubectl logs 命令查看 Pod 的日志，以了解容器启动时发生了什么错误。
- 查看Pod建立情况：使用kubectl describe命令查看Pod建立情况

### 5.6 SysctlForbidden （内核配置）
Pod 状态为 SysctlForbidden 通常表示Pod 自定义了内核配置，但 kubelet 没有添加内核配置或配置的内核参数不支持

为了排查 SysctlForbidden 状态的 Pod，可以执行以下步骤：

- 查看 Pod 的日志：使用 kubectl logs 命令查看 Pod 的日志，以了解容器启动时发生了什么错误。
- 查看Pod建立情况：使用kubectl describe 命令查看Pod建立情况。


### 5.7 Completed （执行结束）
Pod 状态为 Completed 通常表示容器内部主进程退出，一般计划任务执行结束会显示该状态

为了排查 Completed 状态的 Pod，可以执行以下步骤：

- 查看 Pod 的日志：使用 kubectl logs 命令查看 Pod 的日志，以了解容器启动时发生了什么错误。
## 参考资料

- [Docker与Kubernetes容器运维实战](https://baike.baidu.com/item/Docker与Kubernetes容器运维实战/63475077?fr=ge_ala)

## 免责声明

因个人水平有限，专栏中难免存在错漏之处，请勿直接复制文档中的命令、方法直接应用于线上生产环境。请读者们务必先充分理解并在测试环境验证通过后方可正式实施，避免造成生产环境的破坏或损害。

## 联系我们
---
扫码关注微信公众号

![输入图片说明](../greatsql-wx.jpg)
