#!/bin/bash
download_name="frp_0.39.1_linux_amd64.tar.gz"
frp_name="frp_0.39.1_linux_amd64"
file_url="https://github.com/fatedier/frp/releases/download/v0.39.1/${download_name}"
download_path="/tmp"


# 下载frp文件
download(){
    if [  -d "${download_path}/frp" ];then
        return
    fi
    cd $download_path && wget --no-check-certificate $file_url 
    if [ $? -eq 0  ];then
        tar -xzf $download_name && mv ${frp_name} frp && cd frp
        local frp_path=$(pwd)
        echo "${download_name} 已解压到 ${frp_path}"
    else
        echo "frp下载失败"
    fi
}

# frps
frps(){
    # 不存在的话 就没有继续下去的必要了
    if [ ! -d "${download_path}/frp" ];then
        exit 1
    fi
    cd "${download_path}/frp"
    chmod +x ./frps && mv ./frps /usr/bin/
    cd ./systemd
    sed -i 's/User=nobody/User=root/g' ./frps.service && mv ./frps.service /etc/systemd/system/
    if [ $? -eq 0  ];then
        systemctl enable frps.service && systemctl start frps.service
    else
        exit
    fi   
}

# frpc 
frpc(){
    # 不存在的话 就没有继续下去的必要了
    if [ ! -d "${download_path}/frp" ];then
        exit 1
    fi
    cd "${download_path}/frp"
    chmod +x ./frpc && mv ./frpc /usr/bin/
    cd ./systemd
    sed -i 's/User=nobody/User=root/g' ./frpc.service && mv ./frpc.service /etc/systemd/system/
    if [ $? -eq 0  ];then
        systemctl enable frpc.service && systemctl start frpc.service
    else
        exit 1
    fi   
}

# 生成服务端配置文件
frps_ini(){
    if [ ! -d "/etc/frp" ];then
        mkdir -p /etc/frp
    fi 
    read -p "监听端口 bind_port: " bind_port
    read -p "token: " token
    read -p "面板用户名 dashboard_user: " dashboard_user
    read -p "面板密码 dashboard_pwd: " dashboard_pwd
    read -p "面板监听端口 dashboard_port: " dashboard_port

cat>/etc/frp/frps.ini<<EOF
[common]
bind_port = $bind_port
token = $token

dashboard_user = $dashboard_user
dashboard_pwd = $dashboard_pwd
dashboard_port = $dashboard_port
EOF
}

# 生成客户端配置文件
frpc_ini(){
    if [ ! -d "/etc/frp" ];then
        mkdir -p /etc/frp
    fi 
    echo "=== common公共部分 ==="
    read -p "server_addr: " server_addr
    read -p "server_port: " server_port
    read -p "token: " token
    echo
    echo "=== 端口转发部分 ==="
    read -p "本地需要转发的端口: " local_port
    read -p "要转发到的远程端口: " remote_port1
    echo 
    echo "=== socks5代理部分 ==="
    read -p "远程端口 remote_port: " remote_port
    read -p "设置用户名 plugin_user: " plugin_user
    read -p "设置密码 plugin_passwd: " plugin_passwd

cat>/etc/frp/frpc.ini<<EOF
[common]
server_addr = $server_addr
server_port = $server_port
token = $token

# 端口转发
[port2port]
type = tcp
local_ip = 127.0.0.1
local_port = $local_port
remote_port = $remote_port1

# socks5 代理
[test_sock5]
type = tcp
remote_port = $remote_port
plugin = socks5
plugin_user = $plugin_user
plugin_passwd = $plugin_passwd
use_encryption = true
use_compression = true
EOF
}
# 检查是否有frps、frpc和frps.service、frpc.service
check(){
    version=$(/usr/bin/$1 -v 2>/dev/null)
    if [ ! -z $version ];then
        echo "/usr/bin/$1 已经存在"
        exit
    fi
    system_service="/etc/systemd/system/$1.service"
    if [ -f $system_service ];then
        echo "$system_service,请检查后再继续"
        exit
    fi
}
uninstall_frp(){
    # 关于systemctl的处理不严谨,如果从未安装过会报错，但不影响执行
    systemctl stop frps
    systemctl stop frpc
    systemctl disable frps
    systemctl disable frpc
    rm -rf "${download_path}/${download_name}"
    rm -rf "${download_path}/frp"
    rm -rf /usr/bin/frp*
    rm -rf /etc/frp
    rm -rf /etc/systemd/system/frp*
    echo "清理、卸载frp成功"
}
start_menu(){
    download
    echo "请选择要安装的类型"
    echo "0: exit"
    echo "1: 安装frps服务端"
    echo "2: 安装frpc客户端"
    echo "3: 卸载frps、frpc服务"
    read -p "你选择的是:" choose
    
    case $choose in
        0) exit
        ;;
        1) check frps
           frps_ini
           frps
        ;;
        2) check frpc
           frpc_ini
           frpc
        ;;
        3) uninstall_frp
        ;;
        *) echo "请选择0-2之间的数"
    esac
}
start_menu