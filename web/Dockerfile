FROM nginx:stable-alpine

# Necessário para configurar a rota de resposta ao cliente.
RUN apk add --no-cache iproute2 postgresql-client nmap

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
