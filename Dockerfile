FROM alpine:3.20

RUN apk add --no-cache unbound ca-certificates openssl bind-tools

WORKDIR /app

COPY configs ./configs
COPY scripts ./scripts
COPY var ./var
COPY docs ./docs
COPY README.md ./README.md

# Create an unprivileged user and ensure writable dirs.
RUN adduser -D -H -s /sbin/nologin unbounduser \
  && mkdir -p /app/var /data \
  && chown -R unbounduser:unbounduser /app /data \
  && chmod 700 /data \
  && chmod +x /app/scripts/entrypoint.sh

USER unbounduser

EXPOSE 8853/tcp
EXPOSE 8053/udp
EXPOSE 8053/tcp

ENTRYPOINT ["/bin/sh", "/app/scripts/entrypoint.sh"]
