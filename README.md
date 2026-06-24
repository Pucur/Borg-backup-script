# 🧠 Home Server Backup & Power Cycle Script

This is a fully automated **backup + shutdown + power control pipeline** written in Bash.  
It handles Borg backups, system shutdown, and power switching via Home Assistant — all in one go.
The original idea was to have a very large power-hungry device only wake up when a backup was being saved to it.

---

## ⚙️ What does it do?

Step by step:

### 🔌 1. Power ON remote host
First, it powers on the target server using a Home Assistant API call:

- `switch.turn_on` → Sonoff / server rack power switch

---

### 🌐 2. Wait for host to come online
The script then waits until the server responds:

- continuously pings the target host
- proceeds only when it is reachable
- adds extra delay for full boot & services initialization

---

### 💾 3. Backup with BorgBackup (needs for install first, and init the remote host)
Core backup process:

- runs `borg create`
- uses SSH to reach the backup repository
- compresses data with `lz4` for speed
- writes logs to a date-stamped log file

---

### 🧹 4. Retention cleanup (prune)
If backup succeeds:

- runs `borg prune`
- keeps backups within a 6-month retention window

---

### 📊 5. Summary report
At the end, the script prints:

- backup status (success/fail)
- prune status
- execution time
- final overall status (✅ / ❌)

---

### 🖥️ 6. Remote shutdown
Once backup is complete:

- triggers `poweroff` via SSH
- ensures graceful system shutdown

---

### 🔌 7. Power OFF remote host
Finally:

- calls Home Assistant API → `switch.turn_off`
- completely powers down the system environment
