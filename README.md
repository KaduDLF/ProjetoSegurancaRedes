## Tema
Firewall Linux, Netfilter e Iptables utilizando Docker e Docker Compose.

## Objetivo
Simular uma rede segmentada com cliente, firewall, DMZ, servidor web e, em uma próxima etapa, banco de dados.

## Rede do laboratório

| Serviço | Rede | IP |
| --- | --- | --- |
| client | Rede cliente | 172.20.0.10 |
| firewall | Rede cliente | 172.20.0.2 |
| firewall | DMZ | 172.21.0.2 |
| web | DMZ | 172.21.0.10 |

O cliente usa Alpine com curl, nmap e iproute2. O firewall usa Alpine com iptables e iproute2. O servidor web usa Nginx com uma página simples.

As duas redes são internas ao laboratório. O cliente tem uma rota para a DMZ pelo firewall, e o servidor web tem a rota de volta pelo mesmo firewall. Não publicamos a porta do servidor no computador, pois o teste desta etapa deve ser feito pelo cliente.

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

O banco de dados e suas regras serão adicionados na próxima etapa.

Referências: [serviços do Compose](https://docs.docker.com/reference/compose-file/services/) e [redes do Compose](https://docs.docker.com/reference/compose-file/networks/).
