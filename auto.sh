#!/bin/bash
# Zivpn UDP Module installer - Universal (AMD64 & ARM64)
# Creator Zahid Islam (Modified for Auto-Arch, Dynamic Ports, and Robust Config)

echo -e "\n====================================="
echo -e " 1. ZIVPN UDP Passwords"
echo -e "====================================="
read -p "Enter passwords separated by commas, example: pass1,pass2 (Press enter for Default 'zi'): " input_config

if [ -n "$input_config" ]; then
    IFS=',' read -r -a config <<< "$input_config"
    if [ ${#config[@]} -eq 1 ]; then
        config+=(${config[0]})
    fi
else
    config=("zi")
fi

JSON_PASSWORDS=$(printf "\"%s\"," "${config[@]}" | sed 's/,$//')

echo -e "\n====================================="
echo -e " 2. ZIVPN Ports Configuration"
echo -e "====================================="
read -p "Enter Target Port (Press enter for Default '5667'): " input_target_port
TARGET_PORT=${input_target_port:-5667}

DEFAULT_EXCLUDE="53,68,111,546,5353,7359,12451,41641,51820,53602"
read -p "Enter Exclude Ports (Press enter for Default '$DEFAULT_EXCLUDE'): " input_exclude_ports
EXCLUDE_PORTS=${input_exclude_ports:-$DEFAULT_EXCLUDE}

echo -e "\nUpdating server..."
sudo apt-get update && apt-get upgrade -y
systemctl stop zivpn.service 1> /dev/null 2> /dev/null

# ==========================================
# ตรวจสอบ CPU Architecture และกำหนดลิงก์ดาวน์โหลด
# ==========================================
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    echo -e "Detected Architecture: AMD64 (x86_64)"
    BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    echo -e "Detected Architecture: ARM64 (aarch64)"
    BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm64"
else
    echo -e "Unsupported architecture: $ARCH"
    exit 1
fi

echo -e "Downloading UDP Service Binary..."
wget $BIN_URL -O /usr/local/bin/zivpn 1> /dev/null 2> /dev/null
chmod +x /usr/local/bin/zivpn
mkdir -p /etc/zivpn 1> /dev/null 2> /dev/null

echo "Generating cert files (Valid for 10 years)..."
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2>/dev/null

sysctl -w net.core.rmem_max=16777216 1> /dev/null 2> /dev/null
sysctl -w net.core.wmem_max=16777216 1> /dev/null 2> /dev/null

echo "Generating config.json locally..."
cat <<EOF > /etc/zivpn/config.json
{
  "listen": ":$TARGET_PORT",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs":"zivpn",
  "auth": {
    "mode": "passwords",
    "config": [$JSON_PASSWORDS]
  }
}
EOF

cat <<EOF > /etc/zivpn/ports.conf
# ZIVPN Port Configuration
TARGET_PORT=$TARGET_PORT
EXCLUDE_PORTS="$EXCLUDE_PORTS"
EOF

cat <<'EOF' > /usr/local/bin/zivpn-iptables.sh
#!/bin/bash
source /etc/zivpn/ports.conf

TABLE=nat
CHAIN=PREROUTING
INTERFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

iptables -t $TABLE -L $CHAIN --line-numbers -n | grep "zivpn-rule" | awk '{print $1}' | sort -nr | while read num; do
    iptables -t $TABLE -D $CHAIN $num
done

IFS=',' read -ra PORTS <<< "$EXCLUDE_PORTS"
PORTS=($(printf "%s\n" "${PORTS[@]}" | sort -n | uniq))
START=1

for P in "${PORTS[@]}"; do
    END=$((P-1))
    if [ $START -le $END ]; then
        iptables -t $TABLE -A $CHAIN -i $INTERFACE -p udp --dport ${START}:${END} -j DNAT --to-destination :${TARGET_PORT} -m comment --comment "zivpn-rule"
    fi
    START=$((P+1))
done

if [ $START -le 65535 ]; then
    iptables -t $TABLE -A $CHAIN -i $INTERFACE -p udp --dport ${START}:65535 -j DNAT --to-destination :${TARGET_PORT} -m comment --comment "zivpn-rule"
fi

ufw allow ${TARGET_PORT}/udp > /dev/null 2>&1
EOF

chmod +x /usr/local/bin/zivpn-iptables.sh

cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=zivpn VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStartPre=/usr/local/bin/zivpn-iptables.sh
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zivpn.service
systemctl start zivpn.service

rm zi2.* 1> /dev/null 2> /dev/null

echo -e "\nZIVPN Installed Successfully on $ARCH!"
systemctl status zivpn --no-pager | head -n 5
echo -e "\n======================================================="
echo -e "You can modify ports later in: /etc/zivpn/ports.conf"
echo -e "Then run: systemctl restart zivpn"
echo -e "======================================================="
