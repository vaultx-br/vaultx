FROM alpine:3.22
RUN apk add --no-cache restic sqlite tzdata ca-certificates curl jq
COPY backup /usr/local/bin/backup
COPY entrypoint.sh /usr/local/bin/entrypoint
RUN chmod 755 /usr/local/bin/backup /usr/local/bin/entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint"]
