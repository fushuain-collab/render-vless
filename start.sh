#!/bin/bash
set -e

UUID="${UUID:-e0240134-0986-4b92-a230-fdc8d1200456}"
PORT="${PORT:-10000}"
CF_TOKEN="${CF_TOKEN:-}"
CF_ACCOUNT="${CF_ACCOUNT:-2a59ea0bbb2b91a2c98768cff534bec3}"
KV_NS="${KV_NS:-5d8ac1de6ceb4b9f817c5c335fba1576}"

echo "下载 Xray..."
wget -q -O xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -q xray.zip xray
chmod +x xray

echo "写入配置..."
cat > config.json << CONF
{
  "log": {"loglevel": "warning"},
  "inbounds": [{
    "port": $PORT,
    "listen": "0.0.0.0",
    "protocol": "vless",
    "settings": {
      "clients": [{"id": "$UUID", "level": 0}],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {"path": "/vless"}
    }
  }],
  "outbounds": [{"protocol": "freedom"}]
}
CONF

echo "启动 Xray on port $PORT..."
./xray run -c config.json &

# 等待 xray 就绪
sleep 3

# 获取 Render 服务域名（通过环境变量 RENDER_EXTERNAL_URL）
HOST="${RENDER_EXTERNAL_URL:-}"
if [ -n "$HOST" ]; then
  HOST="${HOST#https://}"
  NODE_NAME="🇺🇸美国-Render"
  VLESS="vless://${UUID}@${HOST}:443?security=tls&type=ws&path=%2Fvless&host=${HOST}&sni=${HOST}&encryption=none#${NODE_NAME}"
  echo "节点: $VLESS"

  # 更新到 CF KV
  if [ -n "$CF_TOKEN" ]; then
    curl -sX PUT "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT}/storage/kv/namespaces/${KV_NS}/values/render_node" \
      -H "Authorization: Bearer ${CF_TOKEN}" \
      -H "Content-Type: text/plain" \
      --data "$VLESS"
    echo "✅ 已更新 KV"
  fi

  # 合并到 Pages 订阅
  EXISTING=$(curl -s "https://vless-sub-bb7.pages.dev/sub" | base64 -d 2>/dev/null || echo "")
  CLEANED=$(echo "$EXISTING" | grep -v "Render" || echo "")
  COMBINED=$(printf "%s\n%s" "$CLEANED" "$VLESS" | base64 -w 0)

  # 安装 wrangler 并部署
  npm install -g wrangler --silent 2>/dev/null
  mkdir -p pages_sub
  echo "$COMBINED" > pages_sub/sub
  echo "ok" > pages_sub/index.html
  CLOUDFLARE_API_TOKEN="${CF_TOKEN}" wrangler pages deploy pages_sub \
    --project-name="vless-sub" \
    --branch="main" 2>&1 | tail -3
  echo "✅ 订阅已更新"
fi

# 保持前台运行
wait