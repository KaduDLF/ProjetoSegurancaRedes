# Relatório — Firewall Linux com Docker

## Identificação

Integrantes: preencher.
Disciplina e professor: preencher.

## Objetivo

Montar um laboratório com três redes e usar iptables para controlar o tráfego encaminhado entre cliente, servidor web e banco de dados.

## Arquitetura

| Rede | Sub-rede | Serviços |
| --- | --- | --- |
| Cliente | 172.20.0.0/24 | client .10 e firewall .2 |
| DMZ | 172.21.0.0/24 | web .10 e firewall .2 |
| Banco | 172.22.0.0/24 | db .10 e firewall .2 |

O firewall está conectado às três redes. Os outros containers estão conectados somente à sua própria rede. As rotas para as demais sub-redes apontam para o endereço .2 do firewall. As respostas também usam esse caminho; não foi necessário adicionar NAT no container firewall.

São usadas bridges comuns. A configuração internal: true foi removida após o HTTP ficar sem resposta e os contadores FORWARD permanecerem em zero. Depois da recriação das redes, os testes de HTTP e de bloqueio funcionaram. As redes têm saída pelo gateway do Docker; a política demonstrada aqui controla o encaminhamento entre as três sub-redes.

## Regras do firewall

A política da cadeia FORWARD é DROP. Primeiro são aceitos pacotes ESTABLISHED,RELATED, para permitir respostas de conexões autorizadas. Depois são permitidas novas conexões:

| Origem | Destino | Porta TCP | Ação |
| --- | --- | --- | --- |
| Cliente 172.20.0.10 | Web 172.21.0.10 | 80 | ACCEPT |
| Web 172.21.0.10 | Banco 172.22.0.10 | 5432 | ACCEPT |
| Demais encaminhamentos | Qualquer destino | Qualquer | DROP |

A última regra DROP facilita a consulta dos contadores de pacotes bloqueados. INPUT e OUTPUT do firewall permanecem no padrão. O encaminhamento IPv4 é habilitado por net.ipv4.ip_forward=1.

## Resultados observados

### Etapa HTTP — confirmada em 11/10/2026

O curl executado no cliente retornou o HTML do servidor. O nmap mostrou 80/tcp open e 81/tcp filtered. No print fornecido, o firewall registrou:

- 14 pacotes e 1551 bytes na regra ESTABLISHED,RELATED.
- 2 pacotes e 120 bytes na regra HTTP.
- 2 pacotes e 120 bytes na regra DROP.

Esses contadores comprovaram que as tentativas passaram pelo firewall. Os valores podem mudar em novos testes e são zerados quando as regras são reaplicadas.

Print: adicionar em docs/evidencias/.

### Etapa banco — pendente de execução

| Teste | Resultado esperado | Resultado obtido |
| --- | --- | --- |
| Consulta SQL pelo container web | seguranca, aluno, 172.22.0.10 | Pendente |
| Cliente para banco TCP 5432 | filtered e aumento em DROP | Pendente |
| Web para cliente TCP 80 | filtered e aumento em DROP | Pendente |
| Repetição cliente para web TCP 80 | HTML e porta open | Pendente |

Os comandos estão no README. Após executar, inserir saídas, prints e os contadores das regras de PostgreSQL, respostas e bloqueio.

## Dificuldades e ajustes

No Windows, o script inicial apresentou exec /entrypoint.sh: no such file or directory. A construção foi ajustada para converter as quebras de linha para o formato Linux.

As redes com internal: true impediram o teste de roteamento. A troca para bridges comuns manteve as sub-redes separadas e permitiu demonstrar as regras do container firewall.

## Limites do laboratório

A página do Nginx é estática. A consulta SQL é um teste manual no container web, não uma integração da página com o banco. O banco usa credenciais de demonstração e um volume persistente. Os containers web e db recebem NET_ADMIN para configurar suas rotas.

O bloqueio entre redes não demonstra isolamento de saída à internet nem proteção contra um administrador que altere as rotas ou regras. O escopo é demonstrar a filtragem de encaminhamento no laboratório.

## Conclusão parcial

O acesso HTTP autorizado e o bloqueio da porta 81 foram confirmados. A configuração do banco e os novos testes foram preparados, mas a conclusão final depende das evidências de execução.

## Referências

- [Docker Compose — serviços](https://docs.docker.com/reference/compose-file/services/)
- [Imagem oficial PostgreSQL](https://github.com/docker-library/docs/blob/master/postgres/README.md)
- [PostgreSQL — pg_isready](https://www.postgresql.org/docs/16/app-pg-isready.html)
