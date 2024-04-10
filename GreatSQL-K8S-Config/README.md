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

## 部署MGR - 单StatefulSet

可以在一个StatefulSet中创建多个pod，并构建一个MGR集群。

使用如下命令，即可快速创建StatefulSet：
```bash
$ kubectl apply -f ./greatsql-sts-mgr/ns.yaml
namespace/greatsql created

$ kubectl apply -f ./greatsql-sts-mgr
configmap/mgr created
namespace/greatsql unchanged
persistentvolume/pv-mgr created
persistentvolumeclaim/pvc-mgr created
statefulset.apps/mgr created
service/mgr created
```

确认所有pod都正常启动后，再执行下面命令构建MGR集群。

首先，对第一个pod执行下面的命令：
```bash
$ kubectl -n greatsql exec -it mgr-0 -- bash -c "/tmp/mgr-init.sh"
Defaulted container "mgr" out of: mgr, init-mgr (init)
+++ mysql -f -e 'SELECT user FROM mysql.user WHERE user='\''mgr'\'''
++ '[' -z '' ']'
++ mysql -f -e 'SET SQL_LOG_BIN=0;
               CREATE USER mgr@'\''%'\'' IDENTIFIED BY '\''mgr-in-k8s'\'';
               GRANT BACKUP_ADMIN, REPLICATION SLAVE ON *.* TO mgr@'\''%'\'';
               RESET MASTER;
               RESET SLAVE ALL;
               SET SQL_LOG_BIN=1;
               CHANGE MASTER TO MASTER_USER='\''mgr'\'', MASTER_PASSWORD='\''mgr-in-k8s'\''  FOR CHANNEL '\''group_replication_recovery'\'';
               START GROUP_REPLICATION;'
++ exit 0
```
如果没有报错，并在最后显示 "exit 0"，则表明MGR第一个节点初始化成功，调用脚本查看MGR状态：
```bash
$ kubectl -n greatsql exec -it mgr-0 -- bash -c "/tmp/mgr-stat.sh"
Defaulted container "mgr" out of: mgr, init-mgr (init)
++ mysql -f -e 'SELECT * FROM performance_schema.replication_group_members;
             SELECT MEMBER_ID AS id, COUNT_TRANSACTIONS_IN_QUEUE AS trx_tobe_certified, COUNT_TRANSACTIONS_REMOTE_IN_APPLIER_QUEUE AS relaylog_tobe_applied, COUNT_TRANSACTIONS_CHECKED AS trx_chkd, COUNT_TRANSACTIONS_REMOTE_APPLIED AS trx_done, COUNT_TRANSACTIONS_LOCAL_PROPOSED AS proposed FROM performance_schema.replication_group_member_stats;'
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
| CHANNEL_NAME              | MEMBER_ID                            | MEMBER_HOST | MEMBER_PORT | MEMBER_STATE | MEMBER_ROLE | MEMBER_VERSION | MEMBER_COMMUNICATION_STACK |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
| group_replication_applier | c4c3b7e0-f71a-11ee-bd68-461a4ff55a9c | mgr-0.mgr   |        3306 | ONLINE       | PRIMARY     | 8.0.32         | XCom                       |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
+--------------------------------------+--------------------+-----------------------+----------+----------+----------+
| id                                   | trx_tobe_certified | relaylog_tobe_applied | trx_chkd | trx_done | proposed |
+--------------------------------------+--------------------+-----------------------+----------+----------+----------+
| c4c3b7e0-f71a-11ee-bd68-461a4ff55a9c |                  0 |                     0 |        0 |        2 |        0 |
+--------------------------------------+--------------------+-----------------------+----------+----------+----------+
++ exit 0
```

如果没有报错且确认MGR状态正常，继续对其他pod执行相同命令：
```bash
$ kubectl -n greatsql exec -it mgr-0 -- bash -c "/tmp/mgr-init.sh"
```

最后，再次查看确认MGR状态，正常的话应该可以得到类似下面的结果：
```bash
$ kubectl -n greatsql exec -it mgr-0 -- bash -c "/tmp/mgr-stat.sh"
Defaulted container "mgr" out of: mgr, init-mgr (init)
++ mysql -f -e 'SELECT * FROM performance_schema.replication_group_members;
             SELECT MEMBER_ID AS id, COUNT_TRANSACTIONS_IN_QUEUE AS trx_tobe_certified, COUNT_TRANSACTIONS_REMOTE_IN_APPLIER_QUEUE AS relaylog_tobe_applied, COUNT_TRANSACTIONS_CHECKED AS trx_chkd, COUNT_TRANSACTIONS_REMOTE_APPLIED AS trx_done, COUNT_TRANSACTIONS_LOCAL_PROPOSED AS proposed FROM performance_schema.replication_group_member_stats;'
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
| CHANNEL_NAME              | MEMBER_ID                            | MEMBER_HOST | MEMBER_PORT | MEMBER_STATE | MEMBER_ROLE | MEMBER_VERSION | MEMBER_COMMUNICATION_STACK |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
| group_replication_applier | c4c3b7e0-f71a-11ee-bd68-461a4ff55a9c | mgr-0.mgr   |        3306 | ONLINE       | PRIMARY     | 8.0.32         | XCom                       |
| group_replication_applier | cf0918f5-f71a-11ee-bcce-c2f91447731b | mgr-1.mgr   |        3306 | ONLINE       | SECONDARY   | 8.0.32         | XCom                       |
| group_replication_applier | d6493fd9-f71a-11ee-bcab-3a9fbd9e650b | mgr-2.mgr   |        3306 | ONLINE       | SECONDARY   | 8.0.32         | XCom                       |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
+--------------------------------------+--------------------+-----------------------+----------+----------+----------+
| id                                   | trx_tobe_certified | relaylog_tobe_applied | trx_chkd | trx_done | proposed |
+--------------------------------------+--------------------+-----------------------+----------+----------+----------+
| c4c3b7e0-f71a-11ee-bd68-461a4ff55a9c |                  0 |                     0 |        0 |        4 |        0 |
| cf0918f5-f71a-11ee-bcce-c2f91447731b |                  0 |                     0 |        0 |        1 |        0 |
| d6493fd9-f71a-11ee-bcab-3a9fbd9e650b |                  0 |                     0 |        0 |        0 |        0 |
+--------------------------------------+--------------------+-----------------------+----------+----------+----------+
++ exit 0
```
可以看到，一个包含3个节点的MGR集群构建完毕。


## 免责声明
因个人水平有限，专栏中难免存在错漏之处，请勿直接复制文档中的命令、方法直接应用于线上生产环境。请读者们务必先充分理解并在测试环境验证通过后方可正式实施，避免造成生产环境的破坏或损害。

## 联系我们
---
扫码关注微信公众号

![输入图片说明](../greatsql-wx.jpg)
