#!/bin/sh

# 创建EMR客户端节点，当前支持创建Haoop，Hive，Hbase，Presto，Flink 客户端


# 从EMR Master点同步emr-apps.repo，emr-platform.repo 
# 之后将使用yum安装客户端
makeYumRepo(){
	# 创建yum repoPub
	pemFile="$1"
 	masterNode="$2"
  	checkParma "$pemFile" "$masterNode"
	sudo mkdir -p /var/aws/emr/
	# 拷贝yum repoPublicKey
	sudo rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -i $pemFile" hadoop@$masterNode:'/var/aws/emr/repoPublicKey.txt' /var/aws/emr/
	# 拷贝emr集群yum源，安装emr同版本组件
	sudo rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -i $pemFile" hadoop@$masterNode:'/etc/yum.repos.d/emr-apps.repo' /etc/yum.repos.d/
	sudo rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -i $pemFile" hadoop@$masterNode:'/etc/yum.repos.d/emr-platform.repo' /etc/yum.repos.d/

}

# 创建Hadoop用户
makeHadoopUser(){
	createUser=hadoop
	createGroup=hadoop
	sudo getent group $createGroup &>/dev/null ||sudo groupadd $createGroup
	sudo id -u $createUser &>/dev/null ||sudo useradd -g $createGroup $createUser
	# enable all users of bdp group can as hdfs
	echo "$createUser ALL = (ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$createUser  > /dev/null

	sudo mkdir -p /home/$createUser/.ssh
	sudo chown $createUser:$createGroup /home/$createUser/.ssh
	sudo chmod 700 /home/$createUser/.ssh
	sudo cp $pemFile /home/$createUser/.ssh/id_isa
	sudo chown $createUser:$createGroup /home/$createUser/.ssh/id_isa
	sudo chmod 600 /home/$createUser/.ssh/id_isa
}


# 从EMR集群同步JRE，并将Java配置到环境变量
makeJre(){
	# 拷贝JRE
	pemFile="$1"
 	masterNode="$2"
  	checkParma "$pemFile" "$masterNode"
	sudo mkdir -p /etc/alternatives/jre
	sudo rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -i $pemFile" hadoop@$masterNode:'/etc/alternatives/jre/*' /etc/alternatives/jre/
	# 配置jre 环境变量
sudo tee /etc/profile.d/java.sh <<EOF
export JAVA_HOME=/etc/alternatives/jre
EOF
	source /etc/profile
	echo "export PATH=$JAVA_HOME/bin:$PATH" | sudo tee -a /etc/profile.d/java.sh  > /dev/null
	source /etc/profile
}

# 安装hadoop client
makeHadoopClient(){
	# hadoop client
	pemFile="$1"
 	masterNode="$2"
  	checkParma "$pemFile" "$masterNode"
	sudo mkdir -p  /etc/hadoop/
	sudo yum -y install hadoop-client hadoop-lzo
	sudo rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -i $pemFile" hadoop@$masterNode:'/etc/hadoop/*' /etc/hadoop/
}

# 安装hive client
makeHiveClient(){
	# Hive Client
	pemFile="$1"
 	masterNode="$2"
  	checkParma "$pemFile" "$masterNode"
	sudo mkdir -p /etc/hive/
	sudo mkdir -p /etc/hive-hcatalog/
	sudo mkdir -p /etc/tez/
	sudo yum -y install tez hive hive-hcatalog
	sudo rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -i $pemFile" hadoop@$masterNode:'/etc/hive/*' /etc/hive/
	sudo rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -i $pemFile" hadoop@$masterNode:'/etc/hive-hcatalog/*' /etc/hive-hcatalog/
	sudo rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -i $pemFile" hadoop@$masterNode:'/etc/tez/*' /etc/tez/
	sudo mkdir -p /var/log/hive/user
	sudo chmod 777 -R /var/log/hive/user
	makeEMRFS "$pemFile" "$masterNode"
}

# 创建EMRFS
makeEMRFS(){
	pemFile="$1"
 	masterNode="$2"
  	checkParma "$pemFile" "$masterNode"
	sudo yum  -y install emrfs
	sudo yum -y  install s3-dist-cp
	sudo rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -i $pemFile" hadoop@$masterNode:'/usr/share/aws/emr/emrfs/conf/*' /usr/share/aws/emr/emrfs/conf/
}

# 创建Hbase
makeHBaseClient(){
	pemFile="$1"
 	masterNode="$2"
  	checkParma "$pemFile" "$masterNode"
	sudo yum install  -y hbase
	sudo mkdir -p /etc/hbase
	sudo rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -i $pemFile" hadoop@$masterNode:'/etc/hbase/*' /etc/hbase/
	sudo mkdir -p /var/log/hbase
	sudo chmod 777 -R /var/log/hbase
}

# 创建Hbase
makePrestoClient(){
	pemFile="$1"
 	masterNode="$2"
 	checkParma "$pemFile" "$masterNode"
	sudo yum install -y presto
	sudo mkdir -p  /etc/presto/conf
	sudo rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -i $pemFile" hadoop@$masterNode:'/etc/presto/conf/presto-env.sh' /etc/presto/conf/
}

makeFlinkClient(){
	pemFile="$1"
 	masterNode="$2"
 	checkParma "$pemFile" "$masterNode"
	sudo yum install -y flink
	sudo mkdir -p  /etc/flink
	sudo rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -i $pemFile" hadoop@$masterNode:'/etc/flink/*' /etc/flink/
	sudo mkdir  -p /var/lib/flink/yarn/
	sudo chmod 777 /var/lib/flink/yarn
}



# 创建必要的目录
makeDir(){
	sudo mkdir -p /mnt/s3
	sudo chmod 777 -R /mnt/s3
	sudo mkdir -p /mnt/tmp
	sudo chmod 777 -R /mnt/tmp
}



# Run the below commands as root
if [ "$USER" != "root" ]; then
  echo "Run me with root user!"
  exit 1
fi


showUsage() {
  printHeading "[ MAKE EMR GATEWAY ] USAGE "

  echo "# init ,install jre,sync repo from  emr master node ,create tmp dir"
  echo "$0 init [PEM_FILE_PATH] [MASTER_NODE_IP]"
  echo

  echo "# create hadoop client"
  echo "$0 make-hadoop-client [PEM_FILE_PATH] [MASTER_NODE_IP]"
  echo

  echo "# create hive client"
  echo "$0 make-hive-client [PEM_FILE_PATH] [MASTER_NODE_IP]"
  echo

  echo "# create hbase client"
  echo "$0 make-hbase-client [PEM_FILE_PATH] [MASTER_NODE_IP]"
  echo

  echo "# create presto client"
  echo "$0 make-presto-client [PEM_FILE_PATH] [MASTER_NODE_IP]"
  echo

  echo "# create flink client"
  echo "$0 make-flink-client [PEM_FILE_PATH] [MASTER_NODE_IP]"
  echo
}

printHeading() {
  title="$1"
  paddingWidth=$((($(tput cols) - ${#title}) / 2 - 3))
  printf "\n%${paddingWidth}s" | tr ' ' '='
  printf "  $title  "
  printf "%${paddingWidth}s\n" | tr ' ' '='
  printf "使用脚本安装的前提条件: 1. 当前系统的的AMI(或者根AMI)是Amazon Linux 2 \n 2. 客户端EC2可以 SSH 到EMR Master，端口22 \n 3. 客户端EC2需要EMR集群Role(根据需要调整), 并且能和集群个节点通信 \n 一下任何一个命令都可多次运行，包括init"
  printf "\n"
}

checkParma(){
  pemFile="$1"
  masterNode="$2"
  if  [ ! "$pemFile" ] || [ ! "$pemFile" ] ;then
    echo "pem 文件路径和emr主节点IP(或域名)是必须的参数"
    exit
  fi 
}


init() {
  pemFile="$1"
  masterNode="$2"
  checkParma "$pemFile" "$masterNode"
  chmod 600 "$pemFile"
  makeYumRepo "$pemFile" "$masterNode"
  makeHadoopUser 
  makeDir
  makeJre "$pemFile" "$masterNode"
}

makeAllClient() {
  echo "make hadoop,hive,hbase,preso,flink  client."
  pemFile="$1"
  masterNode="$2"
  checkParma "$pemFile" "$masterNode"
  init "$pemFile" "$masterNode"
  makeHadoopClient "$pemFile" "$masterNode"
  makeHiveClient  "$pemFile" "$masterNode"
  makeHBaseClient "$pemFile" "$masterNode"
  makePrestoClient "$pemFile" "$masterNode"
  makeFlinkClient "$pemFile" "$masterNode"
}



case $1 in
  init)
    shift
    init "$@"
    ;;
  make-hadoop-user)
    shift
  	makeHadoopUser "$@"
    ;;
  make-hadoop-client)
    shift
  	makeHadoopClient "$@"
    ;;
  make-hive-client)
    shift
    makeHiveClient "$@"
    ;;
  make-hbase-client)
    shift
    makeHBaseClient "$@"
    ;;
  make-presto-client)
    shift
    makePrestoClient "$@"
    ;;
  make-flink-client)
    shift
    makeFlinkClient "$@"
    ;;
  make-all-client)
    shift
    makeAllClient "$@"
    ;;
  help)
    showUsage
    ;;
  *)
    showUsage
    ;;
esac

