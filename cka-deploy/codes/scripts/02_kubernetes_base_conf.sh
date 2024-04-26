#!/bin/bash
# 功能：批量设定kubernetes的内核参数调整和软件源定制
# 版本：v0.1
# 作者：Guoxin
# 联系：lvmugua@163.com
# 使用命令：
# for i in IP1 {IP2..IPn};do scp 02_kubernetes_base_conf.sh root@10.0.0.$i:;ssh root@10.0.0.$i "/bin/bash 02_kubernetes_base_conf.sh";done

# 禁用swap分区
swapoff -a
sed -i 's/.*swap.*/#&/' /etc/fstab
cat > /etc/sysctl.d/k8s.conf << EOF
vm.swappiness=0
EOF

# 调整SELinux级别
setenforce 0

# 禁用防护墙
systemctl disable firewalld --now

# 打开网络转发
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# 加载相应的模块
modprobe br_netfilter
modprobe overlay
sysctl -p /etc/sysctl.d/k8s.conf

# 定制软件源(阿里云)
cat > /etc/yum.repos.d/kubernetes-aliyun.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
yum makecache fast
