FROM postgres:16-alpine

RUN apk add --no-cache iproute2

COPY entrypoint.sh /entrypoint-rede.sh
RUN sed -i 's/\r$//' /entrypoint-rede.sh && chmod +x /entrypoint-rede.sh

ENTRYPOINT ["/entrypoint-rede.sh"]
CMD ["postgres"]
