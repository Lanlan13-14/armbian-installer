#!/usr/bin/env bash
set -e

echo "📦 开始安装 Webmin..."

# 1. 安装基础依赖
sudo apt update
sudo apt install -y wget curl gnupg2 software-properties-common apt-transport-https perl

# 2. 添加 Webmin GPG 密钥
wget -qO- http://www.webmin.com/jcameron-key.asc | sudo apt-key add -

# 3. 添加 Webmin 软件源
sudo tee /etc/apt/sources.list.d/webmin.list >/dev/null <<'EOF'
deb http://download.webmin.com/download/repository sarge contrib
EOF

# 4. 安装 Webmin
sudo apt update
sudo apt install -y webmin

# 5. 若 UFW 已启用，放行端口
if command -v ufw >/dev/null && sudo ufw status | grep -q "Status: active"; then
  echo "🔓 检测到 UFW，自动放行 10000 端口..."
  sudo ufw allow 10000/tcp
fi

# 6. 输出访问信息
IP=$(hostname -I | awk '{print $1}')
echo -e "\n✅ Webmin 安装完成！"
echo -e "🌐 请在浏览器中访问：\e[1;32mhttps://$IP:10000\e[0m"
echo "🔐 登录账号：系统用户名（如 root），密码为对应用户密码。"
echo "⚠️ 如果浏览器提示证书不安全，点击“继续访问”即可。"