#! /bin/bash

#系统全局允许分配的最大文件句柄数
sysctl -w fs.file-max=2097152
sysctl -w fs.nr_open=2097152
echo 2097152 > /proc/sys/fs/nr_open

#允许当前会话/进程打开文件句柄数
ulimit -n 1048576

#修改fs.file-max设置到 /etc/sysctl.conf 文件:
#fs.file-max = 1048576

#修改/etc/security/limits.conf 持久化设置允许用户/进程打开文件句柄数，手动添加
#* soft nofile 1048576
#* hard nofile 1048576
#* soft nproc 524288
#* hard nproc 524288

#并发连接backlog设置
sysctl -w net.core.somaxconn=32768
sysctl -w net.ipv4.tcp_max_syn_backlog=16384
sysctl -w net.core.netdev_max_backlog=16384
#可用知名端口范围:
sysctl -w net.ipv4.ip_local_port_range='80 65535'
#sysctl -w net.core.rmem_default=262144
sysctl -w net.core.wmem_default=262144
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w net.core.optmem_max=16777216
#TCP Socket 读写 Buffer 设置:
sysctl -w net.core.rmem_default=262144
sysctl -w net.core.wmem_default=262144
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w net.core.optmem_max=16777216
sysctl -w net.ipv4.tcp_rmem='1024 4096 16777216'
sysctl -w net.ipv4.tcp_wmem='1024 4096 16777216'

#修改系统内核参数：
echo "never" > /sys/kernel/mm/transparent_hugepage/enabled
echo "never" >  /sys/kernel/mm/transparent_hugepage/defrag

#TCP 连接追踪设置:
sysctl -w net.nf_conntrack_max=1000000
sysctl -w net.netfilter.nf_conntrack_max=1000000
sysctl -w net.netfilter.nf_conntrack_tcp_timeout_time_wait=30

#修改stack size为1024，不启作用，只能手动source
#if [ `grep -c "ulimit -s 1024" /etc/profile` -eq '0' ];then
#  echo "ulimit -s 1024" >> /etc/profile
#  source /etc/profile
#fi
