#! /bin/bash

configPath=config.properties

mongodb_home=`awk -F= -v k=mongodbHome '{ if ( $1 == k ) print $2; }' $configPath`
ips=`awk -F= -v k=ips '{ if ( $1 == k ) print $2; }' $configPath`
template=`awk -F= -v k=template '{ if ( $1 == k ) print $2; }' $configPath`
templatePath=template/$template.conf
mongoss=`awk -F= -v k=mongos '{ if ( $1 == k ) print $2; }' $templatePath`
testDB1=`awk -F= -v k=testDB1 '{ if ( $1 == k ) print $2; }' $configPath`
testDB2=`awk -F= -v k=testDB2 '{ if ( $1 == k ) print $2; }' $configPath`
testDB3=`awk -F= -v k=testDB3 '{ if ( $1 == k ) print $2; }' $configPath`

eval $(echo $ips | awk '{split($0, arr, ","); for(i in arr) print "ipArray["i"]="arr[i]}')
eval $(echo $mongoss | awk '{split($0, mongosArr, ","); for(i in mongosArr) print "mongosArray["i"]="mongosArr[i]}')

for mongosNode in ${mongosArray[*]}
do
  #删除node，保留右边字符
  mongosIpNum=${mongosNode#*node}
  mongosIp=${ipArray[$mongosIpNum]}
  #指定数据库分片生效
  $mongodb_home/bin/mongo $mongosIp:29050/admin << EOF
db.runCommand({enablesharding : "$testDB1"});
db.runCommand({shardcollection : "$testDB1.account", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$testDB1.alarm", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$testDB1.blackClass", key : {_id : "hashed"}});
db.runCommand({enablesharding : "$testDB2"});
db.runCommand({shardcollection : "$testDB2.device", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$testDB2.deviceParam", key : {_id : "hashed"}});
db.runCommand({enablesharding : "$testDB3"});
db.runCommand({shardcollection : "$testDB3.blackImsiFace", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$testDB3.face", key : {_id : "hashed"}});
EOF
done

mongosInitNode=${mongosArray[1]}
#删除node，保留右边字符
mongosInitIpNum=${mongosInitNode#*node}
mongosInitIp=${ipArray[$mongosInitIpNum]}
port=`awk -F= -v k=mongos_port '{ if ( $1 == k ) print $2; }' $templatePath`

#初始化数据库
initDBPath=$mongodb_home/shell
#解压initConfig.zip包 -o:不提示的情况下覆盖文件，-d /opt:指明将文件解压缩到/opt目录
unzip -o -d $initDBPath/initConfig $initDBPath/initConfig.zip
$MONGODB_HOME/bin/mongorestore --host $mongosInitIp:$port --authenticationDatabase admin -d $testDB1 $initDBPath/initConfig/testDB1
$MONGODB_HOME/bin/mongorestore --host $mongosInitIp:$port --authenticationDatabase admin -d $testDB2 $initDBPath/initConfig/testDB2
$MONGODB_HOME/bin/mongorestore --host $mongosInitIp:$port --authenticationDatabase admin -d $testDB3 $initDBPath/initConfig/testDB3
