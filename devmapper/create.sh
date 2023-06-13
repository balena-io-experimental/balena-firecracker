#!/usr/bin/env bash

# https://docs.docker.com/storage/storagedriver/device-mapper-driver/#manage-devicemapper
# https://github.com/firecracker-microvm/firecracker-containerd/blob/main/docs/getting-started.md
# https://github.com/kata-containers/kata-containers/blob/main/docs/how-to/how-to-use-kata-containers-with-firecracker.md

# Sets up a devicemapper thin pool with loop devices in
# /var/lib/firecracker-containerd/snapshotter/devmapper

set -euo pipefail

DEVMAPPER_ROOT=/var/lib/firecracker-containerd/snapshotter/devmapper
DEVMAPPER_POOL=fc-dev-thinpool

mkdir -p "${DEVMAPPER_ROOT}"

if [ ! -f "${DEVMAPPER_ROOT}/data" ]; then
    truncate -s 10G "${DEVMAPPER_ROOT}/data"
fi

if [ ! -f "${DEVMAPPER_ROOT}/metadata" ]; then
    truncate -s 1G "${DEVMAPPER_ROOT}/metadata"
fi

losetup -a

DATADEV="$(losetup --find --show ${DEVMAPPER_ROOT}/data)"
METADEV="$(losetup --find --show ${DEVMAPPER_ROOT}/metadata)"

SECTORSIZE=512
DATASIZE="$(blockdev --getsize64 -q ${DATADEV})"
LENGTH_SECTORS=$(bc <<<"${DATASIZE}/${SECTORSIZE}")
DATA_BLOCK_SIZE=128  # see https://www.kernel.org/doc/Documentation/device-mapper/thin-provisioning.txt
LOW_WATER_MARK=32768 # picked arbitrarily
THINP_TABLE="0 ${LENGTH_SECTORS} thin-pool ${METADEV} ${DATADEV} ${DATA_BLOCK_SIZE} ${LOW_WATER_MARK} 1 skip_block_zeroing"

dmsetup create "${DEVMAPPER_POOL}" --table "${THINP_TABLE}"
