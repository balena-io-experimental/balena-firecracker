#!/usr/bin/env sh

# https://actuated.dev/blog/kvm-in-github-actions
# https://github.com/firecracker-microvm/firecracker/blob/main/docs/getting-started.md

set -eu

# Get a kernel and rootfs
arch="$(uname -m)"
dest_kernel="/files/vmlinux.bin"
dest_rootfs="/files/rootfs.ext4"

firecracker_socket="/tmp/firecracker.sock"
firecracker_config="/app/config.json"

case "${arch}" in
    x86_64)
        kernel="${KERNEL_x86_64:-https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/x86_64/kernels/vmlinux.bin}"
        rootfs="${ROOTFS_x86_64:-https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/x86_64/rootfs/bionic.rootfs.ext4}"
        ;;
    aarch64)
        kernel="${KERNEL_aarch64:-https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/aarch64/kernels/vmlinux.bin}"
        rootfs="${ROOTFS_aarch64:-https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/aarch64/rootfs/bionic.rootfs.ext4}"
        ;;
    *)
        echo "Firecracker does not support ${arch}!"
        exit 1
        ;;
esac

if [ ! -f "${dest_kernel}" ]; then
    echo "Downloading ${kernel}..."
    curl -fsSL -o "${dest_kernel}" "${kernel}"
fi

if [ ! -f "${dest_rootfs}" ]; then
    echo "Downloading ${rootfs}..."
    curl -fsSL -o "${dest_rootfs}" "${rootfs}"
fi

echo "Starting firecracker"
rm -f "${firecracker_socket}"
firecracker --api-sock "${firecracker_socket}" --config-file "${firecracker_config}"
