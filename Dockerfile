
FROM golang:1.18-alpine3.17 AS containerd

WORKDIR /containerd

# hadolint ignore=DL3018
RUN apk add --no-cache \
    build-base \
    ca-certificates \
    git \
    grep

# https://github.com/firecracker-microvm/firecracker-containerd
RUN git clone --recurse-submodules https://github.com/firecracker-microvm/firecracker-containerd.git . && \
    git checkout --quiet 051a16cc9fd754c91ccd12a3827664927e25ddcd

ARG CGO=0
ARG GO111MODULE=on
ARG INSTALLROOT=/opt

RUN make all && make install

###############################################

FROM public.ecr.aws/firecracker/fcuvm:v55 AS firecracker

WORKDIR /firecracker

# https://github.com/firecracker-microvm/firecracker
RUN git clone --recurse-submodules https://github.com/firecracker-microvm/firecracker.git . && \
    git checkout --quiet v1.3.3

RUN ./tools/release.sh --libc musl --profile release && \
    install -D ./build/cargo_target/*-unknown-linux-musl/release/firecracker /opt/bin/firecracker && \
    install -D ./build/cargo_target/*-unknown-linux-musl/release/jailer /opt/bin/jailer

###############################################

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

COPY --from=containerd /opt/bin/ /usr/local/bin/
COPY --from=firecracker /opt/bin/ /usr/local/bin/

RUN firecracker --version && \
    firecracker-containerd --version && \
    firecracker-ctr --version && \
    jailer --version

COPY entry.sh ./

RUN chmod +x entry.sh

CMD [ "/app/entry.sh" ]
