# Stack local

O Compose sobe os mesmos containers publicados no Docker Hub usados pelo Terraform, junto com MySQL 8 e RabbitMQ. As portas locais são frontend `http://localhost`, backend `http://localhost:8080/api` e painel RabbitMQ `http://localhost:15672` (usuário e senha `guest`).

## Preparação (PowerShell)

1. Instale e inicie Docker Desktop.
2. Na raiz deste repositório, crie seu arquivo de configuração:

   ```powershell
   Copy-Item .env.example .env
   notepad .env
   ```

   Troque as senhas e `JWT_SECRET` por valores só para desenvolvimento. `JWT_SECRET` deve ter pelo menos 32 bytes. As credenciais Twilio podem ficar vazias se não for testar notificações.
3. Baixe o mesmo SQL de inicialização que o Terraform usa e coloque em `init`:

   ```powershell
   New-Item -ItemType Directory -Force init | Out-Null
   $sqlUrl = (Get-Content .env | Where-Object { $_ -match '^DATABASE_INIT_SQL_URL=' } | Select-Object -First 1) -replace '^DATABASE_INIT_SQL_URL=', ''
   Invoke-WebRequest -Uri $sqlUrl -OutFile init\script_completo.sql
   ```

   Confira o SQL antes de importá-lo. A URL corresponde ao valor versionado neste checkout; ajuste `.env` se a inicialização de produção mudar.
4. Baixe e inicie os serviços:

   ```powershell
   docker compose pull
   docker compose up -d
   docker compose ps
   ```

   Na primeira execução, o MySQL importa automaticamente `init/script_completo.sql`. Se o SQL tiver outro nome, renomeie para esse nome.

## Uso

Abra `http://localhost:8088`. O proxy local imita o roteamento do ALB: `/api/` vai ao backend e os outros caminhos vão ao frontend. A porta 80 fica disponível para outros serviços locais.

Veja logs com `docker compose logs -f backend frontend db`. Para parar mantendo os dados, execute `docker compose down`. Para apagar também o banco local e recomeçar do zero, execute `docker compose down -v`.

O Compose configura `utf8mb4` no MySQL/JDBC e UTF-8 na JVM. Para investigar caracteres corrompidos, compare o texto enviado, a resposta da API e o valor salvo no MySQL. Se já chegar corrompido à API, o problema está antes do banco; se a resposta estiver correta mas a tela não, investigue a decodificação/renderização do frontend.
