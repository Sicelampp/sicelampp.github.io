#!/bin/bash
# 功能: 批量设定远程主机SSH免密认证
# 版本: V0.1
# 作者: Guoxin
# 联系：lvmugua@163.com

# 准备工作
user_dir='/root'
host_file='/etc/hosts'
login_user='root'
login_pass='123456'
target_net='10.0.0'
target_type=(部署 免密 同步 主机名 退出)

# 菜单
menu(){
	echo -e "\e[31m批量设定远程主机SSH免密、主机名管理界面\e[0m"
	echo "======================================================="
	echo -e "\e[32m 1: 部署环境    2: SSH免密认证 3: 同步hosts \e[0m"
	echo -e "\e[32m 4: 设定主机名  5: 退出操作  \e[0m"
	echo "======================================================="
}

# expect环境
expect_install(){
	if [ -f /usr/bin/expect ]
	then
		echo -e "\e[33m expect环境已经部署完毕\e[0m"
	else
		(yum install expect tcl -y >> /dev/null 2>&1 && echo -e "\e[31m expect软件安装完毕\e[0m") || (echo -e "\e[33m expect软件安装失败\e[0m" && exit)
	fi
}
# 密钥文件生成环境
create_authkey(){
	# 保证历史文件清空
	[ -d ${user_dir}/.ssh ] && rm -rf ${user_dir}/.ssh/*
	# 构建密钥文件对
	/usr/bin/ssh-keygen -t rsa -P "" -f ${user_dir}/.ssh/id_rsa
	echo -e "\e[31m密钥文件已经创建完毕\e[0m"
}
# expect自动匹配逻辑
expect_autoauth_func(){
	# 接收外部参数
	command="$*"
	expect -c "
		spawn ${command}
		expect {
			\"yes/no\" {send \"yes\r\"; exp_continue}
			\"*password*\" {send \"${login_pass}\r\"; exp_continue}
			\"*password*\" {send \"${login_pass}\r\"}
		}"
}
# 跨主机传输文件密钥证书
sshkey_auth_func(){
	# 接受外部的主机列表参数
	local host_list="$*"
	for ip in ${host_list}
	do
		# /usr/bin/ssh-copy-id -i ${user_dir}/.ssh/id_rsa.pub root@host_ip
		cmd="/usr/bin/ssh-copy-id -i ${user_dir}/.ssh/id_rsa.pub"
		remote_host="${login_user}@${ip}"
		expect_autoauth_func "${cmd}" "${remote_host}"
	done
}
# 跨主机同步hosts文件
scp_hosts_func(){
	# 接受外部的主机列表参数
	local host_list="$*"
	for ip in ${host_list}
	do
		remote_host="${login_user}@${ip}"
		scp "${host_file}" "${remote_host}":${host_file}
	done

}
# 跨主机设定规划主机名
set_hostname_func(){                                                                                                       
	        # 接受外部的主机列表参数
		local host_list="$*"
		for ip in ${host_list}
	        do
			host_name=$(grep "${ip}" ${host_file}|awk '{print $NF}')
			remote_host="${login_user}@${ip}"
			ssh "${remote_host}" "hostnamectl set-hostname ${host_name}"
		done    
}
# 生成Remote-IP列表
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
	echo "$(ip_list)"

}
# 帮助信息逻辑
Usage(){
	echo "请输入有效的操作ID"
}
# 界面入口
while true
do
	menu
	read -rp "请输入有效的操作ID: " target_id
	if [ ${#target_type[@]} -ge "${target_id}" ]
	then
		if [ "${target_type[${target_id}-1]}" == "部署" ]
		then
			echo "开始部署环境操作..."
			expect_install
			create_authkey
		elif [ "${target_type[${target_id}-1]}" == "免密" ]
		then
			read -rp "请输入需要批量远程主机SSH免密认证的主机列表范围（示例: {12..19}）: " num_list
			ip_list=$(create_ip_list "${target_net}" "${num_list}")
			echo "开始执行批量免密认证操作..."
			sshkey_auth_func "${ip_list}"
		elif [ "${target_type[${target_id}-1]}" == "同步" ]
		then
			read -rp "请输入需要批量远程主机同步hosts文件的主机列表范围（示例: {12..19}）: " num_list
			ip_list=$(create_ip_list "${target_net}" "${num_list}")
			echo "开始执行批量同步hosts文件操作..."
			scp_hosts_func "${ip_list}"
		elif [ "${target_type[${target_id}-1]}" == "主机名" ]
		then
			read -rp "请输入需要批量设定远程主机主机名的主机列表范围（示例: {12..19}）: " num_list
			ip_list=$(create_ip_list "${target_net}" "${num_list}")
			echo "开始执行批量设定主机名操作..."
			set_hostname_func "${ip_list}"
		elif [ "${target_type[${target_id}-1]}" == "退出" ]
		then
			echo "开始退出批量设定..."
			exit
		fi
	else
		Usage
	fi
done

