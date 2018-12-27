#! /bin/bash

#适用于3台或5台机器搭建15个或20个节点的mongodb高可用集群，3个或5个分片，每个分片（1主+1副+1仲裁）、3个配置、3个或2个路由
configPath=config.properties
#从config.properties文件读取数据出来
template=`awk -F= -v k=template '{ if ( $1 == k ) print $2; }' $configPath`
clusterPath=`awk -F= -v k=clusterPath '{ if ( $1 == k ) print $2; }' $configPath`
mongodb_home=`awk -F= -v k=mongodbHome '{ if ( $1 == k ) print $2; }' $configPath`

function createConfig()
{
   ips=`awk -F= -v k=ips '{ if ( $1 == k ) print $2; }' $configPath`
   localIp=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6 | awk '{print $2}' | tr -d "addr:"`
 
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
 
  if [[ -d $clusterPath/conf ]]
  then 
     rm -rf $clusterPath/conf
  fi
  
  #创建配置文件夹
  mkdir -p $clusterPath/conf  
}

function createMongosFoldersConf()
{
 #创建mongos路由服务器的日志文件夹log、进程文件夹pid
  mkdir -p $clusterPath/mongos/log
  mkdir -p $clusterPath/mongos/pid  

  #设置路由服务器
  cat >> $clusterPath/conf/mongos.conf << EOF
logpath=$clusterPath/mongos/log/mongos.log
pidfilepath=$clusterPath/mongos/pid/mongos.pid
logappend=true
bind_ip=$localIp
port=$1
fork=true
#监听的配置服务器，只能有1个或3个  configs为配置服务器的副本集名字
configdb=configs/$2
#设置最大连接数
maxConns=20000
EOF

}

function createConfigFoldersConf()
{
  #创建config配置服务器的数据文件夹data、日志文件夹log、进程文件夹pid
  mkdir -p $clusterPath/config/data
  mkdir -p $clusterPath/config/log
  mkdir -p $clusterPath/config/pid
 
   #设置配置服务器副本集
  cat >> $clusterPath/conf/config.conf << EOF
dbpath=$clusterPath/config/data
logpath=$clusterPath/config/log/config.log
pidfilepath=$clusterPath/config/pid/config.pid
directoryperdb=true
logappend=true
bind_ip=$localIp
port=$1
oplogSize=10000
fork=true
noprealloc=true
#副本集名称
replSet=configs
#declare this is a shard db of a cluster
configsvr=true
#设置最大连接数
maxConns=20000
EOF
}

function createShardFoldersConf()
{
  #创建shard1分片服务器的数据文件夹data、日志文件夹log、进程文件夹pid
  mkdir -p $clusterPath/$1/data
  mkdir -p $clusterPath/$1/log
  mkdir -p $clusterPath/$1/pid

  #设置第一个分片副本集
  cat >> $clusterPath/conf/$1.conf << EOF
dbpath=$clusterPath/$1/data
logpath=$clusterPath/$1/log/$1.log
pidfilepath=$clusterPath/$1/pid/$1.pid
directoryperdb=true
logappend=true
bind_ip=$localIp
port=$2
oplogSize=10000
fork=true
noprealloc=true
#副本集名称
replSet=$1
#declare this is a shard db of a cluster
shardsvr=true
#设置最大连接数
maxConns=20000
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
       echo "0 0 * * * root $ongodb_home/shell/autoLogRotate.sh $mongodb_home/shell > /dev/null 2>&1 &" >> $cronfile
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
