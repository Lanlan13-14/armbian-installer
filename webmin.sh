#!/usr/bin/env bash
set -e

# -------- CONFIG --------
CREATE_USER=false       # 是否自动创建管理员账号
ADMIN_USER="webadmin"
ADMIN_PASS="webmin123"
CUSTOM_PORT=10000       # 修改为非 10000 端口可更安全
# ------------------------

echo "📦 正在安装 Webmin..."

# 安装基础依赖
apt update
apt install -y wget curl gnupg2 software-properties-common apt-transport-https perl

# 添加 GPG 密钥 & 源
wget -qO- http://www.webmin.com/jcameron-key.asc | apt-key add -
echo "deb http://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list

# 安装 Webmin
apt update
apt install -y webmin

# 开放 UFW 端口（如果启用）
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  echo "🔓 UFW 正在运行，放行端口 $CUSTOM_PORT..."
  ufw allow ${CUSTOM_PORT}/tcp
fi

# 修改端口（如果不是默认端口）
if [[ "$CUSTOM_PORT" != "10000" ]]; then
  sed -i "s/port=10000/port=${CUSTOM_PORT}/" /etc/webmin/miniserv.conf
  systemctl restart webmin
  echo "⚙️ Webmin 已更改监听端口为 ${CUSTOM_PORT}"
fi

# 自动创建管理员账号（可选）
if [ "$CREATE_USER" = true ]; then
  echo "👤 正在创建 Webmin 用户：$ADMIN_USER"
  useradd -m -s /bin/bash $ADMIN_USER || true
  echo "${ADMIN_USER}:${ADMIN_PASS}" | chpasswd
  usermod -aG sudo $ADMIN_USER
  echo "✅ 用户 $ADMIN_USER 创建成功，密码：$ADMIN_PASS"
fi

# 输出结果
IP=$(hostname -I | awk '{print $1}')
echo -e "\n✅ Webmin 安装完成！"
echo -e "🌐 请在浏览器访问：\e[1;32mhttps://$IP:$CUSTOM_PORT\e[0m"
echo -e "🔐 使用你的 Linux 系统用户名（如 root）登录"
echo "⚠️ 证书为自签名，请点击浏览器的“继续访问”"