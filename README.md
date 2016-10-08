# CDH 部署实践


## 资料

- CDH 5.8.0
- CentOS 7.2 （KVM）
- 6  *  4 Cores  8GB RAM 1Gb ETernet 60GB+ SCSI 

## 前言

CDH 是市面上口碑最好，使用企业最多的 Hadoop 100% 开源发布版，使用它可以非常方便的进行集群安装，监控，升级和扩展，并且还包括了许多与特定 Hadoop 版本相兼容的其他服务如 Spark，Hbase，Hive 等。目前，市面上的安装教程关于5.8.0 的非常少，愿意参考的请看 [这里](http://www.2cto.com/net/201609/544957.html)，CDH 的部署方式主要分三种： **不受管的部署方式（unmanged）**和**受管制的部署方式（managed）**， 还有一种使用 EMC DSSD D5 专有硬件的部署方式。不受管制的部署方式安装和配置过程复杂不过灵活性很高受管制的部署方式灵活性比较低，但是整体可控，部署配置安装升级都被统一管理，统一安排，对于大型集群可控的安装方式为首选。

根据 CDH [官方文档](https://www.cloudera.com/documentation/enterprise/latest/topics/installation_installation.html#xd_583c10bfdbd326ba-7dae4aa6-147c30d0933--7f29)，CDH 5.x 受管部署方式包括以下几个部分：
- Oracle JDK
- Cloudera Manager Server and Agent packages
- Supporting database software
- CDH and managed service software

这几个部分是部署 Cloudera Manager 的必须过程，根据这4个必须过程，Cloudera 受管部署方式分为**概念验证部署**和**生产部署**，每种受管部署目的又有不同的安装方法以下做个简单介绍，详细介绍可以参考[这里](https://www.cloudera.com/documentation/enterprise/latest/topics/installation_installation.html#xd_583c10bfdbd326ba-7dae4aa6-147c30d0933--7f29) 。

- **概念验证部署：**
	- 路径 A ：全自动安装方法。顾名思义全自动，就是一键安装， Cloudera Manager 自动安装 Oracle JDK, Cloudera Manager Server, embedded PostgreSQL database, Cloudera Manager Agent, CDH, and managed service software 在集群所有主机上，省时省心省力，但是国内网速感人，基本不可行，并且这种方式不适合生产环境部署。它需要：1. root 帐号或者能够免密 sudo 的帐号。2. Cloudera Manager Server 主机能够 SSH 免密且同端口和其他主机通信。3. 每台主机必须能够有 Internet 访问能力去访问标准包库或者能够访问本地包库镜像。
	- 路径B :  使用 Parcels 或者 Packages 安装 Cloudera Manager。安装 Oracle JDK, Cloudera Manager Server, and embedded PostgreSQL database packages 在 Cloudera Manager Server 主机上。接下来安装 Oracle JDK, Cloudera Manager Agent, CDH, and managed service software，你可以选择手动安装还是通过 Cloudera Manager 自动安装。它需要：1.  Cloudera Manager Server 主机能够 SSH 免密且同端口和其他主机通信。2. 每台主机必须能够有 Internet 访问能力去访问标准包库或者能够访问本地包库镜像。

- **生产部署**：需要手动为 Cloudera Manager Server and Hive Metastore 安装和配置数据库。
	- 路径 B：使用 Parcels 或者 Packages 安装 Cloudera Manager。安装 Oracle JDK, Cloudera Manager Server 在 Cloudera Manager Server 主机上。接下来安装 Oracle JDK, Cloudera Manager Agent, CDH, and managed service software，你可以选择手动安装还是通过 Cloudera Manager 自动安装。它需要：1.  Cloudera Manager Server 主机能够 SSH 免密且同端口和其他主机通信。2. 每台主机必须能够有 Internet 访问能力去访问标准包库或者能够访问本地包库镜像。
	- 路径 C：使用 Tarballs 手动安装 Cloudera Manager。 使用 Tarballs 手动安装 Oracle JDK, Cloudera Manager Server, and Cloudera Manager Agent software，并且使用 Cloudera Manager 的 parcels 自动安装 CDH 和 managed service software。

我的部署方式采取的是生产部署的 路径 B，目标是能够在 N 台服务器（可以是物理机器，也可以是虚拟机）环境中部署 CDH 并且，在该集群中对普通用户实施基于 LDAP + NFS 的授权机制，来灵活地控制用户能够登录的客户端且在客户端之间共享用户的 Home 目录。这种部署方式将 Cloudera Manager Server 与 Hadoop 生态分开，N 台服务器需要一台物理机作为 Cloudera Manager Server，其他 N-1 台受管制的机器机器作为 Cloudera Manager Agent，以作为部署 Hadoop 生态环境的资料。以下是在开发环境的部署服务器拓扑图：[Image](http://obqnhrdkl.bkt.clouddn.com/image/png/cdh_deploy_dev.png)

其中，LDAP Server 和 NFS Server 可以考虑用另外两台服务器主机，因为怕一台主机挂了3个服务器角色全部失效，对于 NFS 方案可以改用分布式文件系统做存储以免出现服务器挂了数据丢失情况， Cloudera Manager 可以部署为高可用且具备负载均衡的模式，鉴于在开发环境，部署难度和企业规模，我并没有采用此部署方式，有兴趣的同学可以参考[这里](https://www.cloudera.com/documentation/enterprise/latest/topics/admin_cm_ha_overview.html#concept_bhl_cvc_pr)。对于 Kerberos 的验证方式，由于不知是我的配置有问题还是 CDH 本身的 BUG，HTTP 所有的 Kerberos 验证都无法顺利通过，导致几个 Hive 等 WebUI 都无法访问，并且 HUE 也无法使用 Sqoop2的 HTTP 接口，所以暂时不做介绍，待以后研究透彻再加入高安全性的 Kerberos + LDAP + 分布式文件系统的部署方式。所以，整个部署有如下几个阶段：
1. 部署 Cloudera Manager Server 和 Cloudera Manager Agent
2. 部署 Hadoop 生态系统所有所需的服务 
3. 部署 LDAP Server 和 NFS Server
4. 部署 LDAP Clients，LDAP 验证登录和 NFS 自动挂载环境
5. 配置 CDH 使用 LDAP 作为授权管理模块



## 资料准备
1. 准备 N 台主机可以是物理主机也可以是虚拟主机，为了能够自动化部署这 N 台主机，需要有一个额外的主机 X 能够与 N 台主机进行免密 ssh 通信，这可能需要用到 Puppet 等自动化运维工具来配置，使得 X 能与 N 台主机通信，具体怎么配置这里不再介绍。我的实践过程中使用的 Openstack 虚拟主机，我已经拥有了一台跳板主机 X 能够与所有虚拟主机通信了。
2. 获取我的 ansible 部署脚本

	```
mkdir ~/cdh-deployment
git clone https://git.oschina.net/luning/CDH-Deploy/tree/master ~/cdh-deployment
	```
## 部署 Cloudera Manager Server 和 Cloudera Manager Agent

1. 修改集群主机配置文件
    在 `cdh-deployment` 文件夹中的 `ansible.cfg` 包含了整个 ansible 的通用配置。
    ```
[defaults]
hostfile=staging    # 启用的主机配置文件, staging 为测试环境，production 为生产环境
host_key_checking = False    # 不提示know_hosts 的 yes or no 警告
private_key_file = /home/dev/pem/goome-dev-cloud.pem # 配置主机X 与 N 台主机通信的 key，若是公钥免密通信，这个选项可以不要
	```
修改 `staging` 的 *ansible_host* 和主机名以满足你的主机分布情况，以下是我的测试环境配置：
		
	```ini
	[cm-server] # cloudera manager server
	cm-server.novalocal ansible_host=10.0.1.114   
	
	[hadoop-controller] # hadoop 的主控节点，如 Namenode。
	hadoop-controller-1.novalocal  ansible_host=10.0.1.107 
	
	[hadoop-computation] # hadoop 的数据和计算节点，如 DataNode。
	hadoop-computation-1.novalocal ansible_host=10.0.1.110
	hadoop-computation-2.novalocal ansible_host=10.0.1.111
	hadoop-computation-3.novalocal ansible_host=10.0.1.112
	hadoop-computation-4.novalocal ansible_host=10.0.1.113
	
	[hadoop-hosts:children] # hadoop 生态系统所有主机
	hadoop-controller
	hadoop-computation
	
	[all:children] # 所有的主机
	cm-server
	hadoop-hosts
	
	[ldap-server] # ldap 服务器
	cm-server.novalocal ansible_host=10.0.1.114
	
	[nfs-server] # nfs 服务器
	cm-server.novalocal ansible_host=10.0.1.114
	
	[ldap-clients] # 需要配置 LDAP 授权登录的主机，一般是 hadoop 服务器的客户端主机 
	10.0.1.124
	10.0.1.125
	```
	你若将 cloudera manager server 的组名修改了，比如将`cm-server`修改为`cloudera-manager-server`, 则你还需要修改 `cdh.yml` 中 `- include: cm-agent.yml server={{ groups['cm-server'][0] }}` 中的 `cm-server` 为`cloudera-manager-server`。

2. 补充所需的 tarballs
	下载 Cloudera Manager Server，Cloudera Manager Agent，CDH Parcels 和 Oracle JDK ，将其打包生成 server.tar.gz, agent.tar.gz, common.tar.gz 和 parcel.tar.gz，根据 git 仓库的`.gitignore` ，将它们放在相应的目录。
	
	```
	roles/cm-server/files/server.tar.gz
	roles/cm-agent/files/agent.tar.gz
	roles/common/files/common.tar.gz
	roles/common/files/parcel.tar.gz
	```

	下面是每个 tarballs 内容：

	```bash
	[dev@vm01 luning]$ tar -tvf roles/cm-agent/files/agent.tar.gz
	-rw-rw-r-- dev/dev     8203824 2016-06-16 21:32 cloudera-manager-agent-5.8.0-1.cm580.p0.40.el7.x86_64.rpm
	[dev@vm01 luning]$ tar -tvf roles/cm-server/files/server.tar.gz
	-rw-rw-r-- dev/dev        8464 2016-06-16 21:32 cloudera-manager-server-5.8.0-1.cm580.p0.40.el7.x86_64.rpm
	[dev@vm01 luning]$ tar -tvf roles/common/files/common.tar.gz
	-rw-r--r-- dev/dev       14612 2016-09-20 03:31 epel-release-latest-7.noarch.rpm
	-rw-rw-r-- dev/dev   142039186 2016-09-20 05:56 oracle-j2sdk1.7-1.7.0+update67-1.x86_64.rpm
	-rw-rw-r-- dev/dev   548173572 2016-06-16 21:33 cloudera-manager-daemons-5.8.0-1.cm580.p0.40.el7.x86_64.rpm
	[dev@vm01 luning]$ tar -tvf roles/common/files/parcel.tar.gz
	-rwxrwxr-x dev/dev  1486884451 2016-09-18 15:00 CDH-5.8.0-1.cdh5.8.0.p0.42-el7.parcel
	-rw-r--r-- dev/dev          41 2016-09-18 15:00 CDH-5.8.0-1.cdh5.8.0.p0.42-el7.parcel.sha
	-rwxrwxr-x dev/dev       63997 2016-09-18 15:02 manifest.json
	```
	下载地址如下表：

	| 文件      |     链接 |   
	| :--------: | --------:| 
	| loudera-manager-agent-5.8.0-1.cm580.p0.40.el7.x86_64.rpm <br> cloudera-manager-server-5.8.0-1.cm580.p0.40.el7.x86_64.rpm <br> cloudera-manager-daemons-5.8.0-1.cm580.p0.40.el7.x86_64.rpm<br> oracle-j2sdk1.7-1.7.0+update67-1.x86_64.rpm |   [link](https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/5.8.0/RPMS/x86_64/) |  
|epel-release-latest-7.noarch.rpm| [link](https://mirrors.tuna.tsinghua.edu.cn/epel/epel-release-latest-7.noarch.rpm)|
|CDH-5.8.0-1.cdh5.8.0.p0.42-el7.parcel <br> CDH-5.8.0-1.cdh5.8.0.p0.42-el7.parcel.sha <sup>1</sup>  <br> manifest.json| [link](https://archive.cloudera.com/cdh5/parcels/5.8.0/)|

	使用 ansible 命令开始部署。若中间没有错误则部署成功，你可以通过 `http://cm-server.novalocal:7180`登录Cloudera Manager 的管理界面，默认用户名和密码为 admin 和 admin。
	```
	ansible-playbook -f cdh.yml -v
	```


## 部署 Hadoop 生态系统所有所需的服务
1. 在选择机器时由于我的 ansible 脚本自动启动了所有服务，所以不要取搜索机器，直接在“受管机器” Tab 下面选择机器，点“继续”
2. 不需要选择安装 JDK，因为我已经为每台主机安装好。
3. 提供root 帐号的私有 Key 或者一个可以 sudo 免密的帐号以及它的私钥，私钥可以登录 Cloudera Manager Server Host 的安装目录

2. 若 Cloudera Manager Server 部署成功，则你会在 Cloudera Manager 上部署一个 PostgreSQL 作为其和 Hive Metastrore 的支撑数据库。这个数据库是可以安装在集群内其他主机上的。这里为了方便自己安装在了 Cloudera Manager Server 上。
如果在启用某个服务的时候发现数据库无法连接，请在`/var/lib/pgsql/data/pg_hba.conf` 中加入某个角色的连接密码访问权限，并重启 `postgresql` 服务。例如你如果要启用 Hue 服务则，需要加入如下内容`host hue hue            0.0.0.0/0 md5`



## Troubleshoot

1. 问： 使用 Sqoop2 报错`java.lang.ClassNotFoundException: org.codehaus.jackson.map.JsonMappingException` 如何解决？
答：参考 [这里](http://community.cloudera.com/t5/Data-Ingestion-Integration/Sqoop-Error-Could-not-start-job/m-p/45416#M1896?eid=31&aid=1)


2. 问:  CDH 5.8.0 启用 Kerberos 导入 KDC 失败，报`addent: cannot read password`
   答：这是 5.8.0 的 `/usr/share/cmf/bin/import_credentials.sh` bug 做如下更改
   ```bash
   [root@cm-server ~]# vi /usr/share/cmf/bin/import_credentials.sh	
	--------
	SLEEP=1   ## 加入SLEEP = 1 秒
	
	# Export password to keytab
	IFS=' ' read -a ENC_ARR <<< "$ENC_TYPES"
	{
	  for ENC in "${ENC_ARR[@]}"
	  do
	    echo "addent -password -p $USER -k $KVNO -e $ENC"
	    if [ $SLEEP -eq 1 ]; then
	      sleep 1
	    fi
	    echo "$PASSWD"
	  done
	  echo "wkt $KEYTAB_OUT"
	} | ktutil
   ```

3. 问：Kerberos 的 acl 文件不被加载？
答：kill 掉 krb5kdc 和 kadmind 两个进程，重新启动。acl 配置文件：
	```
*/admin@hadoop.goome.com *
cloudera-scm@hadoop.goome.com * flume/*@hadoop.goome.com
cloudera-scm@hadoop.goome.com * hbase/*@hadoop.goome.com
cloudera-scm@hadoop.goome.com * hdfs/*@hadoop.goome.com
cloudera-scm@hadoop.goome.com * hive/*@hadoop.goome.com
cloudera-scm@hadoop.goome.com * httpfs/*@hadoop.goome.com
cloudera-scm@hadoop.goome.com * HTTP/*@hadoop.goome.com
cloudera-scm@hadoop.goome.com * hue/*@hadoop.goome.com
cloudera-scm@hadoop.goome.com * impala/*@hadoop.goome.com
cloudera-scm@hadoop.goome.com * mapred/*@hadoop.goome.com
cloudera-scm@hadoop.goome.com * oozie/*@hadoop.goome.com
cloudera-scm@hadoop.goome.com * solr/*@hadoop.goome.com
cloudera-scm@hadoop.goome.com * sqoop/*@hadoop.goome.com
cloudera-scm@hadoop.goome.com * yarn/*@hadoop.goome.com
cloudera-scm@hadoop.goome.com * zookeeper/*@hadoop.goome.com
	```

4. 问：Zookepper 启动异常
答：UnlimitedJCEPolicy 文件补丁没有打，请参照 [这里](https://www.cloudera.com/documentation/enterprise/latest/topics/cm_sg_s2_jce_policy.html) 打上补丁。
5. 问：启动 Hue 出现`couldn't renew kerberos ticket in order to work around Kerberos 1.8.1 issue.` ? 
答： 请在 krb5.conf 的配置文件中你的 realm 中加入 `ticket_lifetime = 24h` 和
   `renew_lifetime = 7d` 。 具体参考 [这里](https://community.cloudera.com/t5/Cloudera-Manager-Installation/Hue-Kerberos-error-quot-TICKET-NOT-RENEWABLE-quot/td-p/6725) 和 [这里](http://www.cloudera.com/documentation/manager/5-1-x/Configuring-Hadoop-Security-with-Cloudera-Manager/cm5chs_enable_hue_sec_s10.html) 。



-------

[1]:  将 `CDH-5.8.0-1.cdh5.8.0.p0.42-el7.parcel.sha1` 重命名为 `CDH-5.8.0-1.cdh5.8.0.p0.42-el7.parcel.sha`
