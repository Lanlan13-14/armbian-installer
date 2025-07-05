#!/usr/bin/env bash
set -euo pipefail

# ========= 固定参数 =========
WEBUI_PORT=5000
DNS_CRED_FILE="/root/.secrets/dns.ini"
CONF_FILE="/etc/ufeasy.conf"
# ===========================

check_root() {
  [[ "$(id -u)" -eq 0 ]] || { echo "❌ 请以 root 身份运行"; exit 1; }
}

gen_slug() { openssl rand -hex 6; }

prompt_user() {
  echo "🔧 基本信息配置"
  read -rp "1️⃣ 请输入域名 (如: example.com): " DOMAIN
  read -rp "2️⃣ 请输入邮箱 (Let’s Encrypt): " EMAIL
  read -rp "3️⃣ 请输入外网访问端口 [默认2096]: " p; LISTEN_PORT=${p:-2096}
  echo -n "4️⃣ 请输入 Web Basic-Auth 密码 (用户名 root): "
  read -rs BASIC_PASS; echo
  SLUG=$(gen_slug)
  echo -e "✅ 已生成随机路径：\e[32m/${SLUG}/\e[0m"

  echo "5️⃣ 配置 Cloudflare DNS 验证"
  read -rsp "🔑 Cloudflare API Token: " token; echo
  mkdir -p "$(dirname "$DNS_CRED_FILE")"
  echo "dns_cloudflare_api_token = $token" >"$DNS_CRED_FILE"
  chmod 600 "$DNS_CRED_FILE"
}

install_pkg() {
  apt update
  apt install -y git python3 nginx ufw certbot \
                 python3-certbot-dns-cloudflare apache2-utils \
                 python3-venv python3-pip
}

deploy_ufw_webui() {
  git clone --depth=1 https://github.com/BryanHeBY/ufw-webui /opt/ufw-webui 2>/dev/null || true
  
  # 创建专用虚拟环境
  python3 -m venv /opt/ufw-webui-venv
  /opt/ufw-webui-venv/bin/pip install -q -r /opt/ufw-webui/requirements.txt
  
  # 创建服务文件
  cat >/etc/systemd/system/ufw-webui.service <<EOF
[Unit]
Description=UFW WebUI
After=network.target
[Service]
WorkingDirectory=/opt/ufw-webui
Environment="PATH=/opt/ufw-webui-venv/bin:\$PATH"
ExecStart=/opt/ufw-webui-venv/bin/python /opt/ufw-webui/app.py --host 127.0.0.1 --port ${WEBUI_PORT}
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now ufw-webui
}

issue_cert() {
  certbot certonly --dns-cloudflare \
    --dns-cloudflare-credentials "$DNS_CRED_FILE" \
    --dns-cloudflare-propagation-seconds 60 \
    -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" \
    --cert-name ufw-webui
  
  mkdir -p /etc/letsencrypt/renewal-hooks/post
  cat >/etc/letsencrypt/renewal-hooks/post/reload-nginx.sh <<EOF
#!/bin/sh
systemctl reload nginx
EOF
  chmod +x /etc/letsencrypt/renewal-hooks/post/reload-nginx.sh
}

setup_nginx() {
  htpasswd -bc /etc/nginx/.htpasswd root "$BASIC_PASS"
  
  cat >/etc/nginx/sites-available/ufw-webui <<EOF
server {
    listen ${LISTEN_PORT} ssl http2;
    server_name $DOMAIN;

    ssl_certificate     /etc/letsencrypt/live/ufw-webui/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ufw-webui/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;

    # 仅匹配特定路径才反代
    location /${SLUG}/ {
        proxy_pass http://127.0.0.1:${WEBUI_PORT}/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        auth_basic "Restricted";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }

    # 其他所有路径跳转到 example.com
    location / {
        return 302 https://example.com;
    }
}
EOF
  ln -sf /etc/nginx/sites-available/ufw-webui /etc/nginx/sites-enabled/
  rm -f /etc/nginx/sites-enabled/default
  nginx -t
  systemctl reload nginx
}

setup_ufw() {
  ufw allow 22/tcp
  ufw allow "${LISTEN_PORT}"/tcp
  ufw --force enable
}

write_conf() {
  cat >"$CONF_FILE" <<EOF
DOMAIN=$DOMAIN
PORT=$LISTEN_PORT
SLUG=$SLUG
EOF
}

install_ufeasy_cli() {
  cat >/usr/local/bin/ufeasy <<'EOS'
#!/usr/bin/env bash
CONF="/etc/ufeasy.conf"
[[ -f "$CONF" ]] || { echo "❌ 配置文件不存在"; exit 1; }
source "$CONF"

show() {
  echo "🔑 登录信息"
  echo "域名   : $DOMAIN"
  echo "端口   : $PORT"
  echo "路径   : /$SLUG/"
  echo "URL    : https://$DOMAIN:$PORT/$SLUG/"
}
set_path() {
  NEW="$1"; [[ -z "$NEW" ]] && { echo "用法: ufeasy set-path <新路径>"; exit 1; }
  sed -i "s|/$SLUG/|/$NEW/|g" /etc/nginx/sites-available/ufw-webui
  sed -i "s|^SLUG=.*|SLUG=$NEW|" "$CONF"
  systemctl reload nginx
  echo "✅ 路径已改为 /$NEW/"
}
set_port() {
  NEW="$1"; [[ -z "$NEW" ]] && { echo "用法: ufeasy set-port <端口>"; exit 1; }
  sed -i "s|listen $PORT |listen $NEW |" /etc/nginx/sites-available/ufw-webui
  sed -i "s|^PORT=.*|PORT=$NEW|" "$CONF"
  ufw allow "$NEW"/tcp
  ufw delete allow "$PORT"/tcp
  systemctl reload nginx
  echo "✅ 端口已改为 $NEW"
}
case "$1" in
  "" ) show ;;
  set-path ) shift; set_path "$1" ;;
  set-port ) shift; set_port "$1" ;;
  * ) echo "用法: ufeasy [set-path <新路径>] [set-port <端口>]";;
esac
EOS
  chmod +x /usr/local/bin/ufeasy
}

main() {
  check_root
  prompt_user
  install_pkg
  deploy_ufw_webui
  issue_cert
  setup_nginx
  setup_ufw
  write_conf
  install_ufeasy_cli

  echo -e "\n✅ 安装完成！"
  echo -e "🌐 访问地址: \e[32mhttps://${DOMAIN}:${LISTEN_PORT}/${SLUG}/\e[0m"
  echo "🔐 用户名: root | 密码: (您设置的密码)"
  echo "📜 管理命令: ufeasy"
  echo "🔄 证书自动续期已配置"
  echo "⚠️ 注意: 访问根路径将跳转到 example.com"
}

main