#!/usr/bin/env bash
set -euo pipefail

# ========= 固定参数（无需改） =========
WEBUI_PORT=5000                         # ufw-webui 仅本地监听
DNS_CRED_FILE="/root/.secrets/dns.ini"
CONF_FILE="/etc/ufeasy.conf"            # 持久化配置
DNS_PLUGIN=""                           # 动态决定
# =====================================

check_root() {
  [[ "$(id -u)" -eq 0 ]] || { echo "❌ 请以 root 身份运行"; exit 1; }
}

gen_slug() { openssl rand -hex 6; }     # 12 位随机串

# ---------- 交互收集信息 ----------
prompt_user() {
  echo "🔧 基本信息配置"
  read -rp "1️⃣ 请输入域名 (如: example.com): " DOMAIN
  read -rp "2️⃣ 请输入邮箱 (Let’s Encrypt): " EMAIL
  read -rp "3️⃣ 请输入外网访问端口 [默认2096]: " p; LISTEN_PORT=${p:-2096}
  echo -n "4️⃣ 请输入 Web Basic-Auth 密码 (用户名 root): "
  read -rs BASIC_PASS; echo
  SLUG=$(gen_slug)
  echo -e "✅ 已生成随机路径：\e[32m/${SLUG}/\e[0m"

  echo "5️⃣ 选择 DNS 解析商:"
  echo "   1) Cloudflare"
  echo "   2) Aliyun"
  echo "   3) Tencent DNSPod"
  read -rp "输入序号: " dns_choice
  case "$dns_choice" in
    1) DNS_PLUGIN="dns-cloudflare"; prompt_cf ;;
    2) DNS_PLUGIN="dns-aliyun";      prompt_aliyun ;;
    3) DNS_PLUGIN="dns-dnspod";      prompt_dnspod ;;
    *) echo "❌ 无效选择"; exit 1 ;;
  esac
}

prompt_cf() {
  read -rsp "🔑 Cloudflare API Token: " token; echo
  mkdir -p "$(dirname "$DNS_CRED_FILE")"
  echo "dns_cloudflare_api_token = $token" >"$DNS_CRED_FILE"
}
prompt_aliyun() {
  read -rp  "🔑 Aliyun AccessKey ID: " id
  read -rsp "🔐 Aliyun AccessKey Secret: " sec; echo
  mkdir -p "$(dirname "$DNS_CRED_FILE")"
  {
    echo "dns_aliyun_access_key_id = $id"
    echo "dns_aliyun_access_key_secret = $sec"
  } >"$DNS_CRED_FILE"
}
prompt_dnspod() {
  read -rp  "🔑 DNSPod ID: " id
  read -rsp "🔐 DNSPod Token: " token; echo
  mkdir -p "$(dirname "$DNS_CRED_FILE")"
  {
    echo "dns_dnspod_api_id = $id"
    echo "dns_dnspod_api_token = $token"
  } >"$DNS_CRED_FILE"
}

# ---------- 系统安装 ----------
install_pkg() {
  apt update
  apt install -y git python3 python3-pip nginx ufw certbot \
                 python3-certbot-${DNS_PLUGIN} apache2-utils
}

deploy_ufw_webui() {
  git clone --depth=1 https://github.com/BryanHeBY/ufw-webui /opt/ufw-webui 2>/dev/null || true
  pip3 install -q -r /opt/ufw-webui/requirements.txt
  cat >/etc/systemd/system/ufw-webui.service <<EOF
[Unit]
Description=UFW WebUI
After=network.target
[Service]
WorkingDirectory=/opt/ufw-webui
ExecStart=/usr/bin/python3 /opt/ufw-webui/app.py --host 127.0.0.1 --port ${WEBUI_PORT}
Restart=always
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now ufw-webui
}

issue_cert() {
  chmod 600 "$DNS_CRED_FILE"
  certbot certonly --${DNS_PLUGIN} \
    --${DNS_PLUGIN}-credentials "$DNS_CRED_FILE" \
    --${DNS_PLUGIN}-propagation-seconds 60 \
    -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" \
    --cert-name ufw-webui
  mkdir -p /etc/letsencrypt/renewal-hooks/post
  echo "systemctl reload nginx" >/etc/letsencrypt/renewal-hooks/post/reload-nginx.sh
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

    # 匹配正确路径才反代
    location /${SLUG}/ {
        proxy_pass http://127.0.0.1:${WEBUI_PORT}/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        auth_basic "Restricted";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }

    # 其它路径一律跳转 example.com
    location / {
        return 302 https://example.com;
    }
}
EOF
  ln -sf /etc/nginx/sites-available/ufw-webui /etc/nginx/sites-enabled/
  nginx -t
  systemctl reload nginx
}

setup_ufw() {
  ufw allow 22/tcp
  ufw allow ${LISTEN_PORT}/tcp
  ufw deny  ${WEBUI_PORT}/tcp
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
[[ -f "$CONF" ]] || { echo "ufeasy: 配置文件不存在"; exit 1; }
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
  SLUG="$NEW"
  systemctl reload nginx
  echo "✅ 路径已改为 /$SLUG/"
}
set_port() {
  NEW="$1"; [[ -z "$NEW" ]] && { echo "用法: ufeasy set-port <端口>"; exit 1; }
  sed -i "s|listen $PORT |listen $NEW |" /etc/nginx/sites-available/ufw-webui
  sed -i "s|^PORT=.*|PORT=$NEW|" "$CONF"
  ufw allow "$NEW"/tcp
  ufw delete allow "$PORT"/tcp
  PORT="$NEW"
  systemctl reload nginx
  echo "✅ 端口已改为 $PORT"
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
  echo "🔐 用户 root / 密码 (安装时设定)"
  echo "📜 查看信息: 运行  ufeasy"
}

main