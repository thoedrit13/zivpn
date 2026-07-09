#!/bin/bash
# - ZiVPN Remover (Complete Cleanup) -

clear
echo -e "Uninstalling ZiVPN ..."

# 1. Stop and Disable Services
systemctl stop zivpn.service 1> /dev/null 2> /dev/null
systemctl stop zivpn_backfill.service 1> /dev/null 2> /dev/null
systemctl disable zivpn.service 1> /dev/null 2> /dev/null
systemctl disable zivpn_backfill.service 1> /dev/null 2> /dev/null
rm -f /etc/systemd/system/zivpn.service
rm -f /etc/systemd/system/zivpn_backfill.service
systemctl daemon-reload

# 2. Kill running processes
killall zivpn 1> /dev/null 2> /dev/null

# 3. Clean up iptables rules (New Script Tags & Legacy Rules)
echo -e "Cleaning up iptables rules..."

# ลบกฎใหม่ที่มี Tag "zivpn-rule"
iptables -t nat -L PREROUTING --line-numbers -n | grep "zivpn-rule" | awk '{print $1}' | sort -nr | while read num; do
    iptables -t nat -D PREROUTING $num
done

# ลบกฎเก่า (Legacy) ที่อาจตกค้างจากการติดตั้งเวอร์ชันก่อนหน้า (พอร์ต 5666 และ 5667)
while true; do
    RULE=$(iptables -t nat -L PREROUTING --line-numbers -n | grep -E "to:5666|to:5667" | head -1 | awk '{print $1}')
    [ -z "$RULE" ] && break
    iptables -t nat -D PREROUTING "$RULE"
done

# 4. Remove Files and Directories
rm -rf /etc/zivpn 1> /dev/null 2> /dev/null
rm -f /usr/local/bin/zivpn 1> /dev/null 2> /dev/null
rm -f /usr/local/bin/zivpn-iptables.sh 1> /dev/null 2> /dev/null

# 5. Check Status
if pgrep "zivpn" >/dev/null; then
    echo -e "Server is still running (Warning)"
else
    echo -e "Server Stopped"
fi

if [ -e "/usr/local/bin/zivpn" ]; then
    echo -e "Files still remaining, try again"
else
    echo -e "Successfully Removed"
fi

# 6. Clean Cache & Swap
echo "Cleaning Cache & Swap"
echo 3 > /proc/sys/vm/drop_caches
sysctl -w vm.drop_caches=3 1> /dev/null 2> /dev/null
swapoff -a && swapon -a

echo -e "Done. ZIVPN has been completely removed from your system."
