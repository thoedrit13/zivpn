# 🚀 ZIVPN UDP Server Installer

> UDP server installation for **ZIVPN Tunnel (SSH/DNS)** VPN app.
> 🖥️ **Supported Architectures:** Server binary for Linux `amd64` and `arm` (Auto-detected).

---

## 🛠️ วิธีติดตั้ง (Installation)

รันคำสั่งด้านล่างนี้ใน Terminal เพื่อเรียกใช้งาน **ZIVPN Manager Menu** (รองรับการติดตั้ง, แก้ไข, และถอนการติดตั้งในตัวเดียว):

```bash
bash <(curl -fsSL [https://raw.githubusercontent.com/thoedrit13/zivpn/main/setup.sh](https://raw.githubusercontent.com/thoedrit13/zivpn/main/setup.sh))
```

---

## ⚙️ การแก้ไขพอร์ตภายหลัง (Configuration)

หากติดตั้งเสร็จแล้ว และต้องการเปลี่ยน Target Port หรือ Exclude Ports สามารถทำได้ง่ายๆ ผ่านไฟล์ Config ดังนี้:

**1. เปิดไฟล์ตั้งค่าด้วย Text Editor:**
```bash
nano /etc/zivpn/ports.conf
```

**2. แก้ไขตัวเลขพอร์ตตามต้องการ:**
```env
TARGET_PORT=5666
EXCLUDE_PORTS="53,68,111,546,5353,7359,12451,41641,51820,53602,9999"
```
*(บันทึกไฟล์: กด `Ctrl+O` -> `Enter` -> `Ctrl+X`)*

**3. รีสตาร์ทเซอร์วิสเพื่ออัปเดตกฎ iptables ทันที:**
```bash
systemctl daemon-reload
systemctl restart zivpn
```

---

## 🛡️ การตรวจสอบและจัดการ Iptables

**วิธีเช็คว่ากฎ (Rule) Iptables ของ ZIVPN ทำงานหรือยัง:**
```bash
sudo iptables -t nat -L PREROUTING -n --line-numbers
```

**วิธีลบกฎ Iptables แบบกำหนดเอง (Manual Delete):**
หากตรวจสอบด้วยคำสั่งด้านบนแล้วต้องการลบ Rule ออก ให้ดูตัวเลขบรรทัด (Line-numbers) แล้วลบออกดังนี้ *(ตัวอย่างคือการลบ Rule ที่ 2)*:
```bash
iptables -t nat -D PREROUTING 2
```

**บันทึกค่า Iptables ให้เป็นถาวร (ป้องกันการหายหลังรีบูทเครื่อง):**
```bash
sudo iptables-save > /etc/iptables/rules.v4
apt install iptables-persistent
```

---

## 🗑️ วิธีถอนการติดตั้ง (Uninstall)

**1. เปิดเมนูจัดการและเลือกหัวข้อ Uninstall:**
```bash
bash <(curl -fsSL [https://raw.githubusercontent.com/thoedrit13/zivpn/main/setup.sh](https://raw.githubusercontent.com/thoedrit13/zivpn/main/setup.sh))
```

**2. ล้างกฎ Iptables ให้หมดจด (ถ้ามีตกค้าง):**
เช็คหมายเลข Rule ที่เหลืออยู่:
```bash
iptables -t nat -L PREROUTING -n --line-numbers
```
พิมพ์คำสั่งลบ Rule ที่ไม่ต้องการ *(เช่น ลบ Rule บรรทัดที่ 2)* และบันทึกค่า:
```bash
iptables -t nat -D PREROUTING 2
sudo iptables-save > /etc/iptables/rules.v4
apt install iptables-persistent
```

---

## 📱 Client App (แอปพลิเคชันสำหรับเชื่อมต่อ)

สามารถดาวน์โหลดแอปพลิเคชัน **ZiVPN** ได้ฟรีบน Google Play Store:

[![Download on Google Play](https://img.shields.io/badge/Google_Play-Download_App-green?logo=google-play&style=for-the-badge)](https://play.google.com/store/apps/details?id=com.zi.zivpn)
> 🔗 **Link:** [Download ZiVPN on Playstore](https://play.google.com/store/apps/details?id=com.zi.zivpn)
