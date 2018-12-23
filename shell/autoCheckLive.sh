#! /bin/bash

shellPath=$1
configPath=$shellPath/config.properties
#从config.properties文件读取数据出来
clusterPath=`awk -F= -v k=clusterPath '{ if ( $1 == k ) print $2; }' $configPath`
template=`awk -F= -v k=template '{ if ( $1 == k ) print $2; }' $configPath`
templatePath=$shellPath/template/$template.conf

ips=`awk -F= -v k=ips '{ if ( $1 == k ) print $2; }' $configPath`
eval $(echo $ips | awk '{split($0, arr, ","); for(i in arr) print "ipArray["i"]="arr[i]}')
localIp=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6 | awk '{print $2}' | tr -d "addr:"`

suffix=""
#判断linux系统cpu是否为numa架构
numaCount=`grep -i numa /var/log/dmesg | wc -l`
nodeCount=`grep -i numa /var/log/dmesg | grep -wi "node" | wc -l`
offCount=`grep -i numa /var/log/dmesg | grep -wi "numa=off" | wc -l`
if [[ ($numaCount -gt 1) && ($nodeCount -gt 1) && ($offCount -eq 0) ]]
then
    suffix="_numa"
fi

#遍历ip数组
for((i=1; i<=${#ipArray[@]}; i++))
do
  if [[ $localIp = ${ipArray[i]} ]]
  then
       mongodbNodes=`awk -F= -v k=node$i '{ if ( $1 == k ) print $2; }' $templatePath`
       eval $(echo $mongodbNodes | awk '{split($0, mongodbArr, ","); for(y in mongodbArr) print "mongodbArray["y"]="mongodbArr[y]}')
       for n in ${mongodbArray[*]}
       do
         pid=`cat $clusterPath/$n/pid/$n.pid`
         logdir=$clusterPath/$n/log
         #判断是否存活
         count=`ps -ef | grep $pid | grep -v grep | wc -l`
         #程序挂掉啦，启动
         if [ $count -eq 0 ];then
            cd $shellPath && $shellPath/autoStartUp.sh $n$suffix
         fi
       done
  fi
done


