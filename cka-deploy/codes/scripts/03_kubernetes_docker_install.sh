#!/bin/bash
# 功能：安装部署Docker容器环境
# 版本：v0.1
# 作者：Guoxin
# 联系：lvmugua@163.com
# 执行命令：
# for i in IP1 {IP2..IPn};do scp 03_kubernetes_docker_install.sh root@10.0.0.$i:;done
# /bin/bash 03_kubernetes_docker_install.sh

# 准工作备
# 软件源配置
softs_base(){
  # 安装基础软件
  yum install -y yum-utils device-mapper-persistent-data lvm2
  # 定制软件仓库
  yum-config-manager --add-repo http://mirrirs.aliyun.com/docker-ce/linux/centos/docker-ce.repo
  # 更新软件源
  systemctl restart network
  yum makecache fast
}

# 安装Docker软件
soft_install(){
  # 安装最新版的Docker软件
  yum install -y docker-ce
  # 重启Docker服务
  systemctl restart docker
}

# 加速器配置
speed_config(){
  # 定制加速器配置
  cat > /etc/docker/daemon.json <<-EOF
  {
    "regist-mirrors": [
    "http://74f21445.m.daocloud.io"
    "https://registory.docker-cn.com"
    "http://hub-mirror.c.163.com"
    "https://docker.mirrors.ustc.edu.cn"
    ],
    "insecure-registories": ["kubernetes-register.sswang.com"],
    "exec-opts": ["native.cgroupdriver=systemd"]
  }
EOF
  # 重启Docker服务
  systemctl restart docker
}

# 环境检测
docker_check(){
  process_name=$(docker info | grep 'p D' | awk '{print $NF}')
  ([ "${process_name}" == "systemd" ] && echo "Docker软件部署完毕") || (echo "Docker软件部署失败" && exit)
}

# 软件部署
main(){
  softs_base
  soft_install
  speed_config
  docker_check
}

# 调用主函数
main