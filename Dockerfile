FROM ubuntu:22.04

ARG SSH_PASSWORD=ansible

RUN apt-get update && apt-get install -y \
    openssh-server \
    python3 \
    sudo \
    nginx \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /var/run/sshd
RUN echo "root:${SSH_PASSWORD}" | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
