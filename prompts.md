# Registro de Uso de IA Generativa — CitizenTech Zeladoria Urbana (GS 2026)

* **Grupo:** MAJE (`3ESPH` — Engenharia de Software / FIAP)
* **Aluno Líder / Administrador:** Otávio Santos de Lima Ferrão (`RM556452`)
* **Aluno Executor de Serviços:** Gustavo Yuji (`RM555034`)
* **Ferramenta de IA Generativa:** Google Gemini
* **Política de Segurança:** Nenhuma senha, chave privada, token ou credencial real foi inserida nos prompts ou armazenada neste documento.

---

## Prompts Utilizados, Finalidade e Verificação Empírica

| # | Prompt Relevante (Resumo) | Finalidade Técnica | Como a Resposta foi Verificada na Prática |
| :-: | :--- | :--- | :--- |
| **01** | *"Estruture uma arquitetura Linux cliente-servidor com duas VMs Ubuntu (`CT-NODE` e `CT-CLIENT`), contas nominais `NomeAluno_RM` no grupo `citizenops` e armazenamento persistente em `/dev/sdb1` via UUID no `/etc/fstab`."* | Definir a topologia de rede interna (`192.168.56.0/24`), a segregação de privilégios (`sudo` apenas para o líder e conta sem `root` para os serviços) e as permissões colaborativas SGID (`2770`). | Executado e validado nas duas VMs por meio dos comandos `hostnamectl`, `id`, `getent group citizenops`, `sudo -l -U OtavioFerrao_RM556452`, `lsblk -f`, `blkid`, `findmnt` e `df -hT`. |
| **02** | *"Gere arquivos de configuração para endurecimento do OpenSSH (`99-citizentech.conf`) e servidor DNS autoritativo BIND9 para a zona `citizentechzeladoria.test` (registros `ns1`, `node`, `dados`, `monitor`, `api` e zona reversa)."* | Bloquear login remoto como `root`, restringir acesso SSH ao grupo `citizenops` via chave Ed25519 e configurar resolução de nomes interna direta e reversa. | Validado com `sshd -T`, autenticação SSH sem senha a partir do `CT-CLIENT` (`whoami`), `named-checkconf`, `named-checkzone` e consultas remotas `dig @192.168.56.10` no cliente. |
| **03** | *"Crie scripts Bash idempotentes (`set -euo pipefail`) para provisionamento da infraestrutura, execução do agente de zeladoria urbana com gravação de `status.txt`, monitoramento de CPU/RAM/Disco com alertas e unidade `systemd` tolerante a falhas."* | Automatizar toda a implantação, registrar os RMs da equipe nos logs/estado e assegurar auto-recuperação (`Restart=always`) em caso de queda do processo. | Validado rodando os scripts `01` a `04`, verificando `systemctl status`, `ps -ef`, `journalctl -u citizentech-agent`, simulando alertas de CPU/RAM/Disco e encerrando o processo com `kill -9` para comprovar o reinício automático. |
| **04** | *"Diagnostique por que o `ssh.service` apareceu como `inactive` após reboot no Ubuntu 26.04 LTS e por que o campo `MEM=%` ficou vazio no monitoramento."* | Identificar o comportamento de *socket activation* (`ssh.socket`) e a diferença de localização do comando `free` em português (`Mem.:` vs `Mem:`). | Validado ativando `systemctl enable --now ssh.service` e ajustando o filtro `awk` para `/^Mem/`, confirmando status `active` após reboot e coleta precisa do percentual de memória (`MEM=29%`). |
