#! /bin/bash

configPath=config.properties

mongodb_home=`awk -F= -v k=mongodbHome '{ if ( $1 == k ) print $2; }' $configPath`
template=`awk -F= -v k=template '{ if ( $1 == k ) print $2; }' $configPath`
templatePath=template/$template.conf
ips=`awk -F= -v k=ips '{ if ( $1 == k ) print $2; }' $configPath`
eval $(echo $ips | awk '{split($0, arr, ","); for(i in arr) print "ipArray["i"]="arr[i]}')

#获取所有的配置、路由、分片
nodes=`awk -F= -v k=nodes '{ if ( $1 == k ) print $2; }' $templatePath`
eval $(echo $nodes | awk '{split($0, nodeArr, ","); for(i in nodeArr) print "nodeArray["i"]="nodeArr[i]}')
param=$1

if [[ $param = "cs" ]]
then    
    #自动化设置配置副本集
    config_numbers=""
    ccount=0
    config_port=`awk -F= -v k=config_port '{ if ( $1 == k ) print $2; }' $templatePath`
    configs=`awk -F= -v k=config '{ if ( $1 == k ) print $2; }' $templatePath`
    eval $(echo $configs | awk '{split($0, configArr, ","); for(i in configArr) print "configArray["i"]="configArr[i]}')
    configMasterNode=${configArray[1]}
    echo "configMasterNode: $configMasterNode"
    #删除node，保留右边字符
    configMasterIpNum=${configMasterNode#*node}
    #echo "configMasterIpNum: $configMasterIpNum"
    configMasterIp=${ipArray[$configMasterIpNum]}
    #echo "configMasterIp: $configMasterIp"
    for((i=1; i<=${#configArray[@]}; i++))
    do
       configNode=${configArray[i]}
       #删除node，保留右边字符
       configIpNum=${configNode#*node}
       config_numbers=$config_numbers"{_id : $ccount, host : '${ipArray[$configIpNum]}:$config_port'},"
       ccount=`expr $ccount + 1`
    done
    #删除最后一个,保留左边字符
    echo "********************************设置config副本集********************************"
    config_numbers=${config_numbers%,*}
    echo $config_numbers
    $mongodb_home/bin/mongo $configMasterIp:$config_port/admin << EOF
config = {_id : "configs", members : [ $config_numbers ] };
rs.initiate(config);
EOF

    #自动化设置分片shard副本集
    for node in ${nodeArray[*]}
    do
       if [[ $node =~ "shard"  ]]         
       then
           shard_numbers=""
           shardMasterIp=""
           scount=0
           shard_port=`awk -F= -v k=$node"_port" '{ if ( $1 == k ) print $2; }' $templatePath`
           shards=`awk -F= -v k=$node '{ if ( $1 == k ) print $2; }' $templatePath`
           eval $(echo $shards | awk '{split($0, shardArr, ","); for(i in shardArr) print "shardArray["i"]="shardArr[i]}')
           for((i=1; i<=${#shardArray[@]}; i++))
           do
              shardNode=${shardArray[i]}
              #echo "shardNode: $shardNode"
              #删除node，保留右边字符
              shardIpNum=${shardNode#*node}
              #echo "shardIpNum: $shardIpNum"
              if [[ $scount = 0 ]]
              then
                  shardMasterIp=${ipArray[$shardIpNum]}
                  shard_numbers=$shard_numbers"{_id : $scount, host : '${ipArray[$shardIpNum]}:$shard_port', priority : 2},"
              fi
              if [[ $scount = 1 ]]
              then
                  shard_numbers=$shard_numbers"{_id : $scount, host : '${ipArray[$shardIpNum]}:$shard_port', priority : 1},"
              fi
              if [[ $scount = 2 ]]
              then
                  shard_numbers=$shard_numbers"{_id : $scount, host : '${ipArray[$shardIpNum]}:$shard_port', arbiterOnly : true}"
              fi
              scount=`expr $scount + 1`
           done
              #echo "shard_numbers: $shard_numbers"
              echo "********************************设置$node副本集********************************"
              $mongodb_home/bin/mongo $shardMasterIp:$shard_port/admin << EOF
config = {_id : "$node", members : [ $shard_numbers ] };
rs.initiate(config);
EOF
       fi
    done
fi

if [[ $param = "mongos" ]]
then  
    #自动化设置路由分片
    mongos_numbers=""
    mongos_port=`awk -F= -v k=mongos_port '{ if ( $1 == k ) print $2; }' $templatePath`
    mongoss=`awk -F= -v k=mongos '{ if ( $1 == k ) print $2; }' $templatePath`
    eval $(echo $mongoss | awk '{split($0, mongosArr, ","); for(i in mongosArr) print "mongosArray["i"]="mongosArr[i]}')
    mongosNode=${mongosArray[1]}
    #删除node，保留右边字符
    mongosIpNum=${mongosNode#*node}
    mongosIp=${ipArray[$mongosIpNum]}
    for node in ${nodeArray[*]}
    do
       if [[ $node =~ "shard" ]]    
       then
           shard_numbers=""
           shard_port=`awk -F= -v k=$node"_port" '{ if ( $1 == k ) print $2; }' $templatePath`
           shards=`awk -F= -v k=$node '{ if ( $1 == k ) print $2; }' $templatePath`
           eval $(echo $shards | awk '{split($0, shardArr, ","); for(i in shardArr) print "shardArray["i"]="shardArr[i]}')
           for((i=1; i<=${#shardArray[@]}; i++))
           do
              shardNode=${shardArray[i]}
              #删除node，保留右边字符
              shardIpNum=${shardNode#*node}
              shardIp=${ipArray[$shardIpNum]}
              shard_numbers=$shard_numbers$shardIp:$shard_port","
           done
           shard_numbers=${shard_numbers%,*}
           echo "mongos add $node shard_numbers:"$shard_numbers
           echo "********************************添加mongos分片$node********************************"
           $mongodb_home/bin/mongo $mongosIp:$mongos_port/admin << EOF
sh.addShard("$node/$shard_numbers");
EOF
       fi  
    done
    $mongodb_home/bin/mongo $mongosIp:$mongos_port/admin << EOF
sh.status();
EOF
fi
