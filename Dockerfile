
FROM golang:1.18-alpine3.17 AS containerd-base

WORKDIR /containerd

# hadolint ignore=DL3018
RUN apk add --no-cache \
    build-base \
    ca-certificates \
    curl \
    debootstrap \
    git \
    grep \
    libseccomp-dev \
    libseccomp-static \
    squashfs-tools

# https://github.com/firecracker-microvm/firecracker-containerd
RUN git clone --recurse-submodules https://github.com/firecracker-microvm/firecracker-containerd.git . && \
    git checkout --quiet 051a16cc9fd754c91ccd12a3827664927e25ddcd

###############################################

FROM containerd-base AS containerd

ARG CGO_ENABLED=0
ARG GO111MODULE=on
ARG INSTALLROOT=/opt
ARG STATIC_AGENT=on

RUN make all && make install

###############################################

FROM containerd-base AS runc

RUN make -C _submodules/runc static

###############################################

FROM containerd-base AS rootfs

WORKDIR /containerd/tools/image-builder

COPY --from=containerd /containerd/agent/agent ./files_ephemeral/usr/local/bin/agent
COPY --from=runc /containerd/_submodules/runc/runc ./files_ephemeral/usr/local/bin/runc

RUN mkdir -p tmp/rootfs && \
    make rootfs.img

###############################################

FROM containerd-base AS kernel

WORKDIR /opt

RUN curl -fsSL "https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/$(uname -m)/kernels/vmlinux.bin" -O

###############################################

# https://gallery.ecr.aws/firecracker/fcuvm
# https://github.com/firecracker-microvm/firecracker/blob/main/tools/devctr/Dockerfile
FROM public.ecr.aws/firecracker/fcuvm:v60 AS firecracker

WORKDIR /firecracker

# https://github.com/firecracker-microvm/firecracker
RUN git clone --recurse-submodules https://github.com/firecracker-microvm/firecracker.git . && \
    git checkout --quiet v1.3.3

# RUN ./tools/release.sh --libc musl --profile release && \
#     install -D ./build/cargo_target/"$(uname -m)-unknown-linux-musl"/release/firecracker /opt/bin/firecracker && \
#     install -D ./build/cargo_target/"$(uname -m)-unknown-linux-musl"/release/jailer /opt/bin/jailer

RUN mkdir -p ./build/cargo_git_registry ./build/cargo_registry

RUN cargo build --release --target "$(uname -m)-unknown-linux-musl" && \
    install -D ./build/cargo_target/"$(uname -m)-unknown-linux-musl"/release/firecracker /opt/bin/firecracker

RUN cargo build --release --target "$(uname -m)-unknown-linux-musl" -p jailer && \
    install -D ./build/cargo_target/"$(uname -m)-unknown-linux-musl"/release/jailer /opt/bin/jailer

###############################################

FROM alpine:3.17 AS runtime

# hadolint ignore=DL3018
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    device-mapper \
    e2fsprogs \
    losetup \
    lsblk \
    pigz \
    squashfs-tools \
    tini \
    util-linux-misc \
    uuidgen

WORKDIR /app

COPY --from=containerd /opt/bin/ /usr/local/bin/
# COPY --from=containerd /containerd/tools/ ./tools/
COPY --from=firecracker /opt/bin/ /usr/local/bin/

RUN firecracker --version && \
    firecracker-containerd --version && \
    firecracker-ctr --version && \
    jailer --version

COPY --from=kernel /opt/vmlinux.bin /var/lib/firecracker-containerd/runtime/vmlinux.bin
COPY --from=rootfs /containerd/tools/image-builder/rootfs.img /var/lib/firecracker-containerd/runtime/rootfs.img

COPY config.toml /etc/firecracker-containerd/config.toml
COPY runtime.json /etc/containerd/firecracker-runtime.json

COPY devmapper/ ./devmapper/
COPY start.sh ./

RUN chmod +x start.sh devmapper/*.sh

ENTRYPOINT [ "/sbin/tini", "--" ]

CMD [ "/app/start.sh" ]

ENV FICD_IMAGE_TAG docker.io/library/hello-world:latest
ENV FICD_KEEP_ALIVE true
