#!/bin/bash

# 显示菜单选项
echo "请选择要执行的操作："
echo "1. 测试CPU性能"
echo "2. VPS检测"
echo "3. 磁盘真实性能读写测试"
echo "4. 三网测速脚本"
echo "5. 三网回程测试脚本"
echo "6. 三网回程延迟测试脚本"
echo "7. 解锁状态查看"
echo "8. 流媒体解锁测试脚本"
echo "9. 解锁tiktok状态"
echo "10. 一键开启BBR"
echo "11. 一键重装系统(DD)"
echo "12. 更新组件"
echo "13. 升级packages"
echo "14. 查看系统现有内核"
echo "15. 退出"

# 提示用户选择操作
read -p "请输入操作编号: " choice

# 执行用户选择的操作
case $choice in
    1)
        # 执行测试CPU性能操作
        apt update -y && apt install -y curl wget sudo
        curl -sL yabs.sh | bash -s -- -i -5
        ;;
    2)
        # 执行VPS检测操作
        echo "请选择要执行的VPS检测脚本："
        echo "1. 脚本1"
        echo "2. 脚本2"
        read -p "请输入脚本编号: " vps_choice
        if [ "$vps_choice" == "1" ]; then
            wget -q https://github.com/Aniverse/A/raw/i/a && bash a
        elif [ "$vps_choice" == "2" ]; then
            wget -qO- bench.sh | bash
        else
            echo "无效的脚本选择。"
        fi
        ;;
    3)
        # 执行磁盘真实性能读写测试操作
        echo "开始进行磁盘真实性能读写测试..."
        dd bs=64k count=4k if=/dev/zero of=test oflag=dsync
        echo "测试完成。"
        ;;
    4)
        # 执行三网测速脚本操作
        bash <(curl -Lso- https://git.io/superspeed_uxh)
        ;;
    5)
        # 执行三网回程测试脚本操作
        echo "请选择要执行的三网回程测试脚本："
        echo "1. 脚本1"
        echo "2. 脚本2"
        read -p "请输入脚本编号: " mtr_choice
        if [ "$mtr_choice" == "1" ]; then
            curl https://raw.githubusercontent.com/zhucaidan/mtr_trace/main/mtr_trace.sh|bash
        elif [ "$mtr_choice" == "2" ]; then
            curl https://raw.githubusercontent.com/zhanghanyun/backtrace/main/install.sh -sSf | sh
        else
            echo "无效的脚本选择。"
        fi
        ;;
    6)
        # 执行三网回程延迟测试脚本操作
        wget -qO- git.io/besttrace | bash
        ;;
    7)
        # 执行解锁状态查看操作
        bash <(curl -Ls https://cdn.jsdelivr.net/gh/missuo/OpenAI-Checker/openai.sh)
        ;;
    8)
        # 执行流媒体解锁测试脚本操作
        bash <(curl -L -s check.unlock.media)
        ;;
    9)
        # 执行解锁tiktok状态操作
        wget -qO- https://github.com/yeahwu/check/raw/main/check.sh | bash
        ;;
    10)
        # 执行一键开启BBR脚本操作
        echo "请选择要执行的BBR脚本："
        echo "1. 脚本1"
        echo "2. 脚本2"
        read -p "请输入脚本编号: " bbr_choice
        if [ "$bbr_choice" == "1" ]; then
            echo "net.core.default_qdisc=fq"  >>  /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr"  >>  /etc/sysctl.conf
            sysctl -p
            lsmod | grep bbr
        elif [ "$bbr_choice" == "2" ]; then
            wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
        else
            echo "无效的脚本选择。"
        fi
        ;;
    11)
        # 执行一键重装系统(DD)操作
        echo "请选择要执行的系统重装脚本："
        echo "1. 脚本1"
        echo "2. 脚本2"
        echo "3. 脚本3"
        read -p "请输入脚本编号: " reinstall_choice
        if [ "$reinstall_choice" == "1" ]; then
            wget --no-check-certificate -qO InstallNET.sh 'https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh' && chmod a+x InstallNET.sh
            echo "请选择要重装的系统："
            echo "a. Debian 11"
            echo "b. Ubuntu 20.04"
            echo "c. CentOS 7"
            read -p "请输入系统编号: " os_choice
            if [ "$os_choice" == "a" ]; then
                bash InstallNET.sh -debian 11
            elif [ "$os_choice" == "b" ]; then
                bash InstallNET.sh -ubuntu 20.04
            elif [ "$os_choice" == "c" ]; then
                bash InstallNET.sh -centos 7
            else
                echo "无效的系统选择。"
            fi
        elif [ "$reinstall_choice" == "2" ]; then
            bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/MoeClub/Note/master/InstallNET.sh') -d 11 -v 64 -p 123456 -port 22
        elif [ "$reinstall_choice" == "3" ]; then
            wget –no-check-certificate -O AutoReinstall.sh https://git.io/AutoReinstall.sh && bash AutoReinstall.sh
        else
            echo "无效的脚本选择。"
        fi
        ;;
    12)
        # 执行更新组件操作
        apt update -y && apt install -y curl && apt install -y socat && apt install wget -y
        ;;
    13)
        # 执行升级packages操作
        sudo -i
        apt update -y
        apt install wget curl sudo vim git -y
        ;;
    14)
        # 查看系统现有内核
        dpkg  -l|grep linux-image
        ;;
    15)
        # 退出
        echo "退出脚本。"
        exit 0
        ;;
    *)
        echo "无效的操作选择。"
        ;;
esac