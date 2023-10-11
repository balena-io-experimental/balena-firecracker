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
    bridge-utils \
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
    tcpdump \
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

RUN chmod +x start.sh overlay/sbin/* overlay/usr/local/bin/*

ENTRYPOINT [ "/usr/src/app/start.sh" ]

###############################################

# # This is a stage we use for testing with livepush as it
# # includes an example rootfs.
# FROM alpine:3.18 AS test-rootfs

# # hadolint ignore=DL3018
# RUN apk add --no-cache bash ca-certificates curl iproute2

# # Include firecracker wrapper and scripts
# FROM jailer AS test-jailer

# # Use livepush directives to conditionally run this test stage
# # for livepush, but not for default builds used in publishing.
# #dev-copy= --from=test-rootfs / /usr/src/app/rootfs/
# #dev-cmd-live=/usr/local/bin/usage.sh

###############################################

# This is a stage we use for testing with livepush as it
# includes an example rootfs.
FROM debian:bookworm AS test-rootfs

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl iproute2 iputils-ping openssl tcpdump ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Include firecracker wrapper and scripts
FROM jailer AS test-jailer

# Use livepush directives to conditionally run this test stage
# for livepush, but not for default builds used in publishing.
#dev-copy= --from=test-rootfs / /usr/src/app/rootfs/
#dev-cmd-live=/usr/local/bin/usage.sh

###############################################

# This is the stage we want to publish, but it has no rootfs
# so we can't use it for livepush testing.
FROM jailer AS default
