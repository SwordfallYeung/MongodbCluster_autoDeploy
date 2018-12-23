#! /bin/bash

function createShardFolders()
{
  #创建shard1分片服务器的数据文件夹data、日志文件夹log、进程文件夹pid
  #mkdir -p ./shard$1/data
  #mkdir -p ./shard$1/log
   echo shard$1/pid

}

#createShardFolders 10

function ipsAddPort()
{
 ips="192.168.187.201,192.168.187.202,192.168.187.203"
 ipsAndPorts=${ips//,/:29040,}
 echo $ipsAndPorts:29040
}

#ipsAddPort

function scontain()
{
 if [[ "shard1" =~ "shard"  ]]
 then
     echo "包含"
 fi
}

#scontain

function stringsubtring()
{
 #s="shard2_numa"
 #echo ${s%_*}
 a="a"
 b="b"
 echo $a$b
}
#stringsubtring

function test()
{
  nodes=config,shard1,shard2,shard3,shard4,shard5,mongos
  eval $(echo $nodes | awk '{split($0, arr, ","); for(i in arr) print "nodeArray["i"]="arr[i]}')
  ips=1,2,3,4,5
  eval $(echo $ips | awk '{split($0, nodeArr, ","); for(i in nodeArr) print "array["i"]="nodeArr[i]}')
  suffix=""
  if [[ $1 = "numa" ]]
  then
     suffix="_numa"
  fi

  #轮询启动mongodb的节点，先config，后shard，再mongos
  for n in ${nodeArray[*]}
  do
    echo "启动$n"
    if [[ $n = "mongos" ]]
    then
      if [[ $1 = "" || ( $1 = "numa" && $2 = "" ) ]]
      then
         for((i=1; i<=${#array[@]}; i++))
         do
            echo "mongos"
         done
      fi
    else
      for((i=1; i<=${#array[@]}; i++))
      do
         echo ${array[i]}
      done
    fi
  done
}

#test $1 $2
function isOrNotNuma()
{
  numaCount=`grep -i numa /var/log/dmesg | wc -l`
  nodeCount=`grep -i numa /var/log/dmesg | grep -wi "node" | wc -l`
  offCount=`grep -i numa /var/log/dmesg | grep -wi "numa=off" | wc -l`
  echo $numaCount 
  echo $nodeCount
  echo $offCount
  if [[ ($numaCount -gt 0) && ($nodeCount -gt 0) && ($offCount -eq 0) ]]
  then 
     echo "包含"
  else 
     echo "不包含"
  fi
}

isOrNotNuma
