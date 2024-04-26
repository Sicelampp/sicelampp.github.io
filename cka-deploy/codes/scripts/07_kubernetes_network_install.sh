#!/bin/bash
# 功能：安装部署Kubernetes网络环境
# 版本：v0.1
# 作者：Guoxin
# 联系：lvmugua@163.com

# 基础变量
root_dir=$(dirname "$PWD")
flannel_dir="$root_dir/yaml/network/flannel"
flannel_file='kube-flannel.yml'
harbor_mirror="kubenetes-register.xxxx.com"
harbor_repo='google_containers'
# 定制配置
flannel_conf(){
  cd "${flannel_dir}" || exit
  [ -f "${flannel_file}" ] && rm -f "${flannel_file}"
  cp "${flannel_file}.bak" "${flannel_file}"
  sed -i "/ iamge:/s#docker.io/flannel#${harbor_mirror}/${harbor_repo}#g" "${flannel_file}"
}

# 获取镜像
get_iamge(){
  for i in $(grep image "${flannel_file}.bak" | grep -v '#' | awk -F '/' '{print $NF}')
    do
      docker pull flannel/"$i"
      docker tag flannel/"$i" "${harbor_mirror}/${harbor_repo}/$i"
      docker push "{harbor_mirror}/${harbor_repo}/$i"
      docker rmi flannel/"$i"
    done
}

# 创建网络环境
apply_flannel(){
  kubelet apply -f "${flannel_file}"
}

# 主函数
main(){
  flannel_conf
  get_iamge
  apply_flannel
}

# 执行主函数
main