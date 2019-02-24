#! /bin/bash

#适用于3台或5台机器搭建15个或20个节点的mongodb高可用集群，3个或5个分片，每个分片（1主+1副+1仲裁）、3个配置、3个或2个路由
configPath=config.properties
#从config.properties文件读取数据出来
template=`awk -F= -v k=template '{ if ( $1 == k ) print $2; }' $configPath`
clusterDataPath=`awk -F= -v k=clusterDataPath '{ if ( $1 == k ) print $2; }' $configPath`
clusterLogPath=`awk -F= -v k=clusterLogPath '{ if ( $1 == k ) print $2; }' $configPath`
mongodb_home=`awk -F= -v k=mongodbHome '{ if ( $1 == k ) print $2; }' $configPath`

function createConfig()
{
   ips=`awk -F= -v k=ips '{ if ( $1 == k ) print $2; }' $configPath`
   hostname=`hostname`
   localIp=`cat /etc/hosts | grep $hostname | awk -F " " '{print $1}'`
   #localIp=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6 | awk '{print $2}' | tr -d "addr:"`
 
   #配置mongodb_home
   #echo "配置mongodb_home"
   #editMongodbHome

   #创建conf文件夹
   echo "********************************创建conf文件夹********************************"
   createConfFolders

   eval $(echo $ips | awk '{split($0, arr, ","); for(i in arr) print "ipArray["i"]="arr[i]}')
   templatePath=template/$template.conf
   #遍历ip数组
   for((i=1; i<=${#ipArray[@]}; i++))
   do
      if [[ $localIp = ${ipArray[i]} ]]
      then
          nodes=`awk -F= -v k=node$i '{ if ( $1 == k ) print $2; }' $templatePath`
          echo "********************************${ipArray[i]}:$nodes********************************"
          eval $(echo $nodes | awk '{split($0, nodeArr, ","); for(i in nodeArr) print "nodeArray["i"]="nodeArr[i]}')
          for node in ${nodeArray[*]}
          do
            port=`awk -F= -v k=$node"_port" '{ if ( $1 == k ) print $2; }' $templatePath`
            case "$node" in
                 "config")
                         #创建config配置文件
                         echo "***************创建config配置文件***************"
                         createConfigFoldersConf $port
                         ;;
                 "mongos")
                         #创建mongos路由配置文件
                         echo "***************创建mongos路由配置文件***************"
                         configPort=`awk -F= -v k=config_port '{ if ( $1 == k ) print $2; }' $templatePath`
                         getConfigsIpsPort $configPort 
                         createMongosFoldersConf $port $ipsAndPorts
                         ;;
            esac
          
            if [[ $node =~ "shard"  ]]
            then
                #创建shard分片配置文件
                echo "***************创建$node分片配置文件***************"
                createShardFoldersConf $node $port
            fi
          done
      fi
   done
}

function getConfigsIpsPort()
{
 ipsAndPorts=""
 for((i=1; i<=${#ipArray[@]}; i++))
 do
   nodes=`awk -F= -v k=node$i '{ if ( $1 == k ) print $2; }' $templatePath`
   if [[ $nodes =~ "config" ]]
   then
       ipsAndPorts=$ipsAndPorts"${ipArray[i]}:$1,"
   fi
 done
 ipsAndPorts=${ipsAndPorts%,*}
}

#为每台机器创建6个目录，shard1、shard2、shard3、config、mongos、conf
function createConfFolders()
{
 
  if [[ -d $clusterDataPath/conf ]]
  then 
     rm -rf $clusterDataPath/conf
  fi
  
  #创建配置文件夹
  mkdir -p $clusterDataPath/conf  
}

function createMongosFoldersConf()
{
 #创建mongos路由服务器的日志文件夹log、进程文件夹pid
  mkdir -p $clusterLogPath/mongos/log
  mkdir -p $clusterDataPath/mongos/pid  

  #设置路由服务器
  cat >> $clusterDataPath/conf/mongos.conf << EOF
systemLog:
  destination: file
  path: $clusterLogPath/mongos/log/mongos.log
  logAppend: true
processManagement:
  fork: true
  pidFilePath: $clusterDataPath/mongos/pid/mongos.pid
net:
  bindIp: $localIp
  port: $1
  maxIncomingConnections: 20000
sharding:
  configDB: configs/$2
EOF

}

function createConfigFoldersConf()
{
  #创建config配置服务器的数据文件夹data、日志文件夹log、进程文件夹pid
  mkdir -p $clusterDataPath/config/data
  mkdir -p $clusterLogPath/config/journal
  mkdir -p $clusterLogPath/config/log
  mkdir -p $clusterDataPath/config/pid

  #把数据目录的journal日志映射到日志目录里面
  ln -s $clusterLogPath/config/journal $clusterDataPath/config/data/journal
 
  #设置配置服务器副本集
  cat >> $clusterDataPath/conf/config.conf << EOF
systemLog:
  destination: file
  path: $clusterLogPath/config/log/config.log
  logAppend: true 
processManagement:
  fork: true
  pidFilePath: $clusterDataPath/config/pid/config.pid
net:
  bindIp: $localIp
  port: $1
  maxIncomingConnections: 20000
storage:
  dbPath: $clusterDataPath/config/data
  journal:
    enabled: true
    commitIntervalMs: 500
  directoryPerDB: true
  syncPeriodSecs: 300
  engine: wiredTiger
replication:
  oplogSizeMB: 10000
  replSetName: configs
sharding:
  clusterRole: configsvr
EOF
}

function createShardFoldersConf()
{
  #创建shard1分片服务器的数据文件夹data、日志文件夹log、进程文件夹pid
  mkdir -p $clusterDataPath/$1/data
  mkdir -p $clusterLogPath/$1/journal
  mkdir -p $clusterLogPath/$1/log
  mkdir -p $clusterDataPath/$1/pid

  #把数据目录的journal日志映射到日志目录里面
  ln -s $clusterLogPath/$1/journal $clusterDataPath/$1/data/journal

  #设置第一个分片副本集
  cat >> $clusterDataPath/conf/$1.conf << EOF
systemLog:
  destination: file
  path: $clusterLogPath/$1/log/$1.log
  logAppend: true
processManagement:
  fork: true
  pidFilePath: $clusterDataPath/$1/pid/$1.pid
net:
  bindIp: $localIp
  port: $2
  maxIncomingConnections: 20000
storage:
  dbPath: $clusterDataPath/$1/data
  journal: 
    enabled: true
    commitIntervalMs: 500
  directoryPerDB: true
  syncPeriodSecs: 300
  engine: wiredTiger
  wiredTiger:
    engineConfig:
      cacheSizeGB: 103
      statisticsLogDelaySecs: 0
      journalCompressor: snappy
      directoryForIndexes: false
    collectionConfig:
      blockCompressor: snappy
    indexConfig:
      prefixCompression: true
replication:
  oplogSizeMB: 10000
  replSetName: $1
sharding:
  clusterRole: shardsvr
EOF
}

#配置mongodb环境变量
function editMongodbHome()
{
  profile=/etc/profile
  #配置MONGODB_HOME
  sed -i "/^export MONGODB_HOME/d" $profile
  echo "export MONGODB_HOME=$mongodb_home" >> $profile
  
  #配置PATH
  sed -i "/^export PATH=\$PATH:\$MONGODB_HOME\/bin/d" $profile
  echo "export PATH=\$PATH:\$MONGODB_HOME/bin" >> $profile

  #使/etc/profile文件生效
  source /etc/profile
}

if [[ $1 = "" ]]
then
   createConfig
fi

if [[ $1 = "addCronTask" ]]
then
   cronfile=/etc/crontab
   shellPath=${mongodb_home//\//\\/}\\/shell
   logRotateCronTaskNum=`sed -n -e "/\0 \0 \* \* \* root $shellPath\/autoLogRotate.sh $shellPath/=" $cronfile`
   if [[ $logRotateCronTaskNum = "" ]]
   then
       #没有则追加
       echo "0 0 * * * root $mongodb_home/shell/autoLogRotate.sh $mongodb_home/shell > /dev/null 2>&1 &" >> $cronfile
   fi

   checkLiveCronTaskNum=`sed -n -e "/\*\/10 \* \* \* \* root $shellPath\/autoCheckLive.sh $shellPath/=" $cronfile`
   if [[ $checkLiveCronTaskNum = "" ]]
   then
       #没有则追加
       echo "*/10 * * * * root $mongodb_home/shell/autoCheckLive.sh $mongodb_home/shell > /dev/null 2>&1 &" >> $cronfile
   fi   
fi

if [[ $1 = "removeCronTask" ]]
then
   cronfile=/etc/crontab
   shellPath=${mongodb_home//\//\\/}\\/shell
   sed -i "/^\*\/10 \* \* \* \* root $shellPath\/autoCheckLive.sh $shellPath/d" $cronfile
   sed -i "/^\0 \0 \* \* \* root $shellPath\/autoLogRotate.sh $shellPath/d" $cronfile
fi
