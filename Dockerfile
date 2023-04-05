FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

# hadolint ignore=DL3008
RUN apt-get update && apt-get install --no-install-recommends -y \
    ca-certificates \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG FIRECRACKER_TAG=v1.3.1
ARG FIRECRACKER_SHA256_x86_64=55f4e8dd3693aaa0584f6fc2656d05e6d197693e02c8170a0673f95ea73504b2
ARG FIRECRACKER_SHA256_aarch64=3832016b8f365fc6cd851caf7662061a2ffa0596227f4d9c7fcb4059845c2369

RUN curl -fsSL -o firecracker.tgz "https://github.com/firecracker-microvm/firecracker/releases/download/${FIRECRACKER_TAG}/firecracker-${FIRECRACKER_TAG}-$(uname -m).tgz" \
    && sha256="FIRECRACKER_SHA256_$(uname -m)" \
    && echo "${!sha256}  firecracker.tgz" | sha256sum -c - \
    && tar -xzf firecracker.tgz --strip-components=1 \
    && for bin in *-$(uname -m) ; do install -v "${bin}" "/usr/local/bin/$(echo "${bin}" | sed -rn 's/(.+)-.+-.+/\1/p')" ; done \
    && rm firecracker.tgz

COPY entry.sh config_*.json ./

RUN chmod +x entry.sh

CMD [ "/app/entry.sh" ]
