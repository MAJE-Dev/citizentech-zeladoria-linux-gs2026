#!/usr/bin/env bash
set -euo pipefail

# Variáveis de Infraestrutura - CitizenTech Zeladoria Urbana (ODS 11)
NODE_HOSTNAME="ct-node-rm556452"
NODE_IP="192.168.56.10"
CLIENT_IP="192.168.56.20"
DOMAIN="citizentechzeladoria.test"
GROUP_NAME="citizenops"
DISK_DEV="/dev/sdb"
PART_DEV="/dev/sdb1"
MOUNT_POINT="/srv/citizentech/storage"
AUDIT_LOG="${MOUNT_POINT}/logs/provision_audit.log"

ALUNOS=(
  "OtavioFerrao_RM556452"
  "GustavoYuji_RM555034"
  "KaioDrago_RM556095"
  "GustavoViega_RM555885"
  "VitorRivas_RM556404"
)

log_audit() {
  local msg="$1"
  local ts
  ts=$(date --iso-8601=seconds)
  echo "${ts} [INFRA] [host=$(hostname)] [user=$(whoami)] ${msg}" | tee -a "$AUDIT_LOG" 2>/dev/null || echo "${ts} [INFRA] ${msg}"
  logger -t citizentech-infra "$msg" || true
}

if [[ $EUID -ne 0 ]]; then
  echo "Erro: execute este script como root ou via sudo." >&2
  exit 1
fi

echo "=== [1/5] Instalando pacotes base de infraestrutura ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq openssh-server bind9 bind9-utils dnsutils parted util-linux

echo "=== [2/5] Configurando hostname e resolucao local ==="
hostnamectl set-hostname "$NODE_HOSTNAME"
grep -q "$NODE_HOSTNAME" /etc/hosts || echo "127.0.1.1 ${NODE_HOSTNAME}" >> /etc/hosts

echo "=== [3/5] Provisionando grupo ${GROUP_NAME} e usuarios nominais ==="
getent group "$GROUP_NAME" >/dev/null || groupadd "$GROUP_NAME"
for LOGIN in "${ALUNOS[@]}"; do
  if ! id "$LOGIN" &>/dev/null; then
    adduser --allow-bad-names --disabled-password --gecos "" "$LOGIN"
    echo "${LOGIN}:Fiap@2026" | chpasswd
  fi
  usermod -aG "$GROUP_NAME" "$LOGIN"
done
usermod -aG sudo OtavioFerrao_RM556452

echo "=== [4/5] Verificando disco secundario (${DISK_DEV}) e montagem fstab ==="
mkdir -p "$MOUNT_POINT"
if [[ -b "$DISK_DEV" ]]; then
  if [[ ! -b "$PART_DEV" ]]; then
    parted -s "$DISK_DEV" mklabel gpt
    parted -s "$DISK_DEV" mkpart primary ext4 0% 100%
    partprobe "$DISK_DEV" || true
    sleep 2
    mkfs.ext4 -F "$PART_DEV"
  fi
  UUID_VAL=$(blkid -s UUID -o value "$PART_DEV")
  if ! grep -q "$UUID_VAL" /etc/fstab; then
    echo "UUID=${UUID_VAL} ${MOUNT_POINT} ext4 defaults,nofail 0 2" >> /etc/fstab
  fi
  mountpoint -q "$MOUNT_POINT" || mount -a
fi

mkdir -p "${MOUNT_POINT}/logs"
chown -R OtavioFerrao_RM556452:"$GROUP_NAME" /srv/citizentech
chmod -R 2770 /srv/citizentech
log_audit "Usuarios, grupo ${GROUP_NAME} e storage ${MOUNT_POINT} validados."

echo "=== [5/5] Configurando Hardening SSH e DNS Autoritativo BIND9 ==="
cat << 'SSHCONF' > /etc/ssh/sshd_config.d/99-citizentech.conf
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication yes
AllowGroups citizenops
SSHCONF
sshd -t && systemctl enable --now ssh && systemctl restart ssh
log_audit "Hardening SSH aplicado (PermitRootLogin=no, AllowGroups=citizenops)."

cat << 'BINDLOCAL' > /etc/bind/named.conf.local
zone "citizentechzeladoria.test" {
    type master;
    file "/etc/bind/db.citizentechzeladoria.test";
};

zone "56.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/db.192.168.56";
};
BINDLOCAL

cat << 'BINDZONE' > /etc/bind/db.citizentechzeladoria.test
$TTL 604800
@   IN  SOA ns1.citizentechzeladoria.test. admin.citizentechzeladoria.test. (
            2026111701 ; Serial
            604800     ; Refresh
            86400      ; Retry
            2419200    ; Expire
            604800 )   ; Negative Cache TTL
;
@       IN  NS  ns1.citizentechzeladoria.test.
ns1     IN  A   192.168.56.10
node    IN  A   192.168.56.10
client  IN  A   192.168.56.20
api     IN  CNAME node.citizentechzeladoria.test.
BINDZONE

cat << 'BINDREV' > /etc/bind/db.192.168.56
$TTL 604800
@   IN  SOA ns1.citizentechzeladoria.test. admin.citizentechzeladoria.test. (
            2026111701 ; Serial
            604800     ; Refresh
            86400      ; Retry
            2419200    ; Expire
            604800 )   ; Negative Cache TTL
;
@       IN  NS  ns1.citizentechzeladoria.test.
10  IN  PTR node.citizentechzeladoria.test.
20  IN  PTR client.citizentechzeladoria.test.
BINDREV

named-checkconf
named-checkzone "$DOMAIN" /etc/bind/db.citizentechzeladoria.test
named-checkzone 56.168.192.in-addr.arpa /etc/bind/db.192.168.56
systemctl enable --now named
systemctl restart named
log_audit "DNS BIND9 validado e ativo para dominio ${DOMAIN} (IP ${NODE_IP})."
echo ">>> Provisionamento de Infraestrutura concluido com sucesso!"
