#!/bin/sh
set -eu

# Permite que o firewall encaminhe pacotes entre as redes.
# Se o Docker já habilitou o encaminhamento, não precisamos alterar /proc.
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]; then
    sysctl -w net.ipv4.ip_forward=1
fi

echo "Firewall iniciado com encaminhamento IPv4 habilitado."

# As regras de iptables serão adicionadas na etapa de configuração da rede.
exec "$@"
