# 第十章 部署多StatefulSet的主从复制

本章介绍在Kubernetes集群中创建 GreatSQL 多StatefulSet方式，一个主节点以及两个从节点的部署架构，在 Kubernetes 中运行 GreatSQL 可以带来众多好处，如

- 资源隔离
- 动态弹性扩缩容
- 环境一致性
- 运维方便

本篇的部署需求如下

- 搭建一个 主从复制 的 GreatSQL 集群
- 存在一个主节点 Master，有两个从节点 Slave
- 从节点可以水平拓展
- 所有的写操作，只能在主节点上执行
- 读操作可以在所有节点上执行

## 一、最低配置和架构

本章将使用采用 NFS存储卷 的方式，持久化存储 GreatSQL 数据目录，具体架构和最低配置如下

> 阅读本章前请您需要阅读完深入浅出Kubernetes 1~9章，或对Kubernetes有一定的基础知识，并已经完成对Kubernetes集群的搭建

kubernetes & Docker & GreatSQL 版本选择

| 名称       | 版本       | 备注                  |
| ---------- | ---------- | --------------------- |
| kubernetes | V1.23.6    | 1.24版本废除Docker    |
| Docker     | V20.10.9   | 1.23最高兼容20.10版本 |
| GreatSQL   | V8.0.32-25 |                       |

Kubernetes集群架构规划

| hostname | ip地址          | 操作系统   | 角色       | 机器最低配置                 |
| -------- | --------------- | ---------- | ---------- | ---------------------------- |
| master   | 192.168.139.120 | Centos 7.6 | master节点 | 最低 2GB ROM、CPU2核心及以上 |
| node1    | 192.168.140.102 | Centos 7.6 | worker节点 | 最低 2GB ROM、CPU2核心及以上 |
| node2    | 192.168.139.104 | Centos 7.6 | worker节点 | 最低 2GB ROM、CPU2核心及以上 |

> 同时把 Master节点 作为 NFS服务器，若有能力且资源充足，可以使用更高存储能力的服务器作为NFS，例如 NAS节点 作为NFS服务器

## 二、部署NFS服务器

NFS卷能将NFS（网络文件系统）挂载到Pod中，不像emptyDir那样会在删除Pod的同时会被删除，NFS卷的内容在删除Pod是会被保存，卷只是被卸载，这意味着NFS卷可以被预先填充数据，并且这些数据可以在Pod之间共享

三台服务器安装NFS服务，提供NFS存储功能

> 注意master、node1、node2都要安装NFS服务

```bash
$ yum install -y nfs-utils
```

启动NFS并设置开机自启

```bash
$ systemctl start nfs-server
$ systemctl enable nfs-server
```

在Mstaer节点上创建三个文件夹，作为数据的存放

```bash
$ mkdir -p /data/nfs/greatsql-master
$ mkdir -p /data/nfs/greatsql-slave-01
$ mkdir -p /data/nfs/greatsql-slave-02
```

并写入到`/etc/exports` 文件中，只在主节点上操作

```bash
#语法格式：共享文件路径 客户机地址（权限）#这里的客户机地址可以是IP,网段,域名,也可以是任意*
$ cat >> /etc/exports << EOF
/data/nfs/greatsql-master *(rw,sync,no_root_squash)
/data/nfs/greatsql-slave-01 *(rw,sync,no_root_squash)
/data/nfs/greatsql-slave-02 *(rw,sync,no_root_squash)
EOF
```

接下来可以直接在主服务器上重启NFS服务器

```bash
$ systemctl restart nfs-server
```

执行后可以通过这行命令来检查目录是否暴露成功

> 注意在三个节点中都要检查一下

```bash
$ showmount -e 192.168.139.120
Export list for 192.168.139.120:
/data/nfs/greatsql-slave-02 *
/data/nfs/greatsql-slave-01 *
/data/nfs/greatsql-master    *
```

到此NFS服务器就已经配置完成了

## 三、创建命名空间

统一个地方来存放GreatSQL在Kubernetes中的资源清单配置文件，可以自行更改位置

```bash
$ mkdir -p /opt/k8s/greatsql_master_slave
$ cd /opt/k8s/greatsql_master_slave
```

创建一个新的命名空间可以做到逻辑隔离、访问控制、自定义资源定义、网络隔离、配置策略隔离、资源管理、可以更好的组织Kubernetes集群，提高管理效率。所以需要创建命名空间来部署GreatSQL集群，当然也可以使用默认的Default命名空间，不过不建议。

推荐都用yaml资源清单文件的方式来创建

```yaml
$ vim greatsql-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: deploy-greatsql
spec: {}
status: {}
```

创建一个Namespace

```bash
$ kubectl apply -f greatsql-namespace.yaml
```

使用`$ kubectl get ns`(namespace = ns)查看Namespace

```bash
$ kubectl get ns
NAME              STATUS   AGE
default           Active   14d
deploy-greatsql   Active   27s # 创建命名空间成功
kube-node-lease   Active   14d
kube-public       Active   14d
kube-system       Active   14d
```

## 四、创建Secret

创建一个存储GreatSQL密码的Secret，可以直接使用这行命令生成这个Secret的资源清单文件

> 若密码不设置为`greatsql`请自行修改，将 PASSWORD= 后面改掉即可

```yaml
$ kubectl create secret generic greatsql-password --namespace=deploy-greatsql --from-literal=PASSWORD=greatsql --dry-run=client -o=yaml
# 输入命令，便出现下面自动生成的Secret资源清单文件
apiVersion: v1
data:
  PASSWORD: Z3JlYXRzcWw=
kind: Secret
metadata:
  creationTimestamp: null
  name: greatsql-password
  namespace: deploy-greatsql
```

> 这里要注意下，网上很多教程采用`echo 123 | base64`这种方式生成密码，但是此时生成的密码，就会把换行符也作为了字符当做密码使用，所以一直报错进不去GreatSQL。如果非要采用这种方法生成密码，需要加上-n，例如：`echo -n 123 | base64`
>
> 建议使用kubectl命令导出更合适，不要直接使用base64命令编码填入yaml文件！

复制上面生成的Secret资源清单，写入到`greatsql-secret.yaml`中

```yaml
$ vim greatsql-secret.yaml

apiVersion: v1
data:
  PASSWORD: Z3JlYXRzcWw=
kind: Secret
metadata:
  creationTimestamp: null
  name: greatsql-password
  namespace: deploy-greatsql
```

创建`greatsql-secret.yaml`

```bash
$ kubectl apply -f greatsql-secret.yaml
```

使用`$ kubectl get secret`查看创建情况

```bash
$ kubectl get secret greatsql-password -n deploy-greatsql
NAME                TYPE     DATA   AGE
greatsql-password   Opaque   1      49m
```

此处的Opaque表示该secret的值是base64编码后的字符串，需要解码后才能获取真实值。这提供了一定的数据保护，避免secret中的敏感数据以明文方式存储。

## 五、部署GreatSQL主节点

### 创建Master节点pv和pvc

```yaml
$ vim greatsql-master-pv-pvc.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: deploy-greatsql-master-nfs-pv
  namespace: deploy-greatsql
spec:
  capacity:
    storage: 5Gi # pv的大小可自行修改
  accessModes:
    - ReadWriteMany
  nfs:
    # 注意修改IP地址和暴露的目录
    server: 192.168.139.120
    path: /data/nfs/greatsql-master
  storageClassName: "nfs"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: deploy-greatsql-master-nfs-pvc
  namespace: deploy-greatsql
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: "nfs"
  resources:
    requests:
      storage: 5Gi # pvc的大小可自行修改,和pv一样就好
  volumeName: deploy-greatsql-master-nfs-pv
```

创建pv和pvc

```bash
$ kubectl apply -f greatsql-master-pv-pvc.yaml 
persistentvolume/deploy-greatsql-master-nfs-pv created
persistentvolumeclaim/deploy-greatsql-master-nfs-pvc created
```

查看创建结果（太长了不好展示，只截取部分）

```bash
$ kubectl get pv,pvc -n deploy-greatsql
NAME 													STATUS  #后面不展示
persistentvolume/deploy-greatsql-master-nfs-pv			Bound
NAME  													STATUS  #后面不展示
persistentvolumeclaim/deploy-greatsql-master-nfs-pvc	Bound
```

### 创建Master节点cnf

首先我们需要准备一个cnf文件，可以参考GreatSQL社区的my.cnf推荐 https://gitee.com/GreatSQL/GreatSQL-Doc/blob/master/docs/my.cnf-example-greatsql-8.0.32-25

这里就采用极简配置，配置几个必要参数

```bash
$ vim greatsql-master.cnf
[client]
socket    = /data/GreatSQL/mysql.sock
[mysql]
prompt="(\\D)[\\u@GreatSQL][\\d]> "
[mysqld]
skip-host-cache
skip-name-resolve
datadir          = /data/GreatSQL
socket           = /data/GreatSQL/mysql.sock
log_error        = /data/GreatSQL/error.log
secure-file-priv = /var/lib/mysql-files
pid-file         = mysql.pid
user             = mysql
secure-file-priv = NULL
server-id        = 1  # server id，要注意多个GeratSQL节点唯一
log-bin          = master-bin  # 生成的logbin的文件名
log_bin_index    = master-bin.index  
binlog-format    = ROW  # binlog的格式
```

接下来将创建一个ConfigMap来存储这个配置文件。可以使用以下配置生成yaml资源清单文件内容

```bash
$ kubectl create configmap greatsql-master-cnf -n deploy-greatsql --from-file=greatsql-master.cnf --dry-run=client -o yaml
# 会自动生成以下内容
apiVersion: v1
data:
  my.cnf: | # 原本为greatsql-master.cnf，修改成my.cnf 方便后续定位
    [client]
    socket    = /data/GreatSQL/mysql.sock
    [mysql]
    prompt="(\\D)[\\u@GreatSQL][\\d]> "
    [mysqld]
    skip-host-cache
    skip-name-resolve
    datadir          = /data/GreatSQL
    socket           = /data/GreatSQL/mysql.sock
    log_error        = /data/GreatSQL/error.log
    secure-file-priv = /var/lib/mysql-files
    pid-file         = mysql.pid
    user             = mysql
    secure-file-priv = NULL
    server-id        = 1
    log-bin          = master-bin
    log_bin_index    = master-bin.index
    binlog-format    = ROW
kind: ConfigMap
metadata:
  creationTimestamp: null
  name: greatsql-master-cnf
  namespace: deploy-greatsql
```

> data：下的原本为greatsql-master.cnf，此处修改为my.cnf，为方便后续定位

复制生成的内容到`greatsql-master-cnf.yaml`，并创建配置文件，且查看是否创建成功

```bash
$ vim greatsql-master-cnf.yaml
# 复制上面生成的进来就好了，此处不展示

$ kubectl apply -f greatsql-master-cnf.yaml
configmap/greatsql-master-cnf created

$ kubectl get cm -n deploy-greatsql
NAME                  DATA   AGE
greatsql-master-cnf   1      23s  # 创建成功
kube-root-ca.crt      1      4h57m
```

### 创建Master节点server

```bash
$ vim greatsql-master-svc.yaml

apiVersion: v1
kind: Service
metadata:
  name: deploy-greatsql-master-svc
  namespace: deploy-greatsql
  labels:
    app: greatsql-master
spec:
  ports:
  - port: 3306
    name: greatsql
    targetPort: 3306
    nodePort: 30306
  selector:
    app: greatsql-master
  type: NodePort
  sessionAffinity: ClientIP
```

创建并查看

```bash
$ kubectl apply -f greatsql-master-svc.yaml 
service/deploy-greatsql-master-svc created

$ kubectl get svc -n deploy-greatsql
NAME                         TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)          AGE
deploy-greatsql-master-svc   NodePort   10.98.12.52   <none>        3306:30306/TCP   17s
```

### 创建Master节点StatefulSet

```yaml
$ vim greatsql-master-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: deploy-greatsql-master
  namespace: deploy-greatsql
spec:
  selector:
    matchLabels:
      app: greatsql-master
  serviceName: "deploy-greatsql-master-svc"
  replicas: 1
  template:
    metadata:
      labels:
        app: greatsql-master
    spec:
      terminationGracePeriodSeconds: 10
      containers:
      - args:
        - --character-set-server=utf8mb4
        - --collation-server=utf8mb4_unicode_ci
        - --lower_case_table_names=1
        - --default-time_zone=+8:00
        name: greatsql
        image: greatsql/greatsql:8.0.32-25
        ports:
        - containerPort: 3306
          name: greatsql
        volumeMounts:
        - name: greatsql-data
          mountPath: /data/GreatSQL
        - name: greatsql-conf
          mountPath: /etc/my.cnf
          readOnly: true
          subPath: my.cnf
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              key: PASSWORD
              name: greatsql-password
              optional: false
        - name: MAXPERF
          value: "0"
      volumes:
      - name: greatsql-data
        persistentVolumeClaim:
          claimName: deploy-greatsql-master-nfs-pvc
      - name: greatsql-conf
        configMap:
          name: greatsql-master-cnf
          items:
            - key: my.cnf
              mode: 0644
              path: my.cnf
```

创建statefulset并检查是否创建成功

```bash
$ kubectl apply -f greatsql-master-statefulset.yaml
statefulset.apps/deploy-greatsql-master created

$ kubectl get statefulset -n deploy-greatsql
NAME                     READY   AGE
deploy-greatsql-master   1/1     12m
```

查看Pod创建情况

```bash
$ kubectl get po -n deploy-greatsql
NAME                       READY   STATUS    RESTARTS   AGE
deploy-greatsql-master-0   1/1     Running   0          5m15s
```

> 注意查看`READY`，若为0/1则使用`kubectl describe pod deploy-greatsql-master-0 -n deploy-greatsql` 排查错误

接下来查看一下NFS挂载的目录，可以看到初始化文件已经出现了

```bash
$ ls /data/nfs/greatsql-master
auto.cnf    ca.pem           client-key.pem     #ib_16384_1.dblwr  ibdata1  #innodb_redo  master-bin.000001  master-bin.000003  mysql      mysql.pid   mysql.sock.lock     private_key.pem  server-cert.pem  sys        undo_001
ca-key.pem  client-cert.pem  #ib_16384_0.dblwr  ib_buffer_pool     ibtmp1   #innodb_temp  master-bin.000002  master-bin.index   mysql.ibd  mysql.sock  performance_schema  public_key.pem   server-key.pem   sys_audit  undo_002
```

> 这里也要看binlog文件名是否为master-bin，否则就是my.cnf配置文件未能生效

进入Pod查看GreatSQL数据库情况

```bash
$ kubectl exec -it deploy-greatsql-master-0 -n deploy-greatsql -- bash -c "mysql -uroot -p"
Enter password:  # 这里输入密码
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 10
Server version: 8.0.32-25 GreatSQL (GPL), Release 25, Revision c2e83f27394

greatsql> show global variables like "server_id"; # 查看下server_id是否为1
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| server_id     | 1     |
+---------------+-------+
1 row in set (0.01 sec)
```

## 六、部署GreatSQL从节点

刚刚安装部署成功了GreatSQL的主节点，接下来安装部署GreatSQL的第一个从节点

### 创建Slaver节点PV和PVC

```yaml
$ vim greatsql-slave-01-pv-pvc.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: deploy-greatsql-slave-01-nfs-pv
  namespace: deploy-greatsql
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteMany
  nfs:
  # 注意修改IP地址和暴露的目录
    server: 192.168.139.120
    path: /data/nfs/greatsql-slave-01
  storageClassName: "nfs"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: deploy-greatsql-slave-01-nfs-pvc
  namespace: deploy-greatsql
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: "nfs"
  resources:
    requests:
      storage: 5Gi
  volumeName: deploy-greatsql-slave-01-nfs-pv
```

创建PV和PVC

```bash
$ kubectl apply -f greatsql-slave-01-pv-pvc.yaml
persistentvolume/deploy-greatsql-slave-01-nfs-pv created
persistentvolumeclaim/deploy-greatsql-slave-01-nfs-pvc created
```

创建完成后要检查一下

```bash
$ kubectl get pv,pvc -n deploy-greatsql
NAME 													STATUS  #后面不展示
persistentvolume/deploy-greatsql-slave-01-nfs-pv   	Bound
NAME  													STATUS  #后面不展示
persistentvolumeclaim/deploy-greatsql-slave-01-nfs-pvc	Bound
```

### 创建Slaver节点cnf

我们需要为从节点准备一个` my.cnf `配置文件：

```bash
$ vim greatsql-slave-01.cnf

[client]
socket           = /data/GreatSQL/mysql.sock
[mysql]
prompt="(\\D)[\\u@GreatSQL][\\d]>"
[mysqld]
skip-host-cache
skip-name-resolve
datadir          = /data/GreatSQL
socket           = /data/GreatSQL/mysql.sock
log_error        = /data/GreatSQL/error.log
secure-file-priv = /var/lib/mysql-files
pid-file         = mysql.pid
user             = mysql
secure-file-priv = NULL
server-id        = 2   # server id,注意不同节点要不一样
log-bin          = slave-bin
relay-log        = slave-relay-bin
relay-log-index  = slave-bin.index
```

接下来将创建一个ConfigMap来存储这个配置文件。可以使用以下配置生成yaml资源清单文件内容

```yaml
$ kubectl create configmap greatsql-slave-01-cnf -n deploy-greatsql --from-file=greatsql-slave-01.cnf --dry-run=client -o yaml
# 会自动生成ConfigMap的内容，这里就不在示范
```

把生成的内容贴到`greatsql-slave-01.yaml`中

> 记得把data下方的 greatsql-slave-01.cnf | 修改为 my.cnf: | 方便后续定位

```yaml
$ vim greatsql-slave-01-cnf.yaml
# 复制自动生成的内容进来即可

$ kubectl apply -f greatsql-slave-01-cnf.yaml
configmap/greatsql-slave-01-cnf created

$ kubectl get cm -n deploy-greatsql
NAME                  DATA   AGE
greatsql-master-cnf      1      18h
greatsql-slave-01-cnf   1      35s
kube-root-ca.crt         1      23h
```

### 创建Slaver节点Service

接下来创建一个Service，这个Service将让所有Slaver节点共用

```bash
$ vim greatsql-slave-svc.yaml

apiVersion: v1
kind: Service
metadata:
  name: deploy-greatsql-slave-svc
  namespace: deploy-greatsql
  labels:
    app: greatsql-slave
spec:
  ports:
  - port: 3306
    name: greatsql
    targetPort: 3306
    nodePort: 30308
  selector:
    app: greatsql-slave
  type: NodePort
  sessionAffinity: ClientIP
```

创建并查看

```bash
$ kubectl apply -f greatsql-slave-svc.yaml
service/deploy-greatsql-slave-svc created

$ kubectl get svc -n deploy-greatsql
NAME                         TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
deploy-greatsql-master-svc   NodePort   10.98.12.52     <none>        3306:30306/TCP   18h
deploy-greatsql-slave-svc   NodePort   10.96.112.130   <none>        3306:30308/TCP   5s
```

### 创建Slaver节点StatefulSet

```yaml
$ vim greatsql-slave-statefulset-01.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: deploy-greatsql-slave-01
  namespace: deploy-greatsql
spec:
  selector:
    matchLabels:
      app: greatsql-slave
  serviceName: "deploy-greatsql-slave-svc"
  replicas: 1
  template:
    metadata:
      labels:
        app: greatsql-slave
    spec:
      terminationGracePeriodSeconds: 10
      containers:
        - args:
            - --character-set-server=utf8mb4
            - --collation-server=utf8mb4_unicode_ci
            - --lower_case_table_names=1
            - --default-time_zone=+8:00
          name: greatsql
          image: greatsql/greatsql:8.0.32-25
          ports:
            - containerPort: 3306
              name: greatsql
          volumeMounts:
            - name: greatsql-data
              mountPath: /data/GreatSQL
            - name: greatsql-conf
              mountPath: /etc/my.cnf
              readOnly: true
              subPath: my.cnf
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  key: PASSWORD
                  name: greatsql-password
                  optional: false
            - name: MAXPERF
	      value: "0"
      volumes:
        - name: greatsql-data
          persistentVolumeClaim:
            claimName: deploy-greatsql-slave-01-nfs-pvc
        - name: greatsql-conf
          configMap:
            name: greatsql-slave-01-cnf
            items:
              - key: my.cnf
                mode: 0644
                path: my.cnf
```

创建statefulset并检查是否创建成功

```bash
$ kubectl apply -f greatsql-slave-statefulset-01.yaml
statefulset.apps/deploy-greatsql-slave-01 created

$ kubectl get statefulset -n deploy-greatsql
NAME                        READY   AGE
deploy-greatsql-master      1/1     17h
deploy-greatsql-slave-01   1/1     7s
```

查看Pod创建情况

```bash
$ kubectl get po -n deploy-greatsql
NAME                          READY   STATUS    RESTARTS   AGE
deploy-greatsql-master-0      1/1     Running   0          17h
deploy-greatsql-slave-01-0   1/1     Running   0          2m8s
```

> 注意查看`READY`状态，若为0/1则需要使用`kubectl describe pod deploy-greatsql-slave-01-0 -n deploy-greatsql`排查

接下来查看一下nfs挂载的目录，可以看到初始化文件已经出现了

```bash
$ ls /data/nfs/greatsql-slave-01
auto.cnf    ca.pem           client-key.pem     #ib_16384_1.dblwr  ibdata1  #innodb_redo  mysql      mysql.pid   mysql.sock.lock     private_key.pem  server-cert.pem  slave-bin.000001  slave-bin.000003  sys        undo_001
ca-key.pem  client-cert.pem  #ib_16384_0.dblwr  ib_buffer_pool     ibtmp1   #innodb_temp  mysql.ibd  mysql.sock  performance_schema  public_key.pem   server-key.pem   slave-bin.000002  slave-bin.index   sys_audit  undo_002
```

> 这里也要看一下binlog的文件名是否为slave-bin，若不是则cnf配置文件没生效

进入Pod查看GreatSQL-Slaver-01数据库情况

```bash
$ kubectl exec -it deploy-greatsql-slave-01-0 -n deploy-greatsql -- bash -c "mysql -uroot -p"
Enter password:  # 这里输入密码
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 10
Server version: 8.0.32-25 GreatSQL (GPL), Release 25, Revision c2e83f27394

greatsql> show global variables like "server_id"; # 查看下server_id是否为2
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| server_id     | 2     |
+---------------+-------+
1 row in set (0.02 sec)
```

至此第一个Slaver节点已经部署完成，接下来部署第二个Slvaer节点

## 七、部署GreatSQL第二从节点

此处就简单介绍，避免篇幅太长，首先创建PV和PVC

```yaml
$ vim greatsql-slave-02-pv-pvc.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: deploy-greatsql-slave-02-nfs-pv
  namespace: deploy-greatsql
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 192.168.139.120
    path: /data/nfs/greatsql-slave-02
  storageClassName: "nfs"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: deploy-greatsql-slave-02-nfs-pvc
  namespace: deploy-greatsql
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: "nfs"
  resources:
    requests:
      storage: 5Gi
  volumeName: deploy-greatsql-slave-02-nfs-pv
```

创建PV和PVC，并检查一下

```bash
$ kubectl apply -f greatsql-slave-02-pv-pvc.yaml
$ kubectl get pv,pvc -n deploy-greatsql
```

复制一个`my.cnf `配置文件，我们直接用Slaver01节点的即可

```bash
$ cp greatsql-slave-01-cnf.yaml greatsql-slave-02-cnf.yaml
$ vim greatsql-slave-02-cnf.yaml
# 修改一下server-id和name 即可
server-id        = 3
name: greatsql-slave-02-cnf
```

创建和检查ConfigMap

```bash
$ kubectl apply -f greatsql-slave-02-cnf.yaml
$ kubectl get cm -n deploy-greatsql
```

创建StatefulSet

```yaml
$ vim greatsql-slave-statefulset-02.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: deploy-greatsql-slave-02
  namespace: deploy-greatsql
spec:
  selector:
    matchLabels:
      app: greatsql-slave
  serviceName: "deploy-greatsql-slave-svc"
  replicas: 1
  template:
    metadata:
      labels:
        app: greatsql-slave
    spec:
      terminationGracePeriodSeconds: 10
      containers:
        - args:
            - --character-set-server=utf8mb4
            - --collation-server=utf8mb4_unicode_ci
            - --lower_case_table_names=1
            - --default-time_zone=+8:00
          name: greatsql
          image: greatsql/greatsql:8.0.32-25
          ports:
            - containerPort: 3306
              name: greatsql
          volumeMounts:
            - name: greatsql-data
              mountPath: /data/GreatSQL
            - name: greatsql-conf
              mountPath: /etc/my.cnf
              readOnly: true
              subPath: my.cnf
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  key: PASSWORD
                  name: greatsql-password
                  optional: false
            - name: MAXPERF
              value: "0"
      volumes:
        - name: greatsql-data
          persistentVolumeClaim:
            claimName: deploy-greatsql-slave-02-nfs-pvc
        - name: greatsql-conf
          configMap:
            name: greatsql-slave-02-cnf
            items:
              - key: my.cnf
                mode: 0644
                path: my.cnf
```

创建statefulset并检查是否创建成功

```bash
$ kubectl apply -f greatsql-slave-statefulset-02.yaml
statefulset.apps/deploy-greatsql-slave-02 created

$ kubectl get statefulset -n deploy-greatsql
NAME                        READY   AGE
deploy-greatsql-master      1/1     122m
deploy-greatsql-slave-01   1/1     94m
deploy-greatsql-slave-02   1/1     5s
```

查看Pod创建情况

```bash
$ kubectl get po -n deploy-greatsql
NAME                          READY   STATUS    RESTARTS   AGE
deploy-greatsql-master-0      1/1     Running   0          123m
deploy-greatsql-slave-01-0   1/1     Running   0          94m
deploy-greatsql-slave-02-0   1/1     Running   0          22s
```

> 注意查看`READY`状态，若为0/1则需要使用`kubectl describe pod deploy-greatsql-slave-02-0 -n deploy-greatsql`排查

接下来查看一下nfs挂载的目录，可以看到初始化文件已经出现了

```bash
$ ls /data/nfs/greatsql-slave-02
auto.cnf    client-cert.pem  #file_purge        ib_buffer_pool  #innodb_redo  mysql.ibd   mysql.sock.lock     public_key.pem   slave-bin.000001  slave-bin.index  undo_001
ca-key.pem  client-key.pem   #ib_16384_0.dblwr  ibdata1         #innodb_temp  mysql.pid   performance_schema  server-cert.pem  slave-bin.000002  sys              undo_002
ca.pem      error.log        #ib_16384_1.dblwr  ibtmp1          mysql         mysql.sock  private_key.pem     server-key.pem   slave-bin.000003  sys_audit
```

> 这里也要看一下binlog的文件名是否为slave-bin，若不是则cnf配置文件没生效

到此，已经部署完成三台服务器了，接下来将组成一个组从复制的架构

## 八、组成主从集群

进入Master节点

```bash
$ kubectl exec -it deploy-greatsql-master-0 -n deploy-greatsql -- bash -c "mysql -uroot -p"
Enter password:  # 这里输入密码
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 10
Server version: 8.0.32-25 GreatSQL (GPL), Release 25, Revision c2e83f27394
```

查看下Master节点binlog的位置

```bash
$ show master status;
+-------------------+----------+--------------+------------------+-------------------+
| File              | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set |
+-------------------+----------+--------------+------------------+-------------------+
| master-bin.000003 |      157 |              |                  |                   |
+-------------------+----------+--------------+------------------+-------------------+
1 row in set (0.00 sec)
```

记住File字段和Position字段的值，下面要用到

接下来我们来看下这行配置主从复制中的从库的命令

```bash
$ change master to master_host='deploy-greatsql-master-0.deploy-greatsql-master-svc.deploy-greatsql.svc.cluster.local', master_port=3306, master_user='root', master_password='greatsql', master_log_file='master-bin.000003', master_log_pos=157, master_connect_retry=30, get_master_public_key=1;
```

注意以下几个参数

- master_host: 主库的主机地址，kubernetes提供的解析规则是 pod名称.service名称.命名空间.svc.cluster.local 
- master_port: 主库的端口号默认是3306
- master_user: 用于复制连接的用户名
- master_password: 登录到主节点要用到的密码
- master_log_file: 之前查看GreatSQL主节点状态时候的 File 字段
- master_log_pos: 之前查看GreatSQL主节点状态时候的 Position 字段
- master_connect_retry: 主节点重连时间
- get_master_public_key: 连接主GreatSQL的公钥获取方式

进入到第一个从节点

```bash
$ kubectl exec -it deploy-greatsql-slave-01-0 -n deploy-greatsql -- bash -c "mysql -uroot -p"

# 输入刚刚提到的指令
greatsql> change master to master_host='deploy-greatsql-master-0.deploy-greatsql-master-svc.deploy-greatsql.svc.cluster.local', master_port=3306, master_user='root', master_password='greatsql', master_log_file='master-bin.000003', master_log_pos=157, master_connect_retry=30, get_master_public_key=1;
Query OK, 0 rows affected, 11 warnings (0.08 sec)

# 开启复制
greatsql> start slave;
(Wed Oct 18 14:17:36 2023)[root@GreatSQL][(none)]>show slave status\G
*************************** 1. row ***************************
               Slave_IO_State: Waiting for source to send event
                  Master_Host: deploy-greatsql-master-0.deploy-greatsql-master-svc.deploy-greatsql.svc.cluster.local
                  Master_User: root
                  Master_Port: 3306
                Connect_Retry: 30
              Master_Log_File: master-bin.000003
          Read_Master_Log_Pos: 157
               Relay_Log_File: slave-relay-bin.000002
                Relay_Log_Pos: 327
        Relay_Master_Log_File: master-bin.000003
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
# 下面省略
1 row in set, 1 warning (0.00 sec)
```

可以看到第一个Slaver节点成功加入，接下来让第二个节点也加入

进入第二个节点

```bash
$ kubectl exec -it deploy-greatsql-slave-02-0 -n deploy-greatsql -- bash -c "mysql -uroot -p"
```

输入刚刚的指令

```bash
# 输入刚刚提到的指令
greatsql> change master to master_host='deploy-greatsql-master-0.deploy-greatsql-master-svc.deploy-greatsql.svc.cluster.local', master_port=3306, master_user='root', master_password='greatsql', master_log_file='master-bin.000003', master_log_pos=157, master_connect_retry=30, get_master_public_key=1;
Query OK, 0 rows affected, 11 warnings (0.08 sec)
# 开启复制
greatsql> start slave;
greatsql> show slave status\G
*************************** 1. row ***************************
               Slave_IO_State: Waiting for source to send event
                  Master_Host: deploy-greatsql-master-0.deploy-greatsql-master-svc.deploy-greatsql.svc.cluster.local
                  Master_User: root
                  Master_Port: 3306
                Connect_Retry: 30
              Master_Log_File: master-bin.000003
          Read_Master_Log_Pos: 157
               Relay_Log_File: slave-relay-bin.000002
                Relay_Log_Pos: 327
        Relay_Master_Log_File: master-bin.000003
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
# 下面省略
1 row in set, 1 warning (0.00 sec)
```

自此我们的主从就搭建完毕了

## 九、测试主从集群

首先我们在主节点当中创建一个数据库和一个数据表

```sql
# 进入主节点
$ kubectl exec -it deploy-greatsql-master-0 -n deploy-greatsql -- bash -c "mysql -uroot -p"

greatsql> CREATE DATABASE testdb;
greatsql> USE testdb;
greatsql> CREATE TABLE testtable (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  age INT NOT NULL,
  address VARCHAR(100),
  created_at DATETIME
);
greatsql> INSERT INTO testtable (name, age, address, created_at) VALUES 
('张三', 20, '北京', '2023-01-01 12:00:00'),
('李四', 25, '上海', '2023-02-01 13:00:00'), 
('王五', 18, '广州', '2023-03-01 14:00:00'),
('赵六', 30, '深圳', '2023-04-01 15:00:00'),
('钱七', 21, '西安', '2023-05-01 16:00:00'),
('孙八', 26, '杭州', '2023-06-01 17:00:00'), 
('周九', 35, '成都', '2023-07-01 18:00:00'),
('吴十', 24, '武汉', '2023-08-01 19:00:00'),
('郑十一', 32, '南京', '2023-09-01 20:00:00'),
('冯十二', 19, '天津', '2023-10-01 21:00:00');
```

接着进入两个从节点查看

```bash
$ kubectl exec -it deploy-greatsql-slave-01-0 -n deploy-greatsql -- bash -c "mysql -uroot -p"
greatsql>  select * from testdb.testtable;
+----+-----------+-----+---------+---------------------+
| id | name      | age | address | created_at          |
+----+-----------+-----+---------+---------------------+
|  1 | 张三      |  20 | 北京    | 2023-01-01 12:00:00 |
|  2 | 李四      |  25 | 上海    | 2023-02-01 13:00:00 |
|  3 | 王五      |  18 | 广州    | 2023-03-01 14:00:00 |
|  4 | 赵六      |  30 | 深圳    | 2023-04-01 15:00:00 |
|  5 | 钱七      |  21 | 西安    | 2023-05-01 16:00:00 |
|  6 | 孙八      |  26 | 杭州    | 2023-06-01 17:00:00 |
|  7 | 周九      |  35 | 成都    | 2023-07-01 18:00:00 |
|  8 | 吴十      |  24 | 武汉    | 2023-08-01 19:00:00 |
|  9 | 郑十一    |  32 | 南京    | 2023-09-01 20:00:00 |
| 10 | 冯十二    |  19 | 天津    | 2023-10-01 21:00:00 |
+----+-----------+-----+---------+---------------------+
10 rows in set (0.01 sec)
# 从节点1没问题，接下来看看从节点2
$ kubectl exec -it deploy-greatsql-slave-02-0 -n deploy-greatsql -- bash -c "mysql -uroot -p"
greatsql>  show global variables like "server_id"; 
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| server_id     | 3     |
+---------------+-------+
1 row in set (0.02 sec)

greatsql>  select * from testdb.testtable;
+----+-----------+-----+---------+---------------------+
| id | name      | age | address | created_at          |
+----+-----------+-----+---------+---------------------+
|  1 | 张三      |  20 | 北京    | 2023-01-01 12:00:00 |
|  2 | 李四      |  25 | 上海    | 2023-02-01 13:00:00 |
|  3 | 王五      |  18 | 广州    | 2023-03-01 14:00:00 |
|  4 | 赵六      |  30 | 深圳    | 2023-04-01 15:00:00 |
|  5 | 钱七      |  21 | 西安    | 2023-05-01 16:00:00 |
|  6 | 孙八      |  26 | 杭州    | 2023-06-01 17:00:00 |
|  7 | 周九      |  35 | 成都    | 2023-07-01 18:00:00 |
|  8 | 吴十      |  24 | 武汉    | 2023-08-01 19:00:00 |
|  9 | 郑十一    |  32 | 南京    | 2023-09-01 20:00:00 |
| 10 | 冯十二    |  19 | 天津    | 2023-10-01 21:00:00 |
+----+-----------+-----+---------+---------------------+
10 rows in set (0.01 sec)
```

到此我们的GreatSQL部署上Kubernetes搭建的主从集群正式完成~

## 十、GreatSQL-Operator仓库

随着云原生技术的蓬勃发展，Kubernetes已然成为容器编排的事实标准，在Web应用、大数据、人工智能等各种场景中被广泛采用。作为数据库界的新星，GreatSQL部署在Kubernetes之上也是大势所趋。

然而，明白Kubernetes的学习门槛较高，yaml文件编排复杂冗长，这给许多GreatSQL用户的 K8s 之旅带来不小困扰。

为此，GreatSQL 社区积极拥抱开源，创建了 GreatSQL-Operator 项目，目标是让更多技术爱好者一同编写 Kubernetes 配置模板，让 GreatSQL 在 K8s 集群中轻松实现高可用。一起学习、贡献、成长。继续推进 GreatSQL 的 K8s 之路，在云原生的海洋中扬帆起航!


## 参考资料

- [Docker与Kubernetes容器运维实战](https://baike.baidu.com/item/Docker与Kubernetes容器运维实战/63475077?fr=ge_ala)

## 免责声明

因个人水平有限，专栏中难免存在错漏之处，请勿直接复制文档中的命令、方法直接应用于线上生产环境。请读者们务必先充分理解并在测试环境验证通过后方可正式实施，避免造成生产环境的破坏或损害。

## 联系我们
---
扫码关注微信公众号

![输入图片说明](../greatsql-wx.jpg)
