#!/bin/bash
# 功能：安装部署Harbor镜像仓库环境
# 版本：v0.1
# 作者：Guoxin
# 联系：lvmugua@163.com

# 准备工作
harbor_name='harbor'
harbor_admin='admin'
admin_passwd='Harbor12345'
harbor_address=$(awk '/register/{print $1}' /etc/hosts)

server_dir='/data/server'
softs_dir='/data/softs'
bin_dir='/usr/bin'
data_dir="${server_dir}/${harbor_name}/data"

harbor_version='vx.x.x'
image_name="harbor.${harbor_name}.tar.gz"
harbor_softs="harbor-offline-installer-${harbor_version}.tgz"
compose_softs="docker-compose-linux-x86_64"

conf_name='harbor.yml'
service_file='/lib/systemd/system/harbor.service'

harbor_user='xxxx'
harbor_passwd='Harbor12345'
harbor_proj1='docker-web1'
harbor_proj2='google_containers'
harbor_addr=$(awk '/regi/{print $1}' /etc/hosts)
harbor_url="http://${harbor_addr}"
harbor_ver_api='api/version'
add_user_api='api/v2.0/users'
add_proj_api='api/v2.0/projects'
curl_cmd='curl -s -H "Content -Type: application/json"'

# 获取系统版本
status=$(grep -i ubuntu /etc/issue)
[ -n "$status" ] && os_type="Ubuntu" || os_type="CentOS"
[ "${os_type}" == "CentOS" ] && cmd_type="yum" || cmd_type="apt"

# 环境部署配置
compose_install(){
  # 安装docker-compose
  "${cmd_type}" install -y jq docker-compose
}

harbor_install(){
  # 安装Harbor
  echo -e "\e[32m 开始安装指定版本的Harbor程序文件 \e[0m"
  [ -d "${server_dir}" ] || mkdir -p "${server_dir}"
  tar xf "${softs_dir}/${harbor_softs}" -C "$(server_dir)"
}

# 导入镜像
image_load(){
  # 加载镜像文件
  cd "${server_dir}/harbor" || exit
  docker load < "${image_name}"
}

config_harbor(){
  # 修改Harbor配置文件
  cd "${server_dir}/harbor" || exit
  /usr/bin/cp "${conf_name}.tmpl" "${conf_name}"
  sed -i "s#^hostname:.*#hostname: $harbor_address#" "${conf_name}"
  sed -i 's/^https/#https/' "${conf_name}"
  sed -i 's/port: 443/#port: 443/' "${conf_name}"
  sed -i 's/certificate:/#certificate:/' "${conf_name}"
  sed -i 's/private_key:/#private_key:/' "${conf_name}"
  sed -i "s/Harbor12345:/$admin_passwd/" "${conf_name}"
  sed -i 's/certificate:/#certificate:/' "${conf_name}"
  sed -i "s#data_volume:.*#data_volume: $data_dir#" "${conf_name}"
  # 配置Harbor
  "${server_dir}/${harbor_name}"/prepare
  # 启动Harbor安装脚本
  "${server_dir}/${harbor_name}"/install.sh
  sleep 5
  ${bin_dir}/docker-compose ps
  sleep 3
  ${bin_dir}/docker-compose down
}

# Harbor服务启动文件配置
service_conf(){
  cat > ${service_file} <<-eof
[Unit]
Description=Harbor
After=docker.service systemd-networkd.service systemd-resolved.service
Requires=docker.service
Documentation=http://github.com/vmware/harbor

[Service]
Type=simple
Restart=on-failure
RestartSec=5
# 需要注意harbor的安装位置
ExecStart=${bin_dir}/docker-compose --file ${server_dir}/${harbor_name}/docker-compose.yml up
ExecStop=${bin_dir}/docker-compose --file ${server_dir}/${harbor_name}/docker-compose.yml down

[Install]
WantedBy=multi-user.target
eof
  systemctl daemon-reload
  systemctl enable --now ${harbor_name}
}

# 检查效果
harbor_check(){
  # 检查服务
  status=$(systemctl is-active harbor.service)
  if [ "${status}" == "active" ]; then
    echo -e "\e[32m harbor私有镜像仓库环境部署成功 \e[0m"
  else
    echo -e "\e[31m harbor私有镜像仓库环境部署失败 \e[0m"
  fi
  # 检测应用
  echo -e "\e[32m harbor私有镜像仓库应用服务检测中 \e[0m"
  mark=''
  rm -rf /var/lib/dpkg/lock*
  msg=$(curl -s -H "Content-Type: application/json" -u "${harbor_admin}:${admin_passwd}" -X GET "${harbor_url}/${harbor_ver_api}")
  sts=$(echo "$msg" | jq -r ".version")
  while [ "${sts}" != "v2.0" ];do
    printf "progress: [%-40s]\r" "${mark}"
    sleep 0.2
    mark="#${mark}"
    msg=$(curl -s -H "Content-Type: application/json" -u "${harbor_admin}:${admin_passwd}" -X GET "${harbor_url}/${harbor_ver_api}")
    sts=$(echo "$msg" | jq -r ".version")
  done
  echo -e "\e[32m harbor私有镜像仓库应用访问成功 \e[0m"
}

# 定制Harbor仓库
add_user(){
  user="$1"
  passwd="$2"
  # 创建配置文件
  cat >/tmp/user.json <<-eof
{
  "username": "${user}",
  "email": "lvmugua@163.com",
  "password": "${passwd}",
  "realname": "${user}",
  "role_id": 2
}
eof
  # 创建用户
  curl -s -H "Content-Type: application/json" -u "${harbor_admin}:${admin_passwd}" -X POST "${harbor_url}/${add_user_api}" -d @/tmp/user.json
  # 检查效果
  result=$(curl -s -H "Content-Type: application/json" -u "${harbor_admin}:${admin_passwd}" -X GET "${harbor_url}/${add_user_api}" | grep "${user}")
  if [ "${result}" != "" ]; then
    echo -e "\e[32m ${user}自定义用户创建成功 \e[0m"
  else
    echo -e "\e[32m ${proj}自定义用户创建失败 \e[0m"
    exit
  fi
}

add_proj(){
  user="$1"
  pass="$2"
  proj="$3"
  # 创建配置文件
  cat >/tmp/proj.json <<-eof
{
  "project_name": "${proj}",
  "public": true
}
eof
  # 创建用户
  curl -s -H "Content-Type: application/json" -u "${user}:${pass}" -X POST "${harbor_url}/${add_proj_api}" -d @/tmp/proj.json
  # 检查效果
  result=$(curl -s -H "Content-Type: application/json" -u "${user}:${pass}" -X GET "${harbor_url}/${add_proj_api}" | grep "${proj}")
  if [ "${result}" != "" ]; then
    echo -e "\e[32m ${proj}项目创建成功 \e[0m"
  else
    echo -e "\e[32m ${proj}项目创建失败 \e[0m"
    exit
  fi
}

# 主函数
main(){
  # 部署Docker-Compose环境
  compose_status=$(docker-compose -v 2>/dev/null | grep -c version)
  if [ "${compose_status}" == "0" ];then
    compose_install
  else
    echo -e "\e[32m 目标主机上已经Docker-Compose环境 \e[0m"
  fi
  # 部署Harbor环境
  status=$(systemctl is-active harbor.service)
  if [ "${status}" != "active" ];then
    harbor_install
    image_load
    config_harbor
    service_conf
    harbor_check
  else
    echo -e "\e[32m 目标主机上已经存在Harbor环境 \e[0m"
  fi
  # 为了保证Harbor服务启动成功
  sleep 5
  # 定制Harbor仓库
  add_user "${harbor_user}" "${harbor_passwd}"
  add_proj "${harbor_user}" "${harbor_passwd}" "${harbor_proj1}"
  add_proj "${harbor_user}" "${harbor_passwd}" "${harbor_proj2}"
}

# 执行主函数
main