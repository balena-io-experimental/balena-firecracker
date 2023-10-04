FROM debian:bullseye-slim AS kernel

WORKDIR /src

ARG DEBIAN_FRONTEND=noninteractive

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/$(uname -m)/kernels/vmlinux.bin" -O

###############################################

FROM debian:bullseye-slim AS firecracker

WORKDIR /src

ARG DEBIAN_FRONTEND=noninteractive

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# renovate: datasource=github-releases depName=firecracker-microvm/firecracker
ARG FIRECRACKER_VERSION=v1.4.1
ARG FIRECRACKER_URL=https://github.com/firecracker-microvm/firecracker/releases/download/${FIRECRACKER_VERSION}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN curl -fsSL -O "${FIRECRACKER_URL}/firecracker-${FIRECRACKER_VERSION}-$(uname -m).tgz" \
    && curl -fsSL "${FIRECRACKER_URL}/firecracker-${FIRECRACKER_VERSION}-$(uname -m).tgz.sha256.txt" | sha256sum -c - \
    && tar -xzf "firecracker-${FIRECRACKER_VERSION}-$(uname -m).tgz" --strip-components=1 \
    && for bin in *-"$(uname -m)" ; do install -v "${bin}" "/usr/local/bin/$(echo "${bin}" | sed -rn 's/(.+)-.+-.+/\1/p')" ; done \
    && rm "firecracker-${FIRECRACKER_VERSION}-$(uname -m).tgz"

###############################################

FROM debian:bullseye-slim AS jailer

WORKDIR /usr/src/app

ARG DEBIAN_FRONTEND=noninteractive

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    e2fsprogs \
    file \
    gettext \
    ipcalc \
    iproute2 \
    iptables \
    jq \
    procps \
    rsync \
    uuid-runtime \
    && rm -rf /var/lib/apt/lists/*

COPY --from=firecracker /usr/local/bin/* /usr/local/bin/
COPY --from=kernel /src/vmlinux.bin /jail/boot/vmlinux.bin

RUN addgroup --system firecracker \
    && adduser --system firecracker --ingroup firecracker \
    && chown -R firecracker:firecracker ./

RUN firecracker --version \
    && jailer --version

COPY overlay ./overlay
COPY start.sh config.json ./

RUN chmod +x start.sh overlay/sbin/init overlay/usr/local/bin/fcnet-setup.sh

CMD [ "/usr/src/app/start.sh" ]

ENV CMD curl http://artscene.textfiles.com/asciiart/unicorn

###############################################

FROM alpine:3.18 AS alpine-rootfs

# WORKDIR /src

# # hadolint ignore=DL3018
# RUN apk add --no-cache openrc util-linux

# # Set up a login terminal on the serial console (ttyS0)
# RUN ln -s agetty /etc/init.d/agetty.ttyS0 \
#     && echo ttyS0 > /etc/securetty \
#     && rc-update add agetty.ttyS0 default

# # Make sure special file systems are mounted on boot
# RUN rc-update add devfs boot \
#     && rc-update add procfs boot \
#     && rc-update add sysfs boot

# # Create a tarball of the root file system
# RUN tar cf /rootfs.tar /bin /etc /lib /root /sbin /usr

###############################################

# Use the official Ubuntu image as a base
FROM ubuntu:jammy AS ubuntu-rootfs

# Install the necessary packages
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl iproute2 iputils-ping bind9-dnsutils \
    && rm -rf /var/lib/apt/lists/*

# # Set environment variables to avoid prompts
# ENV DEBIAN_FRONTEND=noninteractive

# # Install the necessary packages
# # hadolint ignore=DL3008
# RUN apt-get update \
#     && apt-get install -y --no-install-recommends curl systemd systemd-sysv \
#     && rm -rf /var/lib/apt/lists/*

# # Remove unnecessary services
# RUN find /etc/systemd/system \
#         /lib/systemd/system \
#         \( \
#         -name "*udev*" \
#         -o -name "*resolved*" \
#         -o -name "*logind*" \
#         -o -name "*getty*" \
#         -o -name "*networkd*" \
#         \) \
#         -exec rm -f {} \;

# # Set systemd as the entrypoint
# STOPSIGNAL SIGRTMIN+3
# CMD [ "/sbin/init" ]

# # Set up necessary mount points
# VOLUME [ "/sys/fs/cgroup" ]

# # Copy the updated systemd service file
# COPY entrypoint.service /etc/systemd/system/entrypoint.service
# RUN systemctl enable entrypoint.service

# COPY init /init
# RUN chmod +x /init

###############################################

FROM ghcr.io/product-os/self-hosted-runners:v3.3.3 AS self-hosted-runners

# Install the necessary packages
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl iproute2 iputils-ping bind9-dnsutils \
    && rm -rf /var/lib/apt/lists/*

###############################################

# Include firecracker wrapper and scripts
FROM jailer AS runtime

# Copy the root file system tarball into the firecracker runtime image
# COPY --from=ubuntu-rootfs /rootfs.tar ./

# WORKDIR /rootfs

COPY --from=ubuntu-rootfs / /usr/src/app/rootfs/

# Create a tarball of the root file system
# RUN tar cf /usr/src/app/rootfs.tar ./

# ENV CMD exec /init
