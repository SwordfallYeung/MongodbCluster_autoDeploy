#! /bin/bash

configPath=config.properties
mongodb_home=`awk -F= -v k=mongodbHome '{ if ( $1 == k ) print $2; }' $configPath`
clusterDataPath=`awk -F= -v k=clusterDataPath '{ if ( $1 == k ) print $2; }' $configPath`
param=$1

#config
if [[ $param = "config" ]]
then
   $mongodb_home/bin/mongod -f $clusterDataPath/conf/config.conf
fi
if [[ $param = "config_numa" ]]
then
   numactl --interleave=all $mongodb_home/bin/mongod -f $clusterDataPath/conf/config.conf
fi

#shard1
paramLegth=`echo "$param" |wc -L`
if [[ ($param =~ "shard") && ($paramLegth -lt 11) && ($paramLegth -gt 5)]]
then
   $mongodb_home/bin/mongod -f $clusterDataPath/conf/$param.conf
fi
if [[ ($param =~ "shard") && $param =~ "numa" ]]
then
   shardName=${param%_*}
   numactl --interleave=all $mongodb_home/bin/mongod -f $clusterDataPath/conf/$shardName.conf
fi

#mongos
if [[ $param = "mongos" ]]
then
   $mongodb_home/bin/mongos -f $clusterDataPath/conf/mongos.conf
fi
