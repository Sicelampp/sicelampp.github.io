#!/bin/bash
# 功能：Kubernetes环境初始化
# 版本：v0.1
# 作者：Guoxin
# 联系：lvmugua@163.com
# 清理环境命令
# kubeadm reset --cri-socket=unix:///var/run/cri-dockered.sock

# 基础变量
harbor_mirror="kubernetes-register.xxxx.com"
harbor_user='xxxx'
harbor_passwd='Harbor12345'
aliyun_mirror='registry.aliyuncs.com'
harbor_repo='google_containers'

# 获取系统版本
status=$(grep -i ubuntu /etc/issue)
[ -n "$status" ] && os_type="Ubuntu" || os_type="CentOS"
[ "${os_type}" == "CentOS" ] && cmd_type="yum" || cmd_type="apt"

# 获取kubernetes的所有版本
k8s_version(){
  # host_addr="$1"
  echo -e "\e[32m 当前环境下可安装的kubernetes版本 \e[0m"
  echo "======================================================================"
  if [ "${os_type}" == "CentOS" ];then
    yum list --showduplicates kubeadm | sort -r | grep '1.2' | head -10
  else
    apt-cache madison kubeadm | head -10
  fi
  echo "======================================================================"
}

# 安装软件
k8s_softs_install(){
  read -r -p "请输入是否要部署的软件版本（比如 1.25.1，空表示最新版）：" version
  if [[ -n $version ]];then
  # 获取安装命令
  [ "${os_type}" == "CentOS" ] && soft_tail='-'${version} || soft_tail='='${version}'-00'
  ${cmd_type} install kubeadm"${soft_tail}" kubectl"${soft_tail}" kubelet"${soft_tail}" -y; systemctl enable kubelet
  else
    ${cmd_type} install kubeadm kubectl kubelet -y; systemctl enable kubelet
  fi
}

get_images(){
  # 获取指定kubernetes版本所需镜像
  images=$(kubeadm config images list --kubernetes-version="${version}" | awk -F "/" '{print $NF}')
  docker login ${harbor_mirror} -u ${harbor_user} -p "${harbor_passwd}"
  for i in ${images}
  do
    docker pull "${aliyun_mirror}/${harbor_repo}/$i"
    docker tag "${aliyun_mirror}/${harbor_repo}/$i ${harbor_mirror}/${harbor_repo}/$i"
    docker push "{harbor_mirror}/${harbor_repo}/$i"
    docker rmi "${aliyun_mirror}/${harbor_repo}/$i"
  done
}

# kubernetes集群部署
cluster_create(){
  repo_addr="${harbor_mirror}/${harbor_repo}"
  master=$(grep master /etc/hosts | awk '{print $1}')
  [ -f /tmp/msg.txt ] && rm -f /tmp/msg.txt
  # 开始集群初始化
  kubeadm init --kubernetes-version="${version}" --apiserver-advertise-address="${master}" --images-repository ${repo_addr} --service-cidr=10.96.0.0/12 --pod-network-cidr=10.244.0.0/16 --cri-socket unix:///var/run/cri-dockered.sock --ignore-preflight-errors=Swap | tee /tmp/msg.txt
  # 输出待凭借执行命令参数
  echo "其他节点添加到集群的时候，请拼接参数： --cri-socket unix:///var/run/cri-dockered.sock"
}

# master节点收尾动作
master_tail(){
  # 创建k8s的认证文件
  mkdir -p "$HOME"/.kube
  cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
  chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

  # k8s命令操作自动化
  grep kubeadm "$HOME"/.bashrc 2>/dev/null && status="ok" || status="no"
  [ "${status}" == "no" ] && echo 'source < (kubeadm completion bash)' >> "$HOME"/.bashrc
  grep kubectl "$HOME"/.bashrc 2>/dev/null && status="ok" || status="no"
  [ "${status}" == "no" ] && echo 'source < (kubelet completion bash)' >> "$HOME"/.bashrc
}

# 主函数
main(){
  k8s_version
  k8s_softs_install
  get_images
  cluster_create
  master_tail
}

# 执行主函数
main
