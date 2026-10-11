#!/bin/sh
set -eu

if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]; then
    sysctl -w net.ipv4.ip_forward=1
fi

# Começa bloqueando o encaminhamento e monta as regras do laboratório.
iptables -P FORWARD DROP
iptables -F FORWARD

# Permite as respostas de conexões autorizadas.
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# O cliente pode acessar somente o HTTP do servidor web.
iptables -A FORWARD -s 172.20.0.10 -d 172.21.0.10 -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT

# Registra nos contadores os pacotes bloqueados.
iptables -A FORWARD -j DROP

touch /tmp/firewall-pronto
echo "Firewall iniciado: HTTP liberado do cliente para a DMZ."
exec "$@"
