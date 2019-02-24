#! /bin/bash

configPath=config.properties
#从config.properties文件读取数据出来
clusterDataPath=`awk -F= -v k=clusterDataPath '{ if ( $1 == k ) print $2; }' $configPath`
mongodb_home=`awk -F= -v k=mongodbHome '{ if ( $1 == k ) print $2; }' $configPath`
template=`awk -F= -v k=template '{ if ( $1 == k ) print $2; }' $configPath`
ips=`awk -F= -v k=ips '{ if ( $1 == k ) print $2; }' $configPath`
user=`awk -F= -v k=user '{ if ( $1 == k ) print $2; }' $configPath`
hostname=`hostname`
localIp=`cat /etc/hosts | grep $hostname | awk -F " " '{print $1}'`
#localIp=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6 | awk '{print $2}' | tr -d "addr:"`
templatePath=template/$template.conf

#获取所有的配置、路由、分片
nodes=`awk -F= -v k=nodes '{ if ( $1 == k ) print $2; }' $templatePath`
eval $(echo $nodes | awk '{split($0, nodeArr, ","); for(i in nodeArr) print "nodeArray["i"]="nodeArr[i]}')

#ips切割为数组array
eval $(echo $ips | awk '{split($0, arr, ","); for(i in arr) print "ipArray["i"]="arr[i]}')

suffix=""
#判断linux系统cpu是否为numa架构
numaCount=`grep -i numa /var/log/dmesg | wc -l`
nodeCount=`grep -i numa /var/log/dmesg | grep -wi "node" | wc -l`
offCount=`grep -i numa /var/log/dmesg | grep -wi "numa=off" | wc -l`
if [[ ($numaCount -gt 1) && ($nodeCount -gt 1) && ($offCount -eq 0) ]]
then
    suffix="_numa"
fi

#轮询启动mongodb的节点，先config，后shard，再mongos
for n in ${nodeArray[*]}
do
   if [[ $n = "mongos" ]]
   then
      if [[ $1 = "" ]]
      then
         mongoss=`awk -F= -v k=mongos '{ if ( $1 == k ) print $2; }' $templatePath`
         eval $(echo $mongoss | awk '{split($0, mongosArr, ","); for(i in mongosArr) print "mongosArray["i"]="mongosArr[i]}')
         for((i=1; i<=${#mongosArray[@]}; i++))
         do
            mongosNode=${mongosArray[i]}
            #删除node，保留右边字符
            mongosIpNum=${mongosNode#*node}
            mongosIp=${ipArray[$mongosIpNum]}
            echo "********************************start $mongosIp $n********************************"
            #启动本地服务或ssh远程调用
            if [[ $localIp = $mongosIp ]]
            then
                $mongodb_home/shell/autoStartUp.sh $n
            else
                ssh $user@$mongosIp "cd $mongodb_home/shell && ./autoStartUp.sh $n"
            fi
         done
         
         #mongos也启动，即mongodb集群全启动
         #查看/etc/crontab是否开启定时任务，没有则开启
         for((i=1; i<=${#ipArray[@]}; i++))
         do
           if [[ $localIp = ${ipArray[i]} ]]
           then
              echo "*****start ${ipArray[i]} 定时任务:日志切割和mongo进程存活监控*****"
              $mongodb_home/shell/autoConfig.sh addCronTask
           else
              echo "*****start ${ipArray[i]} 定时任务:日志切割和mongo进程存活监控*****"
              ssh $user@${ipArray[i]} "cd $mongodb_home/shell && $mongodb_home/shell/autoConfig.sh addCronTask"
           fi
         done
      fi
   else   
      shards=`awk -F= -v k=$n '{ if ( $1 == k ) print $2; }' $templatePath`
      eval $(echo $shards | awk '{split($0, shardArr, ","); for(i in shardArr) print "shardArray["i"]="shardArr[i]}')
      for((i=1; i<=${#shardArray[@]}; i++))
      do
         shardNode=${shardArray[i]}
         #删除node，保留右边字符
         shardIpNum=${shardNode#*node}
         shardIp=${ipArray[$shardIpNum]}
         echo "********************************start $shardIp $n********************************"
         #启动本地服务或ssh远程调用
         if [[ $localIp = $shardIp ]]
         then
             $mongodb_home/shell/autoStartUp.sh $n$suffix
         else
             ssh $user@$shardIp "cd $mongodb_home/shell && ./autoStartUp.sh $n$suffix"
         fi
      done
   fi
done
