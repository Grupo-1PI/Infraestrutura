#!/bin/bash

# Configurações de Erro:
# -e: Para o script imediatamente em caso de erro
# -u: Para o script se encontrar uma variável não definida
# -o pipefail: Garante que erros em comandos com pipe (|) sejam detectados
set -euo pipefail

# Função de log simples
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Aviso caso o script pare inesperadamente
trap 'log "ERRO: O script foi interrompido devido a um erro no último comando.";' ERR

log "Iniciando instalação do Docker e Docker compose..."

log "Passo 1: Atualizando repositórios do sistema..."
sudo apt-get update -y

log "Passo 2: Instalando dependências básicas..."
sudo apt-get install -y ca-certificates curl gnupg lsb-release

log "Passo 3: Configurando chave GPG do Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
sudo chmod a+r /etc/apt/keyrings/docker.gpg

log "Passo 4: Adicionando repositório oficial ao APT..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

log "Passo 5: Instalando Docker Engine e Plugins..."
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

log "Passo 6: Adicionando usuário ubuntu ao grupo docker..."
sudo usermod -aG docker ubuntu

log "Sucesso! Instalação concluída."
docker --version