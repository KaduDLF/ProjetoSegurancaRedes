## Tema
Firewall Linux, Netfilter e Iptables utilizando Docker e Docker Compose.

## Objetivo
Simular uma rede segmentada com cliente, firewall, DMZ, servidor web e banco de dados.

## Rede do laboratório

| Serviço | Rede | IP |
| --- | --- | --- |
| client | Rede cliente | 172.20.0.10 |
| firewall | Rede cliente | 172.20.0.2 |
| firewall | DMZ | 172.21.0.2 |
| web | DMZ | 172.21.0.10 |
| firewall | Rede banco | 172.22.0.2 |
| db | Rede banco | 172.22.0.10 |

O cliente usa Alpine com curl, nmap e iproute2. O firewall usa Alpine com iptables e iproute2. O servidor web usa Nginx com uma página simples.

As três redes usam bridges separadas. Não usamos `internal: true`, pois o isolamento dessa opção pode bloquear os pacotes destinados à outra sub-rede antes de chegarem ao container firewall. As bridges permitem saída pelo gateway do Docker; as regras desta etapa controlam o tráfego entre cliente e DMZ. O cliente tem uma rota para a DMZ pelo firewall, e o servidor web tem a rota de volta pelo mesmo firewall. Não publicamos a porta do servidor no computador, pois o teste desta etapa deve ser feito pelo cliente.

O firewall permite HTTP do cliente para o servidor web e as respostas das conexões autorizadas. Os outros encaminhamentos são bloqueados. As políticas INPUT e OUTPUT do próprio firewall continuam no padrão; nesta etapa estamos filtrando o tráfego que passa entre as redes.

## Como iniciar

Com o Docker Desktop aberto e configurado para containers Linux, execute na pasta do projeto:

```sh
git pull origin main
docker compose config
docker compose up -d --build
docker compose ps
```

O Compose espera o firewall aplicar as regras e o Nginx responder antes de iniciar o cliente. Não usamos nomes fixos de containers, então os containers de teste anteriores não entram em conflito com os serviços do Compose.

A permissão NET_ADMIN permite configurar as rotas e o iptables. O encaminhamento IPv4 é habilitado pelo sysctl do Compose. O Dockerfile do firewall corrige as quebras de linha do script para funcionar também quando o projeto é baixado no Windows.

Se o Docker informar que uma sub-rede já está em uso, confira as redes existentes com `docker network ls`. Ao mudar os endereços do laboratório, atualize também as rotas e as regras do firewall.

## Atualização das redes

Após uma alteração nas opções das redes, recrie o laboratório:

```sh
git pull origin main
docker compose down
docker compose up -d --build
```

O comando down remove os containers e as redes deste Compose, que serão recriados pelo up.

## Testes

### Acesso permitido

```sh
docker compose exec client curl --noproxy "*" --max-time 5 http://172.21.0.10
```

Deve aparecer o HTML da página do projeto.

### Portas permitidas e bloqueadas

```sh
docker compose exec client nmap -sT -Pn -n -p 80,81 --reason --max-retries 1 --host-timeout 20s 172.21.0.10
```

A porta 80 deve aparecer como `open` e a 81 como `filtered`. Usamos -Pn porque o firewall não libera as sondagens de descoberta do nmap. A porta 81 não tem serviço: sem o bloqueio ela responderia como fechada; com DROP, a tentativa fica sem resposta.

### Comprovar a passagem pelo firewall

```sh
docker compose exec firewall iptables -L FORWARD -n -v
docker compose exec firewall cat /proc/sys/net/ipv4/ip_forward
docker compose exec client ip route
docker compose exec web ip route
```

Depois dos testes, os contadores das regras de HTTP, de respostas e de DROP devem aumentar. O encaminhamento IPv4 deve mostrar 1. Guarde as saídas para o relatório.

Para consultar erros:

```sh
docker compose logs firewall web client
```

Para encerrar o laboratório:

```sh
docker compose down
```

## Banco de dados

Usamos PostgreSQL 16 em uma terceira rede. Somente o servidor web pode iniciar conexões TCP para o banco na porta 5432. O cliente tem uma rota até essa rede para comprovar o bloqueio pelo firewall.

O usuário aluno e a senha padrão senha_laboratorio são dados de demonstração. Você pode definir DB_PASSWORD em um arquivo .env antes da primeira inicialização. A mesma variável é usada pelo banco e pelo cliente PostgreSQL instalado no web. Alterar essa variável depois não muda a senha de um banco que já foi inicializado no volume.

O volume dados_banco mantém os dados ao executar docker compose down. Nenhuma porta do banco é publicada no computador.

O Nginx continua servindo uma página estática. O teste SQL é executado pelo terminal do container web para demonstrar o acesso autorizado; a página não consulta o banco.

### Acesso permitido do web ao banco

```sh
docker compose exec web psql -c "SELECT current_database(), current_user, inet_server_addr();"
```

Esperado: seguranca, aluno e 172.22.0.10. Esse comando comprova conexão e autenticação, além da porta aberta.

### Cliente bloqueado no banco

```sh
docker compose exec client nmap -sT -Pn -n -p 5432 --reason --max-retries 1 --host-timeout 20s 172.22.0.10
```

Esperado: 5432 filtered. Depois confira o contador DROP do firewall.

### Novas conexões da DMZ para o cliente bloqueadas

```sh
docker compose exec web nmap -sT -Pn -n -p 80 --reason --max-retries 1 --host-timeout 20s 172.20.0.10
docker compose exec firewall iptables -L FORWARD -n -v
```

Esperado: 80 filtered. O cliente não tem um servidor nessa porta; sem DROP ela retornaria closed. As respostas ao HTTP autorizado continuam permitidas por ESTABLISHED,RELATED.

### Evidências e relatório

O arquivo docs/relatorio.md reúne a arquitetura, as regras e os resultados já confirmados. Os testes novos estão marcados como pendentes até sua execução. Salve os prints em docs/evidencias/ e atualize os resultados após conferir as saídas.

Referência do banco: [imagem oficial PostgreSQL](https://github.com/docker-library/docs/blob/master/postgres/README.md).

Referências: [serviços do Compose](https://docs.docker.com/reference/compose-file/services/) e [redes do Compose](https://docs.docker.com/reference/compose-file/networks/).
