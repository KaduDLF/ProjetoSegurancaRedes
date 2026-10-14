# Relatório Técnico — Segmentação de Rede e Firewall Linux

Aluno: Carlos Eduardo De Oliveira Silva.
Disciplina: Segurança da Informação.
Professor: Roitier.

## 1. Definição do Case

Este trabalho considera a empresa fictícia Integra Serviços, uma pequena prestadora de serviços que precisa disponibilizar um portal de atendimento para seus funcionários. O portal representa o acesso ao sistema, enquanto um banco de dados representa o armazenamento de informações de clientes e atendimentos.

Os funcionários precisam acessar o servidor web. O servidor responsável pelo sistema precisa consultar o banco, mas os computadores dos funcionários não devem acessar o banco diretamente. Também não há necessidade de o servidor web iniciar conexões para os computadores dos usuários.

O laboratório representa esses papéis com containers Docker: um cliente Alpine, um firewall Alpine com iptables, um servidor Nginx e um banco PostgreSQL 16. A página do Nginx é estática; o acesso ao banco é demonstrado por uma consulta SQL executada no terminal do container web. Não foi implementado um sistema de atendimento completo.

## 2. Diagnóstico: Cenário Atual vs. Proposta de Solução

### Cenário atual — problemas mapeados

No cenário hipotético inicial, computadores de usuários e servidores compartilham uma rede sem controle específico entre os serviços. Isso permite tentativas de acesso direto ao banco e facilita a movimentação de um equipamento comprometido para outros serviços.

Os principais problemas considerados são:

- Ausência de segmentação entre usuários, servidor web e banco.
- Falta de uma política que permita apenas as conexões necessárias ao negócio.
- Possibilidade de novas conexões do servidor web para os computadores dos usuários.
- Dificuldade de identificar quais acessos foram permitidos ou bloqueados.

Não foram medidas saturação, latência ou perda de pacotes no cenário inicial. O diagnóstico é uma hipótese de segurança para o estudo de caso, e não uma auditoria de uma empresa real.

### Proposta de solução

Foram criadas três redes. A rede cliente reúne os usuários; a DMZ contém o serviço web; e uma terceira rede contém o banco. A DMZ separa o serviço acessado pelos usuários dos dados e dos próprios computadores clientes. O banco permanece em uma rede própria para que seu acesso possa ser filtrado separadamente.

| Rede | Sub-rede | Equipamento e IP |
| --- | --- | --- |
| Cliente | 172.20.0.0/24 | client: 172.20.0.10; firewall: 172.20.0.2 |
| DMZ | 172.21.0.0/24 | web: 172.21.0.10; firewall: 172.21.0.2 |
| Banco | 172.22.0.0/24 | db: 172.22.0.10; firewall: 172.22.0.2 |

Somente o firewall participa das três redes. Os demais containers participam de uma rede cada. As rotas para as outras sub-redes apontam para o firewall, incluindo as rotas de resposta.

A política FORWARD é DROP: o tráfego encaminhado só é permitido quando corresponde a uma regra de autorização. O parâmetro net.ipv4.ip_forward=1 permite que o Linux atue como roteador.

Usamos bridges comuns, sem internal: true. Durante os testes, essa opção de isolamento impediu o encaminhamento antes de os pacotes chegarem às regras do container firewall. Após recriar as redes sem essa opção, o tráfego passou pelas regras e os testes funcionaram.

O laboratório não publica portas no computador. As bridges podem ter saída pelo gateway do Docker; a política demonstrada controla os acessos entre as três sub-redes, não toda a saída à internet.

## 3. Matriz de Regras de Segurança (Firewall)

As regras estão em [firewall/entrypoint.sh](../firewall/entrypoint.sh) e são reaplicadas na inicialização do container.

| Origem | Destino | Porta/Protocolo ou condição | Ação | Justificativa do negócio |
| --- | --- | --- | --- | --- |
| Participantes de conexões autorizadas | Participantes dessas conexões | ESTABLISHED,RELATED | ACCEPT | Permitir respostas e tráfego relacionado às conexões autorizadas |
| Cliente 172.20.0.10 | Web na DMZ 172.21.0.10 | TCP 80; NEW | ACCEPT | Funcionários precisam acessar o portal |
| Web na DMZ 172.21.0.10 | Banco 172.22.0.10 | TCP 5432; NEW | ACCEPT | O servidor do sistema precisa consultar o PostgreSQL |
| Cliente 172.20.0.10 | Banco 172.22.0.10 | TCP 5432; nova conexão | DROP | Usuários devem acessar os dados pelo sistema, sem conexão direta ao banco |
| Web na DMZ 172.21.0.10 | Cliente 172.20.0.10 | Novas conexões, incluindo TCP 80 | DROP | O serviço web não precisa iniciar conexões para computadores dos funcionários |
| Cliente 172.20.0.10 | Web na DMZ 172.21.0.10 | TCP 81; nova conexão | DROP | A porta não faz parte do serviço autorizado |
| Qualquer origem encaminhada | Qualquer destino | Demais pacotes | DROP | Aplicar o princípio de permitir somente o necessário |

As linhas de bloqueio específicas descrevem os efeitos da regra final DROP e da política padrão; não existem regras DROP separadas para cada par de endereços. A regra final também contabiliza os bloqueios.

A autorização usa os IPs dos containers do laboratório, não toda a sub-rede. INPUT e OUTPUT do próprio firewall permanecem no padrão. Nesta implementação não há HTTPS nem autorização da porta 443: o serviço demonstrado é HTTP na porta 80.

## 4. Metodologia de Testes e Validação

### 4.1. Preparação e inicialização

O avaliador deve ter Git, Docker e Docker Compose disponíveis. No Windows, o Docker Desktop deve estar aberto e configurado para containers Linux.

Para obter o projeto:

```sh
git clone https://github.com/KaduDLF/ProjetoSegurancaRedes.git
cd ProjetoSegurancaRedes
```

Se já houver uma cópia local, atualizar com git pull origin main.

Na pasta do projeto:

```sh
docker compose config
docker compose up -d --build
docker compose ps
```

O firewall, o banco e o web devem ficar healthy, e o cliente deve ficar em execução. O Compose aguarda a aplicação das regras, a disponibilidade do banco e a resposta local do Nginx.

O banco usa o usuário aluno, o banco seguranca e uma senha de demonstração definida no Compose. DB_PASSWORD pode ser definida no arquivo .env antes da primeira inicialização. Os dados são persistidos no volume dados_banco.

### 4.2. Conferir as rotas e o encaminhamento

```sh
docker compose exec client ip route
docker compose exec web ip route
docker compose exec db ip route
docker compose exec firewall cat /proc/sys/net/ipv4/ip_forward
docker compose exec firewall iptables -L FORWARD -n -v
```

O cliente deve alcançar as redes 172.21.0.0/24 e 172.22.0.0/24 pelo gateway 172.20.0.2. O web deve alcançar cliente e banco pelo 172.21.0.2. O banco deve alcançar cliente e DMZ pelo 172.22.0.2. ip_forward deve retornar 1.

Para comparar os testes, registrar os contadores antes e depois de cada tentativa. Opcionalmente, zerar somente os contadores FORWARD antes de cada teste:

```sh
docker compose exec firewall iptables -Z FORWARD
```

Esse comando não remove nem altera as regras.

### 4.3. Testes positivos

**Cliente acessando o portal:**

```sh
docker compose exec client curl --noproxy "*" --max-time 5 http://172.21.0.10
```

Resultado esperado: HTML da página do projeto. O IP é usado porque cliente e web estão em redes distintas e o nome do web não é compartilhado pelo DNS dessas redes.

**Servidor web acessando o banco:**

```sh
docker compose exec web psql -c "SELECT current_database(), current_user, inet_server_addr();"
```

Resultado esperado: seguranca, aluno e 172.22.0.10. Esse teste verifica conexão e autenticação no banco a partir do container web.

### 4.4. Testes negativos

**Porta não autorizada no servidor web:**

```sh
docker compose exec client nmap -sT -Pn -n -p 80,81 --reason --max-retries 1 --host-timeout 20s 172.21.0.10
```

Esperado: 80/tcp open e 81/tcp filtered.

**Acesso direto do cliente ao banco:**

```sh
docker compose exec client nmap -sT -Pn -n -p 5432 --reason --max-retries 1 --host-timeout 20s 172.22.0.10
```

Esperado: 5432/tcp filtered.

**Nova conexão da DMZ para o cliente:**

```sh
docker compose exec web nmap -sT -Pn -n -p 80 --reason --max-retries 1 --host-timeout 20s 172.20.0.10
```

Esperado: 80/tcp filtered.

A opção -Pn evita depender das sondagens de descoberta, que não foram autorizadas. As portas 81 do web e 80 do cliente não possuem um serviço configurado: sem o bloqueio, responderiam como closed. Com DROP, as tentativas ficam sem resposta e são identificadas como filtered. Por isso, o resultado do nmap deve ser acompanhado dos contadores do firewall.

### 4.5. Evidências e resultados obtidos

Após cada teste:

```sh
docker compose exec firewall iptables -L FORWARD -n -v
```

| Teste | Resultado esperado | Evidência disponível |
| --- | --- | --- |
| Cliente para HTTP do web | HTML e TCP 80 open | Confirmado por print em 11/10/2026 |
| Cliente para TCP 81 do web | filtered | Confirmado no mesmo print |
| Consulta SQL pelo web | seguranca, aluno, 172.22.0.10 | Execução informada como bem-sucedida pelo responsável; anexar saída SQL |
| Cliente para banco TCP 5432 | filtered | Execução informada como bem-sucedida pelo responsável; anexar saída do nmap |
| DMZ para cliente TCP 80 | filtered | Confirmado por print em 13/10/2026 |

No print final dos contadores, fornecido em 13/10/2026, foram observados:

| Regra | Pacotes | Bytes |
| --- | --- | --- |
| ESTABLISHED,RELATED | 29 | 3410 |
| HTTP do cliente para web | 1 | 60 |
| PostgreSQL do web para banco | 1 | 60 |
| DROP final | 4 | 240 |

Esses valores mostram passagem de tráfego pelas regras de autorização e bloqueio. O contador DROP é agregado e não identifica sozinho qual teste produziu cada pacote. Os valores variam com novas tentativas e são zerados quando as regras são reaplicadas.

Antes da entrega, salvar os prints em docs/evidencias/ e inserir os links abaixo:

- HTTP e teste das portas 80/81: anexar.
- Consulta SQL do web ao banco: anexar.
- Cliente bloqueado no banco: anexar.
- DMZ bloqueada para o cliente: anexar.
- Contadores FORWARD: anexar.

### 4.6. Encerramento e diagnóstico de problemas

Para consultar os logs:

```sh
docker compose logs firewall web db client
```

Para encerrar:

```sh
docker compose down
```

Esse comando preserva o volume do banco. Se as opções das redes forem alteradas, executar down e depois up -d --build para recriá-las.

## Considerações finais

Os testes confirmaram o acesso HTTP e o bloqueio de conexões não autorizadas. O acesso ao banco e seu bloqueio para o cliente foram informados como bem-sucedidos, e o contador da regra PostgreSQL registrou tráfego. As saídas desses dois testes ainda precisam ser anexadas ao documento.

A solução demonstra segmentação e filtragem de encaminhamento. A página é estática, as credenciais são de laboratório e os containers recebem NET_ADMIN para configurar rotas. Uma implantação real precisaria de medidas adicionais, como HTTPS, proteção das credenciais e redução de permissões.

## Referências

- [Docker Compose — serviços](https://docs.docker.com/reference/compose-file/services/)
- [Docker Compose — redes](https://docs.docker.com/reference/compose-file/networks/)
- [Imagem oficial PostgreSQL](https://github.com/docker-library/docs/blob/master/postgres/README.md)
