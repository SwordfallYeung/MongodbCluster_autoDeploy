#! /bin/bash

hostname=`hostname`
localIp=`cat /etc/hosts | grep $hostname | awk -F " " '{print $1}'`



echo $localIp
