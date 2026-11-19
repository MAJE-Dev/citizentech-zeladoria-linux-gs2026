#!/usr/bin/env bash
BASE="/srv/citizentech/storage"
LOG="${BASE}/logs/agent.log"
STATUS_FILE="${BASE}/status.txt"
EQUIPE_RMS="RM556452, RM555034, RM556095, RM555885, RM556404"

while true; do
  TS=$(date --iso-8601=seconds)
  if ! mountpoint -q "$BASE" || [ ! -w "$BASE" ]; then
    logger -p user.err -t citizentech-agent "ERRO_GRAVACAO: Volume ${BASE} indisponivel ou sem permissao de escrita em $(hostname)"
    exit 1
  fi

  cat << STATUS > "$STATUS_FILE"
PROJETO: CitizenTech Zeladoria Urbana (ODS 11 & ODS 9)
GRUPO: MAJE | TURMA: 3ESPH
RMS_EQUIPE: ${EQUIPE_RMS}
EXECUTOR: $(whoami)
HOSTNAME: $(hostname)
ULTIMA_ATUALIZACAO: ${TS}
STATUS_OPERACIONAL: ATIVO_SEM_FALHAS
STATUS

  echo "${TS} [INFO] Ciclo ativo | host=$(hostname) | user=$(whoami) | RMs=[${EQUIPE_RMS}]" >> "$LOG"
  logger -t citizentech-agent "Ciclo ativo em $(hostname) por $(whoami) | RMs: ${EQUIPE_RMS}"

  for f in "${BASE}/inbox"/*.txt; do
    [ -e "$f" ] || continue
    mv "$f" "${BASE}/processed/"
    echo "${TS} [PROC] Ocorrencia processada: $(basename "$f")" >> "$LOG"
  done
  sleep 15
done
