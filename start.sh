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
    "${FICD_IMAGE_TAG}"

while true; do
    # start a container
    # shellcheck disable=SC2086
    firecracker-ctr --address /run/firecracker-containerd/containerd.sock run \
        --snapshotter devmapper \
        --runtime aws.firecracker \
        --rm --net-host ${FICD_EXTRA_OPTS:-} \
        "${FICD_IMAGE_TAG}" "$(uuidgen)" ${FICD_CMD:-}

    [[ ${FICD_KEEP_ALIVE,,} =~ true|yes|on|1 ]] || break
done

kill -9 "$containerd_pid"
