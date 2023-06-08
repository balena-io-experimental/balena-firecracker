#!/bin/bash

# Sets up a devicemapper thin pool with loop devices in
# /var/lib/firecracker-containerd/snapshotter/devmapper

set -ex

DIR=/var/lib/firecracker-containerd/snapshotter/devmapper
POOL=fc-dev-thinpool

mkdir -p "${DIR}"

# trap 'losetup -d "${DATADEV}"; losetup -d "${METADEV}"; dmsetup remove "${POOL}"' EXIT

# remove existing pools matching the prefix
for pool in $(dmsetup ls | grep "^${POOL}*" | sort -r | awk '{print $1}'); do
    dmsetup remove "${pool}"
done

# remove existing loop devices matching the data mountpoint
for device in $(losetup --output NAME,BACK-FILE --noheadings | awk -v path="${DIR}/data" '{if ($2 == path) print $1}'); do
    losetup -d "${device}"
done

# remove existing loop devices matching the metadata mountpoint
for device in $(losetup --output NAME,BACK-FILE --noheadings | awk -v path="${DIR}/metadata" '{if ($2 == path) print $1}'); do
    losetup -d "${device}"
done

if [ ! -f "${DIR}/data" ]; then
    truncate -s 10G "${DIR}/data"
fi

if [ ! -f "${DIR}/metadata" ]; then
    truncate -s 1G "${DIR}/metadata"
fi

losetup -a

# DATADEV="$(losetup --output NAME,BACK-FILE --noheadings | awk -v path="${DIR}/data" '{if ($2 == path) print $1}' | tail -n1)"
# if [[ -z "${DATADEV}" ]]; then
#     DATADEV="$(losetup --find --show ${DIR}/data)"
# fi

# METADEV="$(losetup --output NAME,BACK-FILE --noheadings | awk -v path="${DIR}/metadata" '{if ($2 == path) print $1}' | tail -n1)"
# if [[ -z "${METADEV}" ]]; then
#     METADEV="$(losetup --find --show ${DIR}/metadata)"
# fi

DATADEV="$(losetup --find --show ${DIR}/data)"
METADEV="$(losetup --find --show ${DIR}/metadata)"

SECTORSIZE=512
DATASIZE="$(blockdev --getsize64 -q ${DATADEV})"
LENGTH_SECTORS=$(bc <<<"${DATASIZE}/${SECTORSIZE}")
DATA_BLOCK_SIZE=128  # see https://www.kernel.org/doc/Documentation/device-mapper/thin-provisioning.txt
LOW_WATER_MARK=32768 # picked arbitrarily
THINP_TABLE="0 ${LENGTH_SECTORS} thin-pool ${METADEV} ${DATADEV} ${DATA_BLOCK_SIZE} ${LOW_WATER_MARK} 1 skip_block_zeroing"

if ! dmsetup reload "${POOL}" --table "${THINP_TABLE}"; then
    dmsetup create "${POOL}" --table "${THINP_TABLE}"
fi
