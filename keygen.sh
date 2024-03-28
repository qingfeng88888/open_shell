#!/bin/bash

# 创建SSH目录
mkdir -p ~/.ssh
cd ~/.ssh

# 生成SSH密钥
# 生成SSH密钥
echo -e "\e[32m开始愉快之旅吧\e[0m"
echo -e "\e[32m系统将提示您指定密钥对名称: \e[33m一路回车\e[32m 请按Enter继续\e[0m"
echo
ssh-keygen -t ed25519 -C "注释随意"

# 复制公钥到远程服务器
read -p "请输入SSH端口号（默认为22）：" ssh_port
ssh_port=${ssh_port:-22}
read -p "请输入服务器IP地址：" server_ip

ssh-copy-id -i ~/.ssh/id_ed25519.pub -p $ssh_port root@$server_ip

# 修改远程服务器配置
ssh -p $ssh_port root@$server_ip << 'EOF'
if grep -q "^#*PubkeyAuthentication\s*no" /etc/ssh/sshd_config; then
    sudo sed -i 's/^#*PubkeyAuthentication\s*no/ PubkeyAuthentication yes/' /etc/ssh/sshd_config
elif grep -q "^#*PubkeyAuthentication\s*yes" /etc/ssh/sshd_config; then
    sudo sed -i 's/^#*PubkeyAuthentication\s*yes/ PubkeyAuthentication yes/' /etc/ssh/sshd_config
else
    echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config
fi
sudo service ssh restart
exit
EOF

# 使用SSH密钥登录
ssh -p $ssh_port -i ~/.ssh/id_ed25519 root@$server_ip
