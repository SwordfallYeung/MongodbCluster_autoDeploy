#! /bin/bash

configPath=config.properties
mongodb_home=`awk -F= -v k=mongodbHome '{ if ( $1 == k ) print $2; }' $configPath`
clusterPath=`awk -F= -v k=clusterPath '{ if ( $1 == k ) print $2; }' $configPath`
template=`awk -F= -v k=template '{ if ( $1 == k ) print $2; }' $configPath`
templatePath=template/$template.conf
user=`awk -F= -v k=user '{ if ( $1 == k ) print $2; }' $configPath`
localIp=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6 | awk '{print $2}' | tr -d "addr:"`

ips=`awk -F= -v k=ips '{ if ( $1 == k ) print $2; }' $configPath`
eval $(echo $ips | awk '{split($0, arr, ","); for(i in arr) print "ipArray["i"]="arr[i]}')

#获取所有的配置、路由、分片
nodes=`awk -F= -v k=nodes '{ if ( $1 == k ) print $2; }' $templatePath`
eval $(echo $nodes | awk '{split($0, nodeArr, ","); for(i in nodeArr) print "nodeArray["i"]="nodeArr[i]}')

#查看/etc/crontab是否开启定时任务，有则关闭
for((i=1; i<=${#ipArray[@]}; i++))
do
   if [[ $localIp = ${ipArray[i]} ]]
   then
       #kill本地的mongod、mongos
       echo "*****close ${ipArray[i]} 定时任务:日志切割和mongo进程存活监控*****"
       $mongodb_home/shell/autoConfig.sh removeCronTask
   else
       echo "*****close ${ipArray[i]} 定时任务:日志切割和mongo进程存活监控*****"
       ssh $user@${ipArray[i]} "cd $mongodb_home/shell && $mongodb_home/shell/autoConfig.sh removeCronTask"
    fi
done

if [[ $1 = "kill" ]]
then
  for((i=1; i<=${#ipArray[@]}; i++))
  do
    if [[ $localIp = ${ipArray[i]} ]]
    then
       #kill本地的mongod、mongos
       echo "*****close ${ipArray[i]} mongodb*****"
       ps -ef | grep $clusterPath/conf | grep -v grep | cut -c 9-15 | xargs kill -2
    else
       echo "*****close ${ipArray[i]} mongodb*****"
       ssh $user@${ipArray[i]} "ps -ef | grep $clusterPath/conf | grep -v grep | cut -c 9-15 | xargs kill -2"
    fi
  done
fi

if [[ $1 = "shutdown" ]]
then
  #1.先关闭mongos
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
       echo "****************close $mongosIp mongos****************"
       ps -ef | grep $clusterPath/conf/mongos.conf | grep -v grep | cut -c 9-15 | xargs kill -2
    else
       echo "****************close $mongosIp mongos****************"
       ssh $user@$mongosIp "ps -ef | grep $clusterPath/conf/mongos.conf | grep -v grep | cut -c 9-15 | xargs kill -2"
    fi
  done
  
  #2.再关闭configs
  configs=`awk -F= -v k=config '{ if ( $1 == k ) print $2; }' $templatePath`
  eval $(echo $configs | awk '{split($0, configArr, ","); for(i in configArr) print "configArray["i"]="configArr[i]}')
  #副本集，先关闭仲裁节点、从节点，最后关闭主节点
  for((i=${#configArray[@]}; i>=1; i--))
  do
    configNode=${configArray[i]}
    #删除node，保留右边字符
    configIpNum=${configNode#*node}
    configIp=${ipArray[$configIpNum]}
    if [[ $localIp = $configIp ]]
    then
       echo "****************close $configIp config****************"
       $mongodb_home/bin/mongod -f $clusterPath/conf/config.conf --shutdown
    else
       echo "****************close $configIp config****************"
       ssh $user@$configIp "$mongodb_home/bin/mongod -f $clusterPath/conf/config.conf --shutdown"
    fi
  done

  #3.最后关闭shards
  for node in ${nodeArray[*]}
    do
       if [[ $node =~ "shard"  ]]         
       then
           shards=`awk -F= -v k=$node '{ if ( $1 == k ) print $2; }' $templatePath`
           eval $(echo $shards | awk '{split($0, shardArr, ","); for(i in shardArr) print "shardArray["i"]="shardArr[i]}')
           #副本集，先关闭仲裁节点、从节点，最后关闭主节点
           for((i=${#shardArray[@]}; i>=1; i--))
           do
              shardNode=${shardArray[i]}
              #删除node，保留右边字符
              shardIpNum=${shardNode#*node}
              shardIp=${ipArray[$shardIpNum]}
              if [[ $localIp = $shardIp ]]
              then
                 echo "****************close $shardIp $node****************"
                 $mongodb_home/bin/mongod -f $clusterPath/conf/$node.conf --shutdown
              else
                 echo "****************close $shardIp $node****************"
                 ssh $user@$shardIp "$mongodb_home/bin/mongod -f $clusterPath/conf/$node.conf --shutdown"
              fi
           done
       fi
    done
fi
