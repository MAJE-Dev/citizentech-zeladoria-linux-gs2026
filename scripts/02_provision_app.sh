#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/srv/citizentech/storage"
AUDIT_LOG="${BASE_DIR}/logs/provision_audit.log"
APP_USER="GustavoYuji_RM555034"
GROUP_NAME="citizenops"

log_audit() {
  local msg="$1"
  local ts
  ts=$(date --iso-8601=seconds)
  echo "${ts} [APP] [host=$(hostname)] [user=$(whoami)] ${msg}" | tee -a "$AUDIT_LOG"
  logger -t citizentech-app "$msg" || true
}

if [[ $EUID -ne 0 ]]; then
  echo "Erro: execute este script como root ou via sudo." >&2
  exit 1
fi

echo "=== [1/3] Criando arvore operacional de zeladoria urbana e permissoes SGID ==="
mkdir -p "${BASE_DIR}"/{inbox,processed,logs,quarantine}
chown -R OtavioFerrao_RM556452:"$GROUP_NAME" /srv/citizentech
chmod -R 2770 /srv/citizentech
chmod 2750 "${BASE_DIR}/quarantine"
log_audit "Diretorios inbox, processed, logs e quarantine configurados com SGID (2770/2750)."

echo "=== [2/3] Implantando executavel do Agente CitizenTech ==="
cat << 'AGENT' > /usr/local/bin/citizentech-agent.sh
#!/usr/bin/env bash
BASE="/srv/citizentech/storage"
LOG="${BASE}/logs/agent.log"

while true; do
  TS=$(date --iso-8601=seconds)
  echo "${TS} [INFO] Ciclo de zeladoria urbana ativo em $(hostname) (usuario=$(whoami))" >> "$LOG"
  for f in "${BASE}/inbox"/*.txt; do
    [ -e "$f" ] || continue
    mv "$f" "${BASE}/processed/"
    echo "${TS} [PROC] Ocorrencia processada: $(basename "$f")" >> "$LOG"
  done
  sleep 15
done
AGENT
chmod 755 /usr/local/bin/citizentech-agent.sh

echo "=== [3/3] Configurando e iniciando servico systemd citizentech-agent ==="
cat << 'UNIT' > /etc/systemd/system/citizentech-agent.service
[Unit]
Description=CitizenTech Zeladoria Urbana Agent (ODS 11 - Sao Paulo)
After=network.target local-fs.target

[Service]
Type=simple
User=GustavoYuji_RM555034
Group=citizenops
ExecStart=/usr/local/bin/citizentech-agent.sh
Restart=always
RestartSec=5
StartLimitIntervalSec=0

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now citizentech-agent.service
systemctl restart citizentech-agent.service
log_audit "Servico citizentech-agent.service orquestrado e ativo sob usuario ${APP_USER}."
echo ">>> Provisionamento da Aplicacao concluido com sucesso!"
