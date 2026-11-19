# CitizenTech Zeladoria Urbana — Infraestrutura Linux Automatizada (GS FIAP 2026)

![ODS 11](https://img.shields.io/badge/ODS%2011-Cidades%20e%20Comunidades%20Sustent%C3%A1veis-orange)
![OS](https://img.shields.io/badge/SO-Ubuntu%2026.04%20LTS-E95420?logo=ubuntu&logoColor=white)
![Bash](https://img.shields.io/badge/Automação-Shell%20Script%20(Bash)-4EAA25?logo=gnu-bash&logoColor=white)
![Systemd](https://img.shields.io/badge/Orquestração-systemd-000000?logo=linux&logoColor=white)

Repositório oficial do projeto **CitizenTech Zeladoria Urbana**, desenvolvido pelo **Grupo MAJE** para a Global Solution de **Operating Systems (FIAP — 2026)**.

A solução implementa uma arquitetura cliente-servidor em ambiente Linux voltada à triagem, processamento automatizado e monitoramento de ocorrências de zeladoria urbana na cidade de São Paulo, alinhada diretamente ao **Objetivo de Desenvolvimento Sustentável 11 (ODS 11 — Cidades e Comunidades Sustentáveis)** da ONU.

---

## 👥 Integrantes — Grupo MAJE

| Papel na Arquitetura | Nome Completo | RM | Conta Nominal Linux | Turma |
| :--- | :--- | :---: | :--- | :--- |
| **Líder / Administrador (`sudo`)** | Otávio Ferrão | `556452` | `OtavioFerrao_RM556452` | 3ESPH |
| **Executor do Agente / Serviços (sem `sudo`)** | Gustavo Yuji | `555034` | `GustavoYuji_RM555034` | 3ESPH |
| **Operador de Zeladoria (`citizenops`)** | Kaio Drago | `556095` | `KaioDrago_RM556095` | 3ESPH |
| **Operador de Zeladoria (`citizenops`)** | Gustavo Viega | `555885` | `GustavoViega_RM555885` | 3ESPH |
| **Operador de Zeladoria (`citizenops`)** | Vitor Rivas | `556404` | `VitorRivas_RM556404` | 3ESPH |

---

## 🏗️ Arquitetura e Topologia de Rede

O ambiente é composto por duas máquinas virtuais **Ubuntu 26.04 LTS** operando em rede isolada Host-Only (`192.168.56.0/24`) com resolução de nomes autoritativa sob o domínio interno `citizentechzeladoria.test`:

```text
+--------------------------------------------------+          +--------------------------------------------------+
|             CT-CLIENT (Estação Remota)           |          |            CT-NODE (Servidor Principal)          |
|  Hostname: ct-client-rm556452                    |          |  Hostname: ct-node-rm556452                      |
|  IP Host-Only: 192.168.56.20/24 (enp0s8)         |          |  IP Host-Only: 192.168.56.10/24 (enp0s8)         |
|  FQDN: client.citizentechzeladoria.test          |          |  FQDN: node.citizentechzeladoria.test            |
|                                                  |          |  CNAME: api.citizentechzeladoria.test            |
|  - Clientes DNS (dig) e SSH (Chave Ed25519)      | =======> |  - DNS Autoritativo BIND9 (named)                |
|  - Submissão remota de ocorrências de zeladoria  |  SSH /   |  - OpenSSH Server endurecido (99-citizentech)    |
|                                                  |   DNS    |  - Storage dedicado /dev/sdb1 (/srv/citizentech) |
|                                                  |          |  - Agente de Zeladoria (citizentech-agent)       |
|                                                  |          |  - Monitor Resiliente (citizentech-monitor)      |
+--------------------------------------------------+          +--------------------------------------------------+
```

### Componentes Principais
* **Armazenamento Dedicado e Permissões SGID:** Partição GPT `/dev/sdb1` formatada em `ext4`, montada de forma persistente via `UUID` em `/srv/citizentech/storage` (`defaults,nofail 0 2`), com diretórios colaborativos (`inbox/`, `processed/`, `logs/`, `quarantine/`) protegidos pelo bit **SGID (`2770` / `2750`)** para o grupo `citizenops`.
* **DNS Autoritativo (`BIND9`):** Resolução direta e reversa para a zona `citizentechzeladoria.test` e `56.168.192.in-addr.arpa`.
* **Hardening SSH (`OpenSSH`):** Bloqueio de login direto como `root` (`PermitRootLogin no`), autenticação via chaves criptográficas Ed25519 (`PubkeyAuthentication yes`) e acesso restrito exclusivamente aos membros do grupo `citizenops` (`AllowGroups citizenops`).
* **Orquestração e Tolerância a Falhas (`systemd`):** Execução desprivilegiada sob o usuário `GustavoYuji_RM555034` com reinício automático incondicional (`Restart=always`, `RestartSec=3`, `StartLimitIntervalSec=0`).

---

## 📂 Estrutura do Repositório

```text
citizentech-zeladoria-linux-gs2026/
├── README.md                                      # Documentação técnica do projeto
├── configs/
│   ├── bind/
│   │   ├── named.conf.local                       # Definição das zonas direta e reversa BIND9
│   │   ├── db.citizentechzeladoria.test           # Registros SOA, NS, A e CNAME do domínio
│   │   └── db.192.168.56                          # Registros PTR (DNS reverso)
│   ├── ssh/
│   │   └── 99-citizentech.conf                    # Política de hardening do OpenSSH Server
│   └── systemd/
│       ├── citizentech-agent.service              # Unit file do agente de zeladoria urbana
│       └── citizentech-monitor.service            # Unit file do monitor resiliente de recursos
|
├── Relatorio.pdf
├── evidencias/
│   └── E01_01 ... E11_01 (.png)                   # 16 capturas validadas com carimbo ISO-8601
└── scripts/
    ├── 01_provision_infra.sh                      # Provisionamento idempotente de infraestrutura
    ├── 02_provision_app.sh                        # Provisionamento da aplicação e orquestração
    ├── 03_monitor_recursos.sh                     # Monitoramento de CPU, RAM e Disco + alertas
    └── 04_audit_validate.sh                       # Auditoria técnica e validação ponta a ponta
```

---

## ⚙️ Guia de Execução Automatizada (Scripts Bash)

Todos os scripts foram projetados com **idempotência** (`set -euo pipefail`) e geram trilha de auditoria em `/srv/citizentech/storage/logs/provision_audit.log` e no `syslog` (`logger`).

### 1. Provisionamento de Infraestrutura (`scripts/01_provision_infra.sh`)
Instala dependências (`openssh-server`, `bind9`, `dnsutils`, `parted`), configura o hostname, cria o grupo `citizenops` e as 5 contas nominais, particiona/monta `/dev/sdb1` via `UUID` no `/etc/fstab`, aplica o hardening SSH e ativa o DNS BIND9.
```bash
sudo ./scripts/01_provision_infra.sh
```

### 2. Provisionamento da Aplicação (`scripts/02_provision_app.sh`)
Cria a árvore operacional em `/srv/citizentech/storage/{inbox,processed,logs,quarantine}` com permissões SGID, instala o agente `/usr/local/bin/citizentech-agent.sh` e habilita o serviço `citizentech-agent.service` no `systemd` sob o usuário `GustavoYuji_RM555034`.
```bash
sudo ./scripts/02_provision_app.sh
```

### 3. Monitoramento de Recursos e Tolerância a Falhas (`scripts/03_monitor_recursos.sh`)
Implanta o daemon `/usr/local/bin/citizentech-monitor.sh` com limiares configuráveis em `/etc/citizentech-monitor.conf` (`CPU >= 80%`, `MEM >= 80%`, `DISCO >= 85%`), registrando métricas contínuas e alertas críticos (`[ALERTA_CPU]`, `[ALERTA_MEM]`, `[ALERTA_DISCO]`) em `/srv/citizentech/storage/logs/monitor_alerts.log` e no `journalctl`.
```bash
sudo ./scripts/03_monitor_recursos.sh
```

### 4. Auditoria e Validação Ponta a Ponta (`scripts/04_audit_validate.sh`)
Verifica o estado de todos os serviços (`agent`, `monitor`, `named`, `ssh`), montagem do disco, resolução DNS direta/reversa e exibe os logs recentes de auditoria e métricas.
```bash
./scripts/04_audit_validate.sh
```

---

## 🛡️ Testes de Resiliência e Operação Ponta a Ponta

### Simulação de Alertas de Infraestrutura
Para validar o disparo de alertas de CPU, Memória RAM e Disco sem comprometer a estabilidade da VM, os limiares em `/etc/citizentech-monitor.conf` podem ser ajustados temporariamente:
```bash
sudo sed -i 's/80/0/g; s/85/0/g' /etc/citizentech-monitor.conf
sleep 12
sudo sed -i 's/=0$/=80/g; s/DISK_THRESHOLD=80/DISK_THRESHOLD=85/g' /etc/citizentech-monitor.conf
tail -n 10 /srv/citizentech/storage/logs/monitor_alerts.log
```

### Teste de Tolerância a Falhas (`SIGKILL`)
O serviço `citizentech-monitor.service` está configurado com `Restart=always` e `RestartSec=3`. Ao encerrar abruptamente o processo com `kill -9`, o `systemd` restaura o monitoramento automaticamente em 3 segundos com um novo PID:
```bash
OLD_PID=$(pgrep -f "/usr/local/bin/citizentech-monitor.sh")
sudo kill -9 "$OLD_PID" && sleep 4
systemctl status citizentech-monitor.service --no-pager
```

---

## 📸 Inventário de Evidências Técnicas (`evidencias/`)

Todas as capturas contêm carimbo temporal **ISO-8601**, identificação do host e usuário nominal executor:

| ID | Arquivo de Evidência | Máquina | Descrição Técnica Validada |
| :---: | :--- | :---: | :--- |
| **E01.1** | `E01_01_sistema_node.png` | `CT-NODE` | Identificação do SO Ubuntu 26.04 LTS e hostname `ct-node-rm556452` |
| **E01.2** | `E01_02_sistema_client.png` | `CT-CLIENT` | Identificação do SO Ubuntu 26.04 LTS e hostname `ct-client-rm556452` |
| **E02.1** | `E02_01_usuarios_node.png` | `CT-NODE` | Contas nominais dos 5 integrantes, grupo `citizenops` e privilégios `sudo` |
| **E02.2** | `E02_02_usuarios_client.png` | `CT-CLIENT` | Contas nominais dos 5 integrantes e grupo `citizenops` no cliente |
| **E03.1** | `E03_01_permissoes_node.png` | `CT-NODE` | Árvore `/srv/citizentech/storage` com SGID (`2770`/`2750`) e escrita colaborativa |
| **E04.1** | `E04_01_disco_fstab_node.png` | `CT-NODE` | Particionamento GPT `/dev/sdb1`, persistência via `UUID` no `/etc/fstab` e `df -h` |
| **E05.1** | `E05_01_servico_systemd_node.png` | `CT-NODE` | Serviço `citizentech-agent.service` ativo sob `GustavoYuji_RM555034` |
| **E06.1** | `E06_01_logs_operacao_node.png` | `CT-NODE` | Triagem automática (`inbox` → `processed`) e logs em `agent.log` |
| **E07.1** | `E07_01_rede_node.png` | `CT-NODE` | Configuração de rede NAT (`enp0s3`) e Host-Only estático `192.168.56.10/24` |
| **E07.2** | `E07_02_rede_client.png` | `CT-CLIENT` | Configuração Host-Only `192.168.56.20/24` e conectividade ICMP (`ping`) com o nó |
| **E08.1** | `E08_01_ssh_config_node.png` | `CT-NODE` | Parâmetros ativos de hardening SSH (`sshd -T`) |
| **E08.2** | `E08_02_ssh_client.png` | `CT-CLIENT` | Autenticação SSH via chave Ed25519 sem senha e checagem remota de serviço |
| **E09.1** | `E09_01_dns_bind_node.png` | `CT-NODE` | Serviço BIND9 (`named`) ativo e resolução direta/reversa local |
| **E09.2** | `E09_02_dns_client.png` | `CT-CLIENT` | Resolução DNS remota (`A`, `CNAME` e `PTR`) consultando `192.168.56.10` |
| **E10.1** | `E10_01_monitor_alertas_node.png` | `CT-NODE` | Coleta de métricas e disparo de `[ALERTA_CPU]`, `[ALERTA_MEM]` e `[ALERTA_DISCO]` |
| **E11.1** | `E11_01_tolerancia_falhas_node.png` | `CT-NODE` | Recuperação automática do monitor após `SIGKILL` e auditoria `04_audit_validate.sh` |

---

## 🎥 Vídeo de Demonstração

* **Link do Vídeo (YouTube / Drive — até 7 min):** [https://www.youtube.com/watch?v=l1B1ddiByRU]
