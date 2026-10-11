FROM alpine:3.22

RUN apk add --no-cache iptables iproute2

COPY entrypoint.sh /entrypoint.sh
# Corrige as quebras de linha quando o projeto é baixado no Windows.
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
