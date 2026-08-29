FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/home/ubuntu/.local/bin:${PATH}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        build-essential \
        ca-certificates \
        curl \
        git \
        jq \
        openssh-client \
        pkg-config \
        ripgrep \
        unzip \
    && rm -rf /var/lib/apt/lists/*

USER ubuntu
WORKDIR /workspace

RUN mkdir -p /home/ubuntu/.local/bin \
    && curl -fsSL \
        https://github.com/aaif-goose/goose/releases/download/stable/download_cli.sh \
       | CONFIGURE=false \
         GOOSE_BIN_DIR=/home/ubuntu/.local/bin \
         bash

RUN goose --version

EXPOSE 3284

ENTRYPOINT ["goose"]
CMD ["serve", "--host", "0.0.0.0", "--port", "3284"]