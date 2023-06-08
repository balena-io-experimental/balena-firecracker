#!/bin/bash

# https://docs.docker.com/storage/storagedriver/device-mapper-driver/#manage-devicemapper
# https://github.com/firecracker-microvm/firecracker-containerd/blob/main/docs/getting-started.md
# https://github.com/kata-containers/kata-containers/blob/main/docs/how-to/how-to-use-kata-containers-with-firecracker.md

DEVMAPPER_ROOT=/var/lib/firecracker-containerd/snapshotter/devmapper
DEVMAPPER_POOL=fc-dev-thinpool

# remove existing pools matching the prefix
for pool in $(dmsetup ls | grep "^${DEVMAPPER_POOL}*" | sort -r | awk '{print $1}'); do
    dmsetup remove "${pool}"
done

# remove existing loop devices matching the data mountpoint
for device in $(losetup --output NAME,BACK-FILE --noheadings | awk -v path="${DEVMAPPER_ROOT}/data" '{if ($2 == path) print $1}'); do
    losetup -d "${device}"
done

# remove existing loop devices matching the metadata mountpoint
for device in $(losetup --output NAME,BACK-FILE --noheadings | awk -v path="${DEVMAPPER_ROOT}/metadata" '{if ($2 == path) print $1}'); do
    losetup -d "${device}"
done
