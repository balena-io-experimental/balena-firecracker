#!/usr/bin/env sh

# https://github.com/firecracker-microvm/firecracker-containerd/blob/main/docs/getting-started.md

set -eu

./setup-devmapper.sh

mkdir -p /var/lib/firecracker-containerd

# start containerd
firecracker-containerd --config /etc/firecracker-containerd/config.toml

# pull an image
firecracker-ctr --address /run/firecracker-containerd/containerd.sock images pull \
    --snapshotter devmapper \
    docker.io/library/busybox:latest

# start a container
firecracker-ctr --address /run/firecracker-containerd/containerd.sock run \
    --snapshotter devmapper \
    --runtime aws.firecracker \
    --rm --tty --net-host \
    docker.io/library/busybox:latest busybox-test
