#!/bin/sh
set -eu

# As respostas às outras redes passam pelo firewall.
ip route replace 172.20.0.0/24 via 172.22.0.2
ip route replace 172.21.0.0/24 via 172.22.0.2

# Mantém a inicialização e a troca de usuário da imagem oficial.
exec /usr/local/bin/docker-entrypoint.sh "$@"
