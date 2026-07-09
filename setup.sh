#!/bin/bash
# ZIVPN Menu - Universal Installer & Manager
# Modified with Auto-Architecture, Dynamic Ports, and Standalone Logic

IP=$(curl -4 -s icanhazip.com)
distribution=$( (lsb_release -ds || cat /etc/*release || uname -om) 2>/dev/null | head -n1 )
Network=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
ports=$(netstat -tunlp 2>/dev/null | grep zivpn | grep ::: | awk '{print substr($4,4); }' | tr '\n' ' ')

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
GRAY='\033[1;37m'
WHITE='\033[1;37m'
RESET='\033[0m'

# Check Root
if [ $(id -u) -ne 0 ]; then
    echo -e "${RED}Please run the script as root user (sudo -i)${RESET}"
    exit 1
fi

# ==========================================
# 1. INSTALL FUNCTION (Universal)
# ==========================================
function install_universal(){
    echo -e "${RED} ────────────── /// ─────────────── ${RESET}"
    echo -e "${YELLOW}This will install ZIVPN (Auto AMD/ARM) with Custom Ports.${RESET}"
    read -p "Continue? [Y/N]: " yesno
    if [[ ${yesno} == @(y|Y) ]]; then
        echo -e "\n${YELLOW}[1] ZIVPN UDP Passwords${RESET}"
        read -p "Enter passwords separated by commas (Default 'zi'): " input_config
        if [ -n "$input_config" ]; then
            IFS=',' read -r -a config <<< "$input_config"
            if [ ${#config[@]} -eq 1 ]; then config+=(${config[0]}); fi
        else
            config=("zi")
        fi
        JSON_PASSWORDS=$(printf "\"%s\"," "${config[@]}" | sed 's/,$//')

        echo -e "\n${YELLOW}[2] ZIVPN Ports Configuration${RESET}"
        read -p "Enter Target Port (Default '5667'): " input_target_port
        TARGET_PORT=${input_target_port:-5667}
        DEFAULT_EXCLUDE="53,68,111,546,5353,7359,12451,41641,51820,53602"
        read -p "Enter Exclude Ports (Default '$DEFAULT_EXCLUDE'): " input_exclude_ports
        EXCLUDE_PORTS=${input_exclude_ports:-$DEFAULT_EXCLUDE}

        echo -e "\n${GREEN}Updating server...${RESET}"
        sudo apt-get update && apt-get upgrade -y
        systemctl stop zivpn.service 1> /dev/null 2> /dev/null

        ARCH=$(uname -m)
        if [[ "$ARCH" == "x86_64" ]]; then
            BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"
        elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
            BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm64"
        else
            echo -e "${RED}Unsupported architecture: $ARCH${RESET}"
            sleep 3; return
        fi

        echo -e "${GREEN}Downloading ZIVPN Binary ($ARCH)...${RESET}"
        wget $BIN_URL -O /usr/local/bin/zivpn 1> /dev/null 2> /dev/null
        chmod +x /usr/local/bin/zivpn
        mkdir -p /etc/zivpn 1> /dev/null 2> /dev/null

        echo -e "${GREEN}Generating 10-Year Certificates...${RESET}"
        openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=US/ST=CA/L=LA/O=Corp/CN=zivpn" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2>/dev/null

        sysctl -w net.core.rmem_max=16777216 1> /dev/null 2> /dev/null
        sysctl -w net.core.wmem_max=16777216 1> /dev/null 2> /dev/null

        cat <<EOF > /etc/zivpn/config.json
{
  "listen": ":$TARGET_PORT",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs":"zivpn",
  "auth": { "mode": "passwords", "config": [$JSON_PASSWORDS] }
}
EOF

        cat <<EOF > /etc/zivpn/ports.conf
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
[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable zivpn.service 1> /dev/null 2> /dev/null
        systemctl start zivpn.service

        echo -e "${GREEN}ZIVPN Installed Successfully!${RESET}"
        sleep 3
    fi
}

# ==========================================
# 2. UNINSTALL FUNCTION
# ==========================================
function uninstall(){
    echo -e "${RED} ────────────── /// ─────────────── ${RESET}"
    echo -e "${YELLOW}This will COMPLETELY UNINSTALL ZIVPN and remove port rules.${RESET}"
    read -p "Continue? [Y/N]: " yesno
    if [[ ${yesno} == @(y|Y) ]]; then
        echo -e "${YELLOW}Uninstalling...${RESET}"
        systemctl stop zivpn.service 1> /dev/null 2> /dev/null
        systemctl disable zivpn.service 1> /dev/null 2> /dev/null
        
        # Clean up iptables rules
        iptables -t nat -L PREROUTING --line-numbers -n | grep "zivpn-rule" | awk '{print $1}' | sort -nr | while read num; do
            iptables -t nat -D PREROUTING $num
        done
        
        rm -rf /etc/zivpn
        rm -f /usr/local/bin/zivpn
        rm -f /usr/local/bin/zivpn-iptables.sh
        rm -f /etc/systemd/system/zivpn.service
        systemctl daemon-reload
        
        echo -e "${GREEN}Uninstall Complete!${RESET}"
        sleep 2
    fi
}

# ==========================================
# 3. SERVICE CONTROLS
# ==========================================
function control_service(){
    ACTION=$1
    echo -e "${YELLOW}${ACTION^^}ING ZIVPN...${RESET}"
    systemctl $ACTION zivpn.service 2>/dev/null
    echo -e "${GREEN}DONE!${RESET}"
    sleep 2
}

# ==========================================
# MAIN MENU LOOP
# ==========================================
while true; do
    clear
    ports=$(netstat -tunlp 2>/dev/null | grep zivpn | grep ::: | awk '{print substr($4,4); }' | tr '\n' ' ')
    [[ -z "$ports" ]] && ports="Not Running"

    echo -e "${GRAY}[${RED}-${GRAY}]${RED} ────────────── /// ─────────────── ${RESET}"
    echo -e "${YELLOW}   【          ${RED}ZIVPN MANAGER           ${YELLOW}】 ${RESET}"
    echo -e "${YELLOW} › ${WHITE}Linux Dist: ${GREEN}$distribution ${RESET}"
    echo -e "${YELLOW} › ${WHITE}IP: ${GREEN}$IP ${RESET}"
    echo -e "${YELLOW} › ${WHITE}Network: ${GREEN}$Network ${RESET}"
    echo -e "${YELLOW} › ${WHITE}Running on Port: ${GREEN}$ports ${RESET}"
    echo -e "${GRAY}[${RED}-${GRAY}]${RED} ────────────── /// ─────────────── ${RESET}"
    echo -e "${YELLOW}[${GREEN}1${YELLOW}] ${RED} › ${WHITE} INSTALL ZIVPN (Universal Auto AMD/ARM)${RESET}"
    echo -e "${YELLOW}[${GREEN}2${YELLOW}] ${RED} › ${WHITE} EDIT PORTS CONFIG (nano /etc/zivpn/ports.conf)${RESET}"
    echo -e "${YELLOW}[${GREEN}3${YELLOW}] ${RED} › ${WHITE} UNINSTALL ZIVPN${RESET}"
    echo -e "${YELLOW}[${GREEN}-${YELLOW}] ${RED} ────────${RESET}"
    echo -e "${YELLOW}[${GREEN}4${YELLOW}] ${RED} › ${WHITE} START ZIVPN${RESET}"
    echo -e "${YELLOW}[${GREEN}5${YELLOW}] ${RED} › ${WHITE} STOP ZIVPN${RESET}"
    echo -e "${YELLOW}[${GREEN}6${YELLOW}] ${RED} › ${WHITE} RESTART ZIVPN${RESET}"
    echo -e "${YELLOW}[${GREEN}0${YELLOW}] ${RED} › ${WHITE} EXIT${RESET}"
    echo -e "${GRAY}[${RED}-${GRAY}]${RED} ────────────── /// ─────────────── ${RESET}"
    read -p " Δ CHOOSE AN OPTION: " option

    case $option in
        1|01) install_universal ;;
        2|02) 
            if [ -f /etc/zivpn/ports.conf ]; then
                nano /etc/zivpn/ports.conf
                echo -e "${YELLOW}Restarting ZIVPN to apply new ports...${RESET}"
                systemctl restart zivpn.service
            else
                echo -e "${RED}ZIVPN is not installed yet!${RESET}"
                sleep 2
            fi
            ;;
        3|03) uninstall ;;
        4|04) control_service start ;;
        5|05) control_service stop ;;
        6|06) control_service restart ;;
        0) clear; exit 0 ;;
        *) continue ;;
    esac
done
