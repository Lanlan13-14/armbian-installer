#!/usr/bin/env bash
set -e

# -------- CONFIG --------
CUSTOM_PORT=10000       # 如需更安全，可改成 8443 等非默认端口
# ------------------------

echo "📦 正在安装 Webmin..."

# 1) 安装基础依赖
apt update
apt install -y wget curl gnupg2 software-properties-common apt-transport-https perl

# 2) 添加 Webmin GPG 密钥与软件源
wget -qO- http://www.webmin.com/jcameron-key.asc | apt-key add -
echo "deb http://download.webmin.com/download/repository sarge contrib" \
  > /etc/apt/sources.list.d/webmin.list

# 3) 安装 Webmin
apt update
apt install -y webmin

# 4) 若系统启用了 UFW，则放行端口
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  echo "🔓 UFW 正在运行，放行端口 $CUSTOM_PORT..."
  ufw allow ${CUSTOM_PORT}/tcp
fi

# 5) 若需要自定义端口，修改 miniserv.conf 并重启 Webmin
if [[ "$CUSTOM_PORT" != "10000" ]]; then
  sed -i "s/^port=.*/port=${CUSTOM_PORT}/" /etc/webmin/miniserv.conf
  systemctl restart webmin
  echo "⚙️ Webmin 已改为监听端口 ${CUSTOM_PORT}"
fi

# 6) 输出访问信息
IP=$(hostname -I | awk '{print $1}')
echo -e "\n✅ Webmin 安装完成！"
echo -e "🌐 请在浏览器访问：\e[1;32mhttps://$IP:$CUSTOM_PORT\e[0m"
echo -e "🔐 直接使用 **系统账号**（如 root）和对应密码登录"
echo "⚠️ 这是自签名证书，浏览器会提示不安全，点击“继续访问”即可"