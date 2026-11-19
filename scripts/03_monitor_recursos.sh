#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/srv/citizentech/storage"
AUDIT_LOG="${BASE_DIR}/logs/provision_audit.log"

if [[ $EUID -ne 0 ]]; then
  echo "Erro: execute este script como root ou via sudo." >&2
  exit 1
fi

echo "=== [1/2] Implantando daemon de monitoramento de CPU, RAM e Disco ==="
cat << 'MONITOR' > /usr/local/bin/citizentech-monitor.sh
#!/usr/bin/env bash
BASE="/srv/citizentech/storage"
ALERT_LOG="${BASE}/logs/monitor_alerts.log"
CONF_FILE="/etc/citizentech-monitor.conf"

# Limiares padrao (podem ser ajustados em /etc/citizentech-monitor.conf para testes)
CPU_THRESHOLD=80
MEM_THRESHOLD=80
DISK_THRESHOLD=85
INTERVAL=10

[ -f "$CONF_FILE" ] && source "$CONF_FILE"

while true; do
  [ -f "$CONF_FILE" ] && source "$CONF_FILE"
  TS=$(date --iso-8601=seconds)

  # Coleta CPU (% usada = 100 - idle)
  CPU_IDLE=$(top -bn1 | awk '/Cpu\(s\)/ {print $8}' | tr ',' '.' | cut -d'.' -f1)
  CPU_IDLE=${CPU_IDLE:-100}
  CPU_USED=$((100 - CPU_IDLE))

  # Coleta Memoria RAM (%)
  MEM_USED=$(free | awk '/^Mem/ {printf("%.0f", $3/$2 * 100)}')

  # Coleta Disco (%) no volume de armazenamento CitizenTech
  DISK_USED=$(df -P /srv/citizentech/storage | awk 'NR==2 {gsub("%",""); print $5}')

  STATUS_LINE="${TS} [METRICS] CPU=${CPU_USED}% (lim=${CPU_THRESHOLD}%) | MEM=${MEM_USED}% (lim=${MEM_THRESHOLD}%) | DISCO=${DISK_USED}% (lim=${DISK_THRESHOLD}%)"
  echo "$STATUS_LINE" >> "$ALERT_LOG"

  if [ "$CPU_USED" -ge "$CPU_THRESHOLD" ]; then
    MSG="${TS} [ALERTA_CPU] Consumo critico de CPU detectado: ${CPU_USED}% >= ${CPU_THRESHOLD}% em $(hostname)"
    echo "$MSG" >> "$ALERT_LOG"
    logger -p user.warning -t citizentech-monitor "$MSG"
  fi

  if [ "$MEM_USED" -ge "$MEM_THRESHOLD" ]; then
    MSG="${TS} [ALERTA_MEM] Consumo critico de Memoria RAM detectado: ${MEM_USED}% >= ${MEM_THRESHOLD}% em $(hostname)"
    echo "$MSG" >> "$ALERT_LOG"
    logger -p user.warning -t citizentech-monitor "$MSG"
  fi

  if [ "$DISK_USED" -ge "$DISK_THRESHOLD" ]; then
    MSG="${TS} [ALERTA_DISCO] Consumo critico de Disco detectado: ${DISK_USED}% >= ${DISK_THRESHOLD}% em $(hostname)"
    echo "$MSG" >> "$ALERT_LOG"
    logger -p user.warning -t citizentech-monitor "$MSG"
  fi

  sleep "$INTERVAL"
done
MONITOR
chmod 755 /usr/local/bin/citizentech-monitor.sh

cat << 'CONF' > /etc/citizentech-monitor.conf
CPU_THRESHOLD=80
MEM_THRESHOLD=80
DISK_THRESHOLD=85
INTERVAL=10
CONF

echo "=== [2/2] Registrando servico tolerante a falhas no systemd ==="
cat << 'UNIT' > /etc/systemd/system/citizentech-monitor.service
[Unit]
Description=CitizenTech Infrastructure Resource Monitor (CPU, RAM, Disk)
After=network.target local-fs.target citizentech-agent.service

[Service]
Type=simple
User=GustavoYuji_RM555034
Group=citizenops
ExecStart=/usr/local/bin/citizentech-monitor.sh
Restart=always
RestartSec=3
StartLimitIntervalSec=0

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now citizentech-monitor.service
systemctl restart citizentech-monitor.service

echo "$(date --iso-8601=seconds) [MONITOR] [host=$(hostname)] [user=$(whoami)] Servico citizentech-monitor.service ativado com auto-recuperacao (Restart=always)." | tee -a "$AUDIT_LOG"
echo ">>> Monitoramento tolerante a falhas ativo!"
