#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/srv/citizentech/storage"
AUDIT_LOG="${BASE_DIR}/logs/provision_audit.log"

echo "=================================================================="
echo " AUDITORIA E VALIDACAO PONTA A PONTA - CITIZENTECH ZELADORIA"
echo " Data: $(date --iso-8601=seconds) | Host: $(hostname) | User: $(whoami)"
echo "=================================================================="

echo -e "\n[1] Validando Grupo e Usuarios Nominais:"
getent group citizenops

echo -e "\n[2] Validando Armazenamento Dedicado (/dev/sdb1):"
df -h /srv/citizentech/storage

echo -e "\n[3] Validando Servicos Systemd (Agente + Monitoramento):"
echo " - citizentech-agent.service:   $(systemctl is-active citizentech-agent.service)"
echo " - citizentech-monitor.service: $(systemctl is-active citizentech-monitor.service)"
echo " - named (BIND9 DNS):           $(systemctl is-active named)"
echo " - ssh (OpenSSH Server):        $(systemctl is-active ssh)"

echo -e "\n[4] Validando Resolucao DNS Autoritativa (.test):"
echo " - node.citizentechzeladoria.test   -> $(dig @127.0.0.1 node.citizentechzeladoria.test +short)"
echo " - client.citizentechzeladoria.test -> $(dig @127.0.0.1 client.citizentechzeladoria.test +short)"
echo " - api.citizentechzeladoria.test    -> $(dig @127.0.0.1 api.citizentechzeladoria.test +short | tr '\n' ' ')"
echo " - Reverso 192.168.56.10            -> $(dig @127.0.0.1 -x 192.168.56.10 +short)"

echo -e "\n[5] Ultimos Registros de Auditoria (provision_audit.log):"
tail -n 6 "$AUDIT_LOG"

echo -e "\n[6] Ultimas Metricas e Alertas de Infraestrutura (monitor_alerts.log):"
tail -n 6 "${BASE_DIR}/logs/monitor_alerts.log"

echo -e "\n=================================================================="
echo " VALIDACAO CONCLUIDA COM SUCESSO!"
echo "=================================================================="
