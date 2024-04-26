#!/bin/bash
# 功能：安装部署CRI容器运行时环境
# 版本：v0.1
# 作者：Guoxin
# 联系：lvmugua@163.com
# 清理CRI命令：
# for i in IP1 {IP2..IPn};do ssh root@10.0.0.$i "systemctl stop cri-docker; rm -rf /user/local/bin/cri-dockerd";done

# 准备工作
target_net='10.0.0'
root_dir=$(dirname "$PWD")
soft_dir="$root_dir/softs"
cri_soft="cri-dockerd-x.x.x.amd64.tgz"
cri_service='cri-docker.service'
cri_socket='cri-docker.socket'
login_user='root'
pause_image='kubernetes-register.x.com/google_containers/pause:x.x'

#生成IP列表
create_ip_list(){
  	# 接收外部输入的两个IP参数
  	local ip_net="$1"
  	local ip_tail="$2"
  	local ip_list=""
  	# 生成IP列表
  	for i in $(eval echo "${ip_tail}");do
  		ip_addr=$(echo -n "${ip_net}.${i} ")
  		ip_list="${ip_list}${ip_addr}"
  	done
  	echo ip_list
}

# 获取CRI-DOCKERD
get_cridockerd(){
  # 获取软件
  cd "${soft_dir}" || exit
  [ -f ${cri_soft} ] && tar xf ${cri_soft}
}

# 配置CRI-DOCKERD
create_file(){
  # 部署cri-docker服务文件
  cat > "${cri_service}" <<-eof
[Unit]
Description=CRI Interface for Docker Application Container Engine
Documentation=https://docs.mirantis.com
After=network-online.target firewalld.service docker.service
Wants=network-online.target
Requires=cri-docker.socket

[Service]
Type=notify
ExecStart=/usr/local/bin/cri-dockerd --network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin --container-runtime-endpoint=unix:///var/run/cri-dockerd.sock --pod-infra-container-image=$pause_image --cri-docker-root-directory=/var/lib/dockershim --docker-endpoint=unix:///var/run/docker.sock --cri-dockerd-root-directory=/var/lib/docker
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
RestartSec=2
Restart=always

# Note that StartLimit* options were moved from "Service" to "Unit" in systemd 229.
# Both the old, and new location are accepted by systemd 229 and up, so using the old location
# to make them work for either version of systemd.
StartLimitBurst=3

# Note that StartLimitInterval was renamed to StartLimitIntervalSec in systemd 230.
# Both the old, and new name are accepted by systemd 230 and up, so using the old name to make
# this option work for either version of systemd.
StartLimitInterval=60s

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity

# Comment TasksMax if your systemd version does not support it.
# Only systemd 226 and above support this option.
TasksMax=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
eof

  cat > "${cri_socket}" <<-eof
[Unit]
Description=CRI Docker Socket for the API
PartOf=cri-docker.service

[Socket]
ListenStream=/var/run/cri-dockert.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=multi-user.target
eof
}

# 检查服务效果
check_service(){
  ip="$1"
  status=$(ssh ${login_user}@"${ip}" "systemctl is-active \${cri_service}")
  if [ "$status" == "active" ]
  then
    echo -e "\e]32m $ip 主机CIR-DOCKERD服务启动成功 \e[0M"
  else
    echo -e "\e]33m $ip 主机CIR-DOCKERD服务启动失败 \e[0M"
  fi
}

# 部署CRI-DOCKERD
deploy_cridocjkerd(){
  read -rp "请输入需要批量部署CRI服务的主机列表范围（实例：{12..19}）:" num_list
  ip_list=$(create_ip_list "${target_net}" "${num_list}")
  for i in ${ip_list}
  do
    scp "${soft_dir}"/"${cri-service}"  ${login_user}@"${i}":/etc/systemd/systemd/system/${cri_service}
    scp "${soft_dir}"/"${cri-socket}"  ${login_user}@"${i}":/usr/lib/systemd/systemd/system/${cri_socket}
    scp "${soft_dir}"/cri-docked/"${cri-dockerd}"  ${login_user}@"${i}":/usr/local/bin/
    ssh ${login_user}@"${i}" "systemctl daemon-reload; systemctl enable cri-docker.service; systemctl restart cri-docker.service"
    check_service"${i}"
  done
}
# 收尾动作
deploy_tail(){
  rm -rf "${soft_dir:?}"/{${cri_service},${cri_socket},cri-dockerd}
}

# 软件部署
main(){
  get_cridockerd
  create_file
  deploy_cridocjkerd
  deploy_tail
}

# 调用主函数
main
