#!/usr/bin/env bash

# https://github.com/firecracker-microvm/firecracker-containerd/blob/main/docs/getting-started.md

set -euo pipefail

trap '/app/devmapper/cleanup.sh' EXIT

/app/devmapper/cleanup.sh
/app/devmapper/create.sh

mkdir -p /var/lib/firecracker-containerd

# start containerd
firecracker-containerd --config /etc/firecracker-containerd/config.toml &
containerd_pid=$!

# pull an image
firecracker-ctr --address /run/firecracker-containerd/containerd.sock images pull \
    --snapshotter devmapper \
    "${RUN_IMAGE:-"docker.io/library/busybox:latest"}"

# start a container
# shellcheck disable=SC2086
exec firecracker-ctr --address /run/firecracker-containerd/containerd.sock run \
    --snapshotter devmapper \
    --runtime aws.firecracker \
    --rm --net-host ${EXTRA_RUN_OPTS:-} ${EXTRA_RUN_FLAGS:-} \
    "${RUN_IMAGE:-"docker.io/library/busybox:latest"}" "$(uuidgen)" ${RUN_COMMAND:-} ${EXTRA_RUN_ARGS:-}

kill -9 "$containerd_pid"
