## Tema
Firewall Linux, Netfilter e Iptables utilizando Docker e Docker Compose.

## Objetivo
Simular uma arquitetura de rede segmentada composta por:

- Rede Cliente
- Firewall
- DMZ
- Servidor Web
- Banco de Dados

O firewall será responsável por controlar o tráfego entre as redes utilizando regras de iptables.

## Imagens Docker

O cliente usa Alpine com curl, nmap e iproute2 para testar acessos e consultar a rede. O firewall também usa Alpine, com iptables e iproute2. O servidor web usa Nginx e entrega uma página simples para os testes.

Para construir as imagens, execute na pasta do projeto:

```sh
docker build -t seguranca-client ./client
docker build -t seguranca-firewall ./firewall
docker build -t seguranca-web ./web
```

O cliente e o firewall ficam ligados aguardando os testes pelo terminal. O entrypoint do firewall habilita o encaminhamento IPv4 caso ele ainda esteja desativado.

Para iniciar o firewall no laboratório:

```sh
docker run -d --name firewall --cap-add=NET_ADMIN --sysctl net.ipv4.ip_forward=1 seguranca-firewall
```

A opção NET_ADMIN permite usar iptables e alterar a rede do container. O sysctl define o encaminhamento na criação do container, pois o Docker pode deixar /proc/sys somente para leitura. No Compose, essas opções correspondem a `cap_add: [NET_ADMIN]` e `sysctls: {net.ipv4.ip_forward: 1}`.

Para conferir o firewall:

```sh
docker exec firewall cat /proc/sys/net/ipv4/ip_forward
docker exec firewall iptables -L -n -v
```

O primeiro comando deve mostrar 1. As regras de bloqueio, as rotas, as redes do Compose e o banco de dados ainda serão configurados nas próximas etapas. Por enquanto, o encaminhamento habilitado não significa que o tráfego já está filtrado.

Para testar apenas a página do servidor web no próprio computador:

```sh
docker run -d --name web-teste -p 127.0.0.1:8080:80 seguranca-web
curl http://localhost:8080
```

Esse teste confirma a resposta do Nginx; o teste de acesso pela DMZ depende da configuração das redes e do firewall.

Referência: [configuração de serviços no Docker Compose](https://docs.docker.com/reference/compose-file/services/).
