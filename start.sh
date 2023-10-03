#!/usr/bin/env bash

# https://actuated.dev/blog/kvm-in-github-actions
# https://github.com/firecracker-microvm/firecracker/blob/main/docs/getting-started.md
# https://github.com/firecracker-microvm/firecracker/blob/main/docs/rootfs-and-kernel-setup.md

set -eu

config_file="/usr/src/app/config.json"
kernel_file="/usr/src/app/vmlinux.bin"
rootfs_tar="/usr/src/app/rootfs.tar"

rootfs_size="${ROOTFS_SIZE:-"2048M"}"
datafs_size="${DATAFS_SIZE:-"8192M"}"

datafs_ext4="/data/datafs.ext4"

tap_subnet="172.16.0.0/24"

# This can optionally be a tmpfs mount via docker compose
chroot_base="/srv/jailer"

host_iface_id="eth0"
iface_id="net1"

# MicroVM unique identifier.
# The jailer will use this id to create a unique chroot directory for the MicroVM
# among other things.
id="$(uuidgen)"

is_tmpfs() {
    filesystem_type=$(stat -f -c '%T' "${1}")
    if [ "$filesystem_type" = "tmpfs" ]; then
        return 0
    else
        return 1
    fi
}

remount_tmpfs_exec() {
    mkdir -p "${1}"

    if is_tmpfs "${1}"; then
        echo "Remounting ${1} with the execute bit set..."
        mount -o remount,rw,exec tmpfs /srv
    else
        echo "Missing execute permissions on ${1}" >&2
        exit 1
    fi
}

copy_kernel() {
    echo "Copying kernel..."

    cp -a "${kernel_file}" "${1}"
}

write_ctr_secrets() {
    echo "Writing secrets file..."

    mkdir -p "$(dirname "${1}")"

    # Loop through all environment variables
    for var in $(compgen -e); do
        # Check if the variable starts with "CTR_"
        if [[ $var == CTR_* ]]; then
            # Write the variable and its value to the secrets file
            echo "$var=${!var}" >>"${1}"
        fi
    done
}

populate_rootfs() {
    echo "Populating rootfs..."

    local rootfs_tmp="/tmp/rootfs"

    truncate -s "${rootfs_size}" "${1}"
    mkfs.ext4 -q "${1}"
    mkdir -p "${rootfs_tmp}"
    mount "${1}" "${rootfs_tmp}"

    tar xf "${rootfs_tar}" -C "${rootfs_tmp}" bin etc lib root sbin usr
    for dir in dev proc run sys var; do mkdir -p "${rootfs_tmp}/${dir}"; done

    write_ctr_secrets "${rootfs_tmp}/var/secrets"

    umount "${rootfs_tmp}"

    chown firecracker:firecracker "${1}"
}

populate_datafs() {
    mkdir -p "$(dirname "${datafs_ext4}")"

    if [ ! -f "${datafs_ext4}" ]; then
        echo "Populating datafs..."
        truncate -s "${datafs_size}" "${datafs_ext4}"
        mkfs.ext4 -q "${datafs_ext4}"
    fi

    chown firecracker:firecracker "${datafs_ext4}"

    # bind mount persistent data directory into the firecracker chroot
    mkdir -p "$(dirname "${1}")"
    mount --bind "$(dirname "${datafs_ext4}")" "$(dirname "${1}")"
}

prepare_config() {
    echo "Preparing config..."

    local dest_config="${1}"

    envsubst <"${config_file}" >"${1}"

    if [ -n "${VCPU_COUNT:-}" ]; then
        jq ".\"machine-config\".vcpu_count = ${VCPU_COUNT}" "${dest_config}" >"${dest_config}".tmp
        mv "${dest_config}".tmp "${dest_config}"
    fi

    if [ -n "${MEM_SIZE_MIB:-}" ]; then
        jq ".\"machine-config\".mem_size_mib = ${MEM_SIZE_MIB}" "${dest_config}" >"${dest_config}".tmp
        mv "${dest_config}".tmp "${dest_config}"
    fi

    jq ".\"network-interfaces\"[0].iface_id = \"${iface_id}\"" "${dest_config}" >"${dest_config}".tmp
    mv "${dest_config}".tmp "${dest_config}"

    jq ".\"network-interfaces\"[0].guest_mac = \"${guest_mac}\"" "${dest_config}" >"${dest_config}".tmp
    mv "${dest_config}".tmp "${dest_config}"

    jq ".\"network-interfaces\"[0].host_dev_name = \"${tap_dev}\"" "${dest_config}" >"${dest_config}".tmp
    mv "${dest_config}".tmp "${dest_config}"
}

find_next_tap_device() {
    subnet="${1:-172.16.0.0/24}"
    i=0
    while true; do
        tap_dev="tap$i"
        if ! ip link show "$tap_dev" >/dev/null 2>&1; then
            mac_addr="$(printf '52:54:%02x:%02x:%02x:%02x\n' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)) $((i % 256)))"
            ip_addr="$(ipcalc -nb "$subnet" | awk '/^Network:/ {print $2}')"
            ip_octet1="$(echo "$ip_addr" | cut -d. -f1)"
            ip_octet2="$(echo "$ip_addr" | cut -d. -f2)"
            ip_octet3="$((i / 256))"
            ip_octet4="$((i % 256 + 2))"
            ip_addr="$ip_octet1.$ip_octet2.$ip_octet3.$ip_octet4"
            echo "$tap_dev $mac_addr $ip_addr/$(echo "$subnet" | awk -F/ '{print $2}')"
            return
        fi
        i=$((i + 1))
    done
}

create_tap_device() {
    echo "Creating ${tap_dev} device..."

    # delete existing tap device
    ip link del "${tap_dev}" 2>/dev/null || true

    # create tap device
    ip tuntap add dev "${tap_dev}" mode tap user firecracker
    ip addr add "${tap_ip}" dev "${tap_dev}"
    ip link set dev "${tap_dev}" up
}

enable_forwarding() {
    echo "Enabling ip forwarding..."

    # enable forwarding
    sysctl -w net.ipv4.ip_forward=1
}

apply_routing() {
    echo "Applying iptables rules..."

    # delete existing matching rules
    iptables -t nat -D POSTROUTING -o "${host_iface_id}" -j MASQUERADE 2>/dev/null || true
    iptables -D FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "${tap_dev}" -o "${host_iface_id}" -j ACCEPT 2>/dev/null || true

    # backup existing rules
    iptables-legacy-save >/etc/iptables.rules.old

    # create rules
    iptables -t nat -A POSTROUTING -o "${host_iface_id}" -j MASQUERADE
    iptables -I FORWARD 1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -I FORWARD 1 -i "${tap_dev}" -o "${host_iface_id}" -j ACCEPT
}

create_logs_fifo() {
    mkdir -p "$(dirname "${1}")"

    # Create a named pipe
    mkfifo "${1}"

    # Redirect the output of the named pipe to /dev/stdout
    cat "${1}" >/dev/stdout &

    chown firecracker:firecracker "${1}"
}

cleanup() {

    echo "Cleaning up..."

    ip link del "${tap_dev}" 2>/dev/null || true

    if [ -f iptables.rules.old ]; then
        iptables-legacy-restore </etc/iptables.rules.old
    fi
}

trap cleanup EXIT

remount_tmpfs_exec "$(dirname "${chroot_base}")"

read -r tap_dev guest_mac tap_ip <<<"$(find_next_tap_device "${tap_subnet}")"
echo "Using tap device $tap_dev with MAC address $guest_mac and IP address $tap_ip"

create_tap_device
enable_forwarding
apply_routing

# These chroot directories will be created by the jailer if they don't exist
# but we need to put the firecracker files in there first.
echo "Creating jailer chroot..."
mkdir -p "${chroot_base}/firecracker/${id}/root"
(
    cd "${chroot_base}/firecracker/${id}/root" || exit 1
    # TODO: skip copying the kernel and bind mount to chroot instead
    copy_kernel vmlinux.bin
    populate_rootfs rootfs.ext4
    # TODO: skip copying the VM config and bind mount to chroot instead
    prepare_config config.json
    create_logs_fifo logs.fifo
    populate_datafs data/datafs.ext4
)

# /usr/local/bin/firecracker --help

echo "Starting firecracker via jailer..."
# https://github.com/firecracker-microvm/firecracker/blob/main/docs/jailer.md
exec /usr/local/bin/jailer --id "${id}" \
    --exec-file /usr/local/bin/firecracker \
    --chroot-base-dir "${chroot_base}" \
    --uid "$(id -u firecracker)" \
    --gid "$(id -g firecracker)" \
    -- \
    --api-sock /run/firecracker.socket \
    --config-file config.json \
    --log-path logs.fifo
