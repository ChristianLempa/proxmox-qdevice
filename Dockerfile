FROM debian:13-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install --no-install-recommends -y \
        corosync-qnetd \
        openssh-client \
        openssh-server \
        sshpass \
        ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure SSH
RUN mkdir -p /run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "root:qdevice" | chpasswd

RUN mkdir -p /var/run/corosync-qnetd /data

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/data"]

EXPOSE 5403 22

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/corosync-qnetd", "-f"]
