FROM debian:13-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install --no-install-recommends -y \
        corosync-qnetd \
        openssh-client \
        sshpass \
        ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/corosync-qnetd /data

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/data"]

EXPOSE 5403

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/corosync-qnetd", "-f"]
