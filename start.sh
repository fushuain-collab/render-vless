#!/bin/bash
set -e

UUID="${UUID:-e0240134-0986-4b92-a230-fdc8d1200456}"
PORT="${PORT:-8080}"

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
exec ./xray run -c config.json
