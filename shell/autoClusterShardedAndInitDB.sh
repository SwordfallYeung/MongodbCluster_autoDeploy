#! /bin/bash

configPath=config.properties

mongodb_home=`awk -F= -v k=mongodbHome '{ if ( $1 == k ) print $2; }' $configPath`
ips=`awk -F= -v k=ips '{ if ( $1 == k ) print $2; }' $configPath`
template=`awk -F= -v k=template '{ if ( $1 == k ) print $2; }' $configPath`
templatePath=template/$template.conf
mongoss=`awk -F= -v k=mongos '{ if ( $1 == k ) print $2; }' $templatePath`
mkDB=`awk -F= -v k=mkDB '{ if ( $1 == k ) print $2; }' $configPath`
faceDB=`awk -F= -v k=faceDB '{ if ( $1 == k ) print $2; }' $configPath`
fusionDB=`awk -F= -v k=fusionDB '{ if ( $1 == k ) print $2; }' $configPath`

eval $(echo $ips | awk '{split($0, arr, ","); for(i in arr) print "ipArray["i"]="arr[i]}')
eval $(echo $mongoss | awk '{split($0, mongosArr, ","); for(i in mongosArr) print "mongosArray["i"]="mongosArr[i]}')

for mongosNode in ${mongosArray[*]}
do
  #删除node，保留右边字符
  mongosIpNum=${mongosNode#*node}
  mongosIp=${ipArray[$mongosIpNum]}
  #指定数据库分片生效
  $mongodb_home/bin/mongo $mongosIp:29050/admin << EOF
db.runCommand({enablesharding : "$mkDB"});
db.runCommand({shardcollection : "$mkDB.account", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.alarm", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.blackClass", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.camera", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.case", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.collisionStatic", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.collisionTask", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.dispositionTask", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.face", key : {imsi : "hashed"}});
db.runCommand({shardcollection : "$mkDB.faceCollisionRecord", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.faceCollsionAnalyze", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.faceFollowRecord", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.faceFollowAnalyze", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.faceImage", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.faceImageExpires", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.faceImageTemp", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.faceImsiStatic", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.faceTrace", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.fileUploadHistory", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.followTask", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.ftpGroupConfig", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.hotSpotStatic", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.imageSearchTask", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.imsiCollisionRecord", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.imsiCollsionAnalyze", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.imsiDetail", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.imsiDevice", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.imsiFaceRec", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.imsiFollowAnalyze", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.imsiFollowRecord", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.imsiPersonList", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.imsiRecord", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.imsiRecordExpires", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.imsiRecordTemp", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.mobile", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.person", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.place", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.sparkJob", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.sysGroup", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.sysPermission", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.sysPermission_copy", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.sysRole", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.sysUser", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.translateImsiRecord", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.userOperateLog", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.warning", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$mkDB.warningStatic", key : {_id : "hashed"}});
db.runCommand({enablesharding : "$faceDB"});
db.runCommand({shardcollection : "$faceDB.face", key : {_id : "hashed"}});
db.runCommand({shardcollection : "$faceDB.imsiFaceRel", key : {_id : "hashed"}});
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
$mongodb_home/bin/mongorestore --host $mongosInitIp:$port --authenticationDatabase admin -d $mkDB $initDBPath/initConfig/meerkat-min
$mongodb_home/bin/mongorestore --host $mongosInitIp:$port --authenticationDatabase admin -d $faceDB $initDBPath/initConfig/face_manager
