FROM golang:1.20.3-alpine3.17 AS eget

# hadolint ignore=DL3018
RUN apk add --no-cache \
    build-base \
    ca-certificates \
    git

WORKDIR /app

ARG CGO=0

RUN git clone -n https://github.com/zyedidia/eget . && \
    git checkout --quiet 760f5151eb17fbd1bb592bce7cce57cf9657ce7d && \
    make build

FROM alpine:3.17

# hadolint ignore=DL3018
RUN apk add --no-cache \
    ca-certificates \
    curl \
    docker-cli \
    e2fsprogs \
    file \
    git

WORKDIR /app

COPY --from=eget /app/eget /usr/local/bin/eget

COPY x86_64/ ./x86_64/
COPY aarch64/ ./aarch64/

RUN ln -sf "$(uname -m)"/config.json config.json \
    && ln -sf "$(uname -m)"/eget.toml eget.toml

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG FIRECRACKER_TAG=v1.3.1

RUN eget firecracker-microvm/firecracker --tag ${FIRECRACKER_TAG} && \
    for bin in /usr/local/bin/*-*-* ; \
    do ln -sf "$(basename "${bin}")" "/usr/local/bin/$(basename "${bin}" | rev | cut -d'-' -f3- | rev)" ; \
    done

RUN firecracker --version \
    && jailer --version

COPY entry.sh ./

RUN chmod +x entry.sh

CMD [ "/app/entry.sh" ]
