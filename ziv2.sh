#!/bin/bash
# Zivpn UDP Module installer - AMD x64 + Dynamic Auto Exclude
# Creator Zahid Islam
# Bash by PowerMX (Modified for Configurable Ports)

echo -e "Updating server..."
sudo apt-get update && apt-get upgrade -y
systemctl stop zivpn.service 1> /dev/null 2> /dev/null

echo -e "Downloading UDP Service..."
wget https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn 1> /dev/null 2> /dev/null
chmod +x /usr/local/bin/zivpn
mkdir -p /etc/zivpn 1> /dev/null 2> /dev/null
wget https://raw.githubusercontent.com/zahidbd2/udp-zivpn/main/config.json -O /etc/zivpn/config.json 1> /dev/null 2> /dev/null

echo "Generating cert files..."
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2>/dev/null

sysctl -w net.core.rmem_max=16777216 1> /dev/null 2> /dev/null
sysctl -w net.core.wmem_max=16777216 1> /dev/null 2> /dev/null

echo -e "\n====================================="
echo -e " ZIVPN UDP Passwords"
echo -e "====================================="
read -p "Enter passwords separated by commas, example: passwd1,passwd2 (Press enter for Default 'zi'): " input_config

if [ -n "$input_config" ]; then
    IFS=',' read -r -a config <<< "$input_config"
    if [ ${#config[@]} -eq 1 ]; then
        config+=(${config[0]})
    fi
else
    config=("zi")
fi

new_config_str="\"config\": [$(printf "\"%s\"," "${config[@]}" | sed 's/,$//')]"
sed -i -E "s/\"config\": ?\[[[:space:]]*\"zi\"[[:space:]]*\]/${new_config_str}/g" /etc/zivpn/config.json

echo -e "\n====================================="
echo -e " ZIVPN Ports Configuration"
echo -e "====================================="
# ค่าเริ่มต้นเป็น 5667 ตามสคริปต์ต้นฉบับ
read -p "Enter Target Port (Press enter for Default '5667'): " input_target_port
TARGET_PORT=${input_target_port:-5667}

DEFAULT_EXCLUDE="53,68,111,546,5353,7359,12451,41641,51820,53602"
read -p "Enter Exclude Ports (Press enter for Default '$DEFAULT_EXCLUDE'): " input_exclude_ports
EXCLUDE_PORTS=${input_exclude_ports:-$DEFAULT_EXCLUDE}

# สร้างไฟล์ Config สำหรับเก็บค่าพอร์ต
cat <<EOF > /etc/zivpn/ports.conf
# ZIVPN Port Configuration
# แก้ไขค่าด้านล่าง แล้วสั่ง 'systemctl restart zivpn' เพื่ออัปเดตกฎ iptables
TARGET_PORT=$TARGET_PORT
EXCLUDE_PORTS="$EXCLUDE_PORTS"
EOF

# สร้าง Script สำหรับจัดการ iptables อัตโนมัติ
cat <<'EOF' > /usr/local/bin/zivpn-iptables.sh
#!/bin/bash
source /etc/zivpn/ports.conf

TABLE=nat
CHAIN=PREROUTING
INTERFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

# ค้นหาและลบกฎเดิมของ ZIVPN (ลบย้อนกลับเพื่อไม่ให้บรรทัดรวน)
iptables -t $TABLE -L $CHAIN --line-numbers -n | grep "zivpn-rule" | awk '{print $1}' | sort -nr | while read num; do
    iptables -t $TABLE -D $CHAIN $num
done

IFS=',' read -ra PORTS <<< "$EXCLUDE_PORTS"
PORTS=($(printf "%s\n" "${PORTS[@]}" | sort -n | uniq))
START=1

# สร้างกฎ Forward ใหม่แบบหลบพอร์ตที่ยกเว้น
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

# อนุญาตพอร์ต UFW
ufw allow ${TARGET_PORT}/udp > /dev/null 2>&1
EOF

chmod +x /usr/local/bin/zivpn-iptables.sh

# สร้างไฟล์ Systemd Service
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

# ทำความสะอาดไฟล์ตามสคริปต์ต้นฉบับ
rm zi2.* 1> /dev/null 2> /dev/null

echo -e "\nZIVPN Installed Successfully!"
echo -e "\n--- Current PREROUTING Rules ---"
iptables -t nat -L PREROUTING -n --line-numbers | grep -E "zivpn-rule|Chain"
echo -e "\n======================================================="
echo -e "You can modify ports later in: /etc/zivpn/ports.conf"
echo -e "Then run: systemctl restart zivpn"
echo -e "======================================================="
