UDP server installation for ZIVPN Tunnel (SSH/DNS) VPN app.
<br>

>Server binary for Linux amd64 and arm.

วิธีติดตั้ง 

#### Instalation Menu

```
bash <(curl -fsSL https://raw.githubusercontent.com/thoedrit13/zivpn/main/setup.sh)
```

วิธีแก้ไขพอร์ตในภายหลัง
```
nano /etc/zivpn/ports.conf
```

สามารถแก้ตัวเลขได้เลย:
```
TARGET_PORT=5666
EXCLUDE_PORTS="53,68,111,546,5353,7359,12451,41641,51820,53602,9999"
```
รีสตาร์ท เพื่อแสดงผล
```
systemctl daemon-reload
systemctl restart zivpn
```
เช็คว่า กฏ iptables ขึ้นมาหรือยัง
```
sudo iptables -t nat -L PREROUTING -n --line-numbers
```
ถ้าต้องการเช็ค หรือ ถ้าต้องการลบ iptables ตัวเดิมออก
```
iptables -t nat -L PREROUTING -n --line-numbers
```
ดูว่าคือ rule ไหน เช่น 2
```
iptables -t nat -D PREROUTING 2
sudo iptables-save > /etc/iptables/rules.v4
apt install iptables-persistent
```
# สร้าง User ป้องกันการรีโมท 
```
sudo useradd -m -s /bin/false userrr
```

# ตั้งรหัสผ่านให้ User (พิมพ์ 2 รอบ จะไม่แสดงบนจอ)
```
sudo passwd userrr
```



หากต้องการลบ
```
bash <(curl -fsSL https://raw.githubusercontent.com/thoedrit13/zivpn/main/setup.sh)
```
และ

ล้างกฎ Iptables ให้หมด
```
iptables -t nat -L PREROUTING -n --line-numbers
```
ดูว่าคือ rule ไหน เช่น 2
```
iptables -t nat -D PREROUTING 2
sudo iptables-save > /etc/iptables/rules.v4
apt install iptables-persistent
```

ลบบัญชีผู้ใช้

```
sudo userdel -r userrrr
```


Client App available:

<a href="https://play.google.com/store/apps/details?id=com.zi.zivpn" target="_blank" rel="noreferrer">Download APP on Playstore</a>
> ZiVPN
                
----
