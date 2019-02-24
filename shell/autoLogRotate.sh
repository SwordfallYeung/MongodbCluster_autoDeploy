#! /bin/bash
#Rotate the MongoDB logs to prevent a single logfile from consuming too much disk space. 

shellPath=$1
configPath=$shellPath/config.properties
#从config.properties文件读取数据出来
clusterDataPath=`awk -F= -v k=clusterDataPath '{ if ( $1 == k ) print $2; }' $configPath`
clusterLogPath=`awk -F= -v k=clusterLogPath '{ if ( $1 == k ) print $2; }' $configPath`
template=`awk -F= -v k=template '{ if ( $1 == k ) print $2; }' $configPath`
templatePath=$shellPath/template/$template.conf

ips=`awk -F= -v k=ips '{ if ( $1 == k ) print $2; }' $configPath`
eval $(echo $ips | awk '{split($0, arr, ","); for(i in arr) print "ipArray["i"]="arr[i]}')
hostname=`hostname`
localIp=`cat /etc/hosts | grep $hostname | awk -F " " '{print $1}'`
#localIp=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6 | awk '{print $2}' | tr -d "addr:"`

#代表删除7天前的备份，即只保留最近7天的备份
days=7

#遍历ip数组
for((i=1; i<=${#ipArray[@]}; i++))
do
  if [[ $localIp = ${ipArray[i]} ]]
  then
       mongodbNodes=`awk -F= -v k=node$i '{ if ( $1 == k ) print $2; }' $templatePath`
       eval $(echo $mongodbNodes | awk '{split($0, mongodbArr, ","); for(i in mongodbArr) print "mongodbArray["i"]="mongodbArr[i]}')
       for((n=1; n<=${#mongodbArray[@]}; n++))
       do
         pid=`cat $clusterDataPath/${mongodbArray[n]}/pid/${mongodbArray[n]}.pid`
         logdir=$clusterLogPath/${mongodbArray[n]}/log
         #切割日志
         /bin/kill -SIGUSR1 $pid
         find $logdir/ -mtime +$days -delete
       done
  fi
done
