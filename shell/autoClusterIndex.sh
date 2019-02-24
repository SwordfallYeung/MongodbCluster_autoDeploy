#! /bin/bash

configPath=config.properties
#从config.properties文件读取数据出来
clusterDataPath=`awk -F= -v k=clusterDataPath '{ if ( $1 == k ) print $2; }' $configPath`
mongodb_home=`awk -F= -v k=mongodbHome '{ if ( $1 == k ) print $2; }' $configPath`
ips=`awk -F= -v k=ips '{ if ( $1 == k ) print $2; }' $configPath`
hostname=`hostname`
localIp=`cat /etc/hosts | grep $hostname | awk -F " " '{print $1}'`
#localIp=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6 | awk '{print $2}' | tr -d "addr:"`
user=`awk -F= -v k=user '{ if ( $1 == k ) print $2; }' $configPath`
template=`awk -F= -v k=template '{ if ( $1 == k ) print $2; }' $configPath`
templatePath=template/$template.conf
#获取所有的配置、路由、分片
nodes=`awk -F= -v k=nodes '{ if ( $1 == k ) print $2; }' $templatePath`
eval $(echo $nodes | awk '{split($0, nodeArr, ","); for(i in nodeArr) print "nodeArray["i"]="nodeArr[i]}')
eval $(echo $ips | awk '{split($0, arr, ","); for(i in arr) print "ipArray["i"]="arr[i]}')

#遍历ip数组
for((i=1; i<=${#ipArray[@]}; i++))
do
  if [[ $localIp = ${ipArray[i]} ]]
  then
     #1.创建mongodbCluster并修改系统配置
     echo "********************************start ${ipArray[i]} autoConfig && autoSystemProperties********************************"
     $mongodb_home/shell/autoConfig.sh && $mongodb_home/shell/autoSystemProperties.sh
  else
     #把远程服务器旧的mongodb安装包删除
     ssh $user@${ipArray[i]} "rm -rf $mongodb_home"
     #把mongodb安装包拷贝到远程服务器
     scp -r $mongodb_home $user@${ipArray[i]}:$mongodb_home
     echo "********************************start ${ipArray[i]} autoConfig && autoSystemProperties********************************"
     ssh $user@${ipArray[i]} "cd $mongodb_home/shell && $mongodb_home/shell/autoConfig.sh && $mongodb_home/shell/autoSystemProperties.sh"
  fi
done

#2.mongodb集群启动config、shard1、shard2、shard3
echo "********************************start mongodb集群启动config、shard1、shard2、shard3********************************"
$mongodb_home/shell/autoClusterStartUp.sh notmongos

#3.mongodb集群配置、分片的副本集初始化
echo "********************************start mongodb集群分片和副本集初始化********************************"
$mongodb_home/shell/autoClusterInitSvr.sh cs

#4.mongodb集群启动mongos
echo "********************************start mongodb集群mongos********************************"
mongoss=`awk -F= -v k=mongos '{ if ( $1 == k ) print $2; }' $templatePath`
eval $(echo $mongoss | awk '{split($0, mongosArr, ","); for(i in mongosArr) print "mongosArray["i"]="mongosArr[i]}')
for mongosNode in ${mongosArray[*]}
do
  #删除node，保留右边字符
  mongosIpNum=${mongosNode#*node}
  mongosIp=${ipArray[$mongosIpNum]}
  if [[ $localIp = $mongosIp ]]
  then
      #1.创建mongodbCluster并修改系统配置
      echo "****************start $mongosIp mongos****************"
      $mongodb_home/shell/autoStartUp.sh mongos
  else
      echo "****************start $mongosIp mongos****************"
      ssh $user@$mongosIp "cd $mongodb_home/shell && ./autoStartUp.sh mongos"
  fi
done

#5.mongodb集群mongos初始化
echo "********************************start mongodb集群mongos初始化********************************"
$mongodb_home/shell/autoClusterInitSvr.sh mongos

#6.mongodb集群数据库表分片和初始化
echo "********************************start mongodb集群数据库表分片和初始化********************************"
$mongodb_home/shell/autoClusterShardedAndInitDB.sh

#7.mongodb集群配置定时任务：日志每天切割，保留7天日志/每隔10分钟监控mongo进程是否存活，不存活则自动拉起
for((i=1; i<=${#ipArray[@]}; i++))
do
  if [[ $localIp = ${ipArray[i]} ]]
  then
     #1.创建mongodbCluster并修改系统配置
     echo "******************************** ${ipArray[i]} 添加定时任务:日志切割和mongo存活监控 ********************************"
     $mongodb_home/shell/autoConfig.sh addCronTask    
  else
     echo "******************************** ${ipArray[i]} 添加定时任务:日志切割和mongo存活监控 ********************************"
     ssh $user@${ipArray[i]} "cd $mongodb_home/shell && $mongodb_home/shell/autoConfig.sh addCronTask"
  fi
done
