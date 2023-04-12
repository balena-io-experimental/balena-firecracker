#!/usr/bin/env sh

# https://actuated.dev/blog/kvm-in-github-actions
# https://github.com/firecracker-microvm/firecracker/blob/main/docs/getting-started.md
# https://github.com/firecracker-microvm/firecracker/blob/main/docs/rootfs-and-kernel-setup.md

set -eu

firecracker_socket="/tmp/firecracker.sock"
firecracker_config="/app/config.json"

kernel_file="/files/vmlinux.bin"
rootfs_file="/files/rootfs.ext4"
rootfs_mount="/tmp/rootfs"

KERNEL_SOURCE="${KERNEL_SOURCE:-"https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/$(uname -m)/kernels/vmlinux.bin"}"
ROOTFS_SOURCE="${ROOTFS_SOURCE:-"docker.io/library/ubuntu:latest"}"
ROOTFS_SIZE="${ROOTFS_SIZE:-"1024M"}"

mkdir -p /files

# for now always force a new rootfs and kernel download
rm -vf /files/*

if [ ! -f "${rootfs_file}" ]; then
    echo "Creating rootfs ${rootfs_file}..."
    truncate -s "${ROOTFS_SIZE}" "${rootfs_file}"
    mkfs.ext4 -q "${rootfs_file}"

    mkdir -p "${rootfs_mount}"
    mount -v "${rootfs_file}" "${rootfs_mount}"

    docker pull "${ROOTFS_SOURCE}"
    docker export "$(docker create --init "${ROOTFS_SOURCE}")" | tar x -C "${rootfs_mount}"

    echo "Unmounting rootfs ${rootfs_file}..."
    umount "${rootfs_mount}"
fi

if [ ! -f "${kernel_file}" ]; then
    echo "Downloading kernel ${KERNEL_SOURCE}..."
    curl -fsSL -o "${kernel_file}" "${KERNEL_SOURCE}"
fi

echo "Starting firecracker"
rm -f "${firecracker_socket}"
firecracker --api-sock "${firecracker_socket}" --config-file "${firecracker_config}"
