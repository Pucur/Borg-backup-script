#!/bin/bash

# =========================
# TURNING ON
# =========================
HOMEASSISTANT_URL="http://192.168.1.0:8123"
API_KEY=""
ENTITY="switch.myentity"

curl -X POST $HOMEASSISTANT_URL/api/services/switch/turn_on \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"entity_id\":\"$ENTITY\"}"

HOST="192.168.1.1"

# =========================
# PING CHECK (GATE)
# =========================

echo "Waiting for host $HOST to come online..."

while true; do
    if ping -c 1 -W 1 "$HOST" >/dev/null 2>&1; then
        echo "Host is UP ✔"
        break
    fi

    sleep 5
done

# =========================
# WAIT FOR SYSTEM BOOT ETC...
# =========================

sleep 30

set -o pipefail

USER="ubuntu"
REPO="/mnt/backup"
SOURCE="/mnt/files"

export HOME=/home/ubuntu
export BORG_PASSPHRASE="big_secret"

DATE=$(date +%Y-%m-%d)
LOGFILE="/home/$USER/script/logs/borg-backup-$DATE.log"

START=$(date +%s)

echo "===== BORG BACKUP START: $(date) =====" | tee -a "$LOGFILE"

# =========================
# BACKUP
# =========================

sudo -E -u $USER borg create --compression lz4 \
ssh://$USER@$HOST$REPO::backup-$DATE \
$SOURCE 2>&1 | tee -a "$LOGFILE"

CREATE_EXIT=${PIPESTATUS[0]}

# ha backup fail → ne menjen tovább
if [ $CREATE_EXIT -ne 0 ]; then
    echo "BACKUP FAILED → aborting prune" | tee -a "$LOGFILE"
    PRUNE_EXIT=1
else
    # =========================
    # PRUNE
    # =========================

    sudo -E -u $USER borg prune -v --keep-within 6m \
    ssh://$USER@$HOST$REPO 2>&1 | tee -a "$LOGFILE"

    PRUNE_EXIT=${PIPESTATUS[0]}
fi

# =========================
# SUMMARY
# =========================

END=$(date +%s)
DURATION=$((END - START))

echo "===== BORG BACKUP END: $(date) =====" | tee -a "$LOGFILE"
echo "CREATE EXIT: $CREATE_EXIT" | tee -a "$LOGFILE"
echo "PRUNE EXIT: $PRUNE_EXIT" | tee -a "$LOGFILE"

printf "DURATION: %02d:%02d:%02d\n" \
$((DURATION/3600)) \
$((DURATION%3600/60)) \
$((DURATION%60)) | tee -a "$LOGFILE"

# =========================
# FINAL STATUS
# =========================

if [ $CREATE_EXIT -eq 0 ] && [ $PRUNE_EXIT -eq 0 ]; then
    echo "STATUS: SUCCESS ✅" | tee -a "$LOGFILE"
else
    echo "STATUS: FAILED ❌" | tee -a "$LOGFILE"
fi

# =========================
# POWER OFF TARGET (if success)
# =========================

    echo "Shutting down remote host..." | tee -a "$LOGFILE"

    sudo -E -u $USER ssh $USER@$HOST "sudo /sbin/poweroff" 2>&1 | tee -a "$LOGFILE"

    SHUTDOWN_EXIT=${PIPESTATUS[0]}
    echo "SHUTDOWN EXIT: $SHUTDOWN_EXIT" | tee -a "$LOGFILE"

# =========================
# TURNING OFF
# =========================

sleep 60

curl -X POST $HOMEASSISTANT_URL/api/services/switch/turn_off \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"entity_id\":\"$ENTITY\"}"
