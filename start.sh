#!/usr/bin/env bash

# https://github.com/firecracker-microvm/firecracker-containerd/blob/main/docs/getting-started.md

set -euo pipefail

trap '/app/devmapper/cleanup.sh' EXIT

/app/devmapper/cleanup.sh
/app/devmapper/create.sh

mkdir -p /var/lib/firecracker-containerd

rootfs_path=/var/lib/firecracker-containerd/runtime/rootfs.img
src_secrets_path=/var/secrets # cannot be in /run or /tmp
dst_secrets_path=/run/secrets # this can be anywhere convenient in the container

print_usage() {
    firecracker-containerd --help
    firecracker-ctr --help
    firecracker-ctr images pull --help
    firecracker-ctr run --help
    firecracker-ctr containers --help
    echo "Sleeping forever..."
    sleep infinity
}

inject_secrets() {
    # unsquashfs --help || true
    echo "Unsquashing rootfs to inject secrets..."
    unsquashfs -d /tmp/squashfs-root "${rootfs_path}"

    # Iterate over all environment variables with the prefix FICD_SECRET_
    for var in "${secrets_keys[@]}"; do
        # Extract the secret_key from the variable name
        secret_key="${var#FICD_SECRET_}"
        (
            cd /tmp/squashfs-root || exit 1
            mkdir -p "$(pwd)/${src_secrets_path}"
            echo "Writing secret '${secret_key}' to rootfs..."
            echo "${!var}" >"$(pwd)/${src_secrets_path}/${secret_key}"
        )
    done

    # mksquashfs --help || true
    echo "Squashing rootfs with injected secrets..."
    mksquashfs /tmp/squashfs-root "${rootfs_path}".new
    mv "${rootfs_path}".new "${rootfs_path}"
    rm -rf /tmp/squashfs-root

    secrets_mount=("--mount" "type=bind,src=${src_secrets_path},dst=${dst_secrets_path},options=rbind:rw")
}

pull_image() {
    echo "Pulling image ${FICD_IMAGE_TAG}..."
    set -x
    # shellcheck disable=SC2086
    firecracker-ctr --address /run/firecracker-containerd/containerd.sock images pull \
        --snapshotter devmapper \
        ${FICD_IMAGE_PULL_OPTIONS:-} "${FICD_IMAGE_TAG}"
    set +x
}

run_container() {
    echo "Running container..."
    set -x
    # shellcheck disable=SC2086
    firecracker-ctr --address /run/firecracker-containerd/containerd.sock run \
        --snapshotter devmapper \
        --runtime aws.firecracker \
        --rm --net-host \
        "${secrets_mount[@]}" \
        ${FICD_RUN_OPTIONS:-} "${FICD_IMAGE_TAG}" "$(uuidgen)" ${FICD_RUN_COMMAND:-} "${run_args[@]}"
    set +x
}

# print_usage

secrets_prefix="FICD_SECRET_"
# shellcheck disable=SC2207
secrets_keys=($(compgen -v "${secrets_prefix}")) || true

if [ ${#secrets_keys[@]} -gt 0 ]; then
    inject_secrets
fi

echo "Starting containerd..."
firecracker-containerd --config /etc/firecracker-containerd/config.toml &
containerd_pid=$!

# Iterate through all environment variables with the prefix FICD_RUN_ARG_
run_args=()
for var in "${!FICD_RUN_ARG_@}"; do
    # Add the value of the current environment variable to the array
    run_args+=("${!var}")
done

pull_image

while true; do
    run_container
    [[ ${FICD_KEEP_ALIVE,,} =~ true|yes|on|1 ]] || break
done

kill -9 "$containerd_pid"
