#!/usr/bin/env bash

# https://actuated.dev/blog/kvm-in-github-actions
# https://github.com/firecracker-microvm/firecracker/blob/main/docs/getting-started.md
# https://github.com/firecracker-microvm/firecracker/blob/main/docs/rootfs-and-kernel-setup.md

set -eu

# The jailer will use this id to create a unique chroot directory for the MicroVM
# among other things.
id="$(uuidgen)"

# The jailer will create a chroot directory for the MicroVM under this base directory
# If this is detected as a tmpfs mount it will be remounted as rw,exec
chroot_base="/srv/jailer"
chroot_dir="${chroot_base}/firecracker/${id}/root"

find_next_tap_device() {
    local subnet="${1}"
    local address
    local short_netmask
    local ip_octet1 ip_octet2 ip_octet3

    address="$(ipcalc -nb "$subnet" | awk '/^Address:/ {print $2}')"
    short_netmask="$(ipcalc -nb "$subnet" | awk '/^Netmask:/ {print $4}')"

    ip_octet1="$(echo "$address" | cut -d. -f1)"
    ip_octet2="$(echo "$address" | cut -d. -f2)"

    local _tap_dev _tap_ip _guest_mac

    i=0
    while true; do
        _tap_dev="tap$i"
        if ! ip link show "$_tap_dev" >/dev/null 2>&1; then

            ip_octet3="$((i % 256))"
            _tap_ip="${ip_octet1}.${ip_octet2}.${ip_octet3}.1/${short_netmask}"
            _guest_mac="$(printf '52:54:%02X:%02X:%02X:%02X\n' "${ip_octet1}" "${ip_octet2}" "${ip_octet3}" 2)"
            echo "${_tap_dev} ${_tap_ip} ${_guest_mac}"
            return
        fi
        i=$((i + 1))
    done
}

# Network settings
# guest_mac="$(printf '52:54:00:%02X:%02X:%02X\n' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))"
guest_subnet="10.10.0.0/30"
iface_id="$(ip route | grep default | awk '{print $5}')"

read -r tap_dev tap_ip guest_mac <<<"$(find_next_tap_device "${guest_subnet}")"

echo "Interface ID: ${iface_id}"
echo "Guest MAC: ${guest_mac}"
echo "Host Device Name: ${tap_dev}"

# Check for hardware acceleration
if ! ls /dev/kvm &>/dev/null; then
    echo "KVM hardware acceleration unavailable. Pass --device /dev/kvm in your Docker run command."
    exit 1
fi

# Set default cores to same as system if not specified
if [ -z "${VCPU_COUNT:-}" ]; then
    VCPU_COUNT=$(nproc --all)
fi

# Set default memory to same as system if not specified
if [ -z "${MEM_SIZE_MIB:-}" ]; then
    MEM_SIZE_MIB=$(($(free -m | grep -oP '\d+' | head -6 | tail -1) - 50))
fi

# Set default space to same as available on system if not specified
if [ -z "${ROOTFS_SIZE:-}" ]; then
    ROOTFS_SIZE=$(df -Ph . | tail -1 | awk '{print $4}')
fi

# Set default space to same as available on system if not specified
if [ -z "${DATAFS_SIZE:-}" ]; then
    DATAFS_SIZE=$(df -Ph . | tail -1 | awk '{print $4}')
fi

if [ -z "${KERNEL_BOOT_ARGS:-}" ]; then
    KERNEL_BOOT_ARGS="console=ttyS0 reboot=k panic=1 pci=off"

    if [ "$(uname -m)" = "aarch64" ]; then
        KERNEL_BOOT_ARGS="keep_bootcon ${KERNEL_BOOT_ARGS}"
    fi
fi

echo "Virtual CPUs: ${VCPU_COUNT}"
echo "Memory: ${MEM_SIZE_MIB}M"
echo "RootFS Size: ${ROOTFS_SIZE}"
echo "DataFS Size: ${DATAFS_SIZE}"
echo "Kernel boot args: ${KERNEL_BOOT_ARGS}"

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
    fi
}

write_ctr_secrets() {
    echo "Writing secrets file..."

    mkdir -p "$(dirname "${1}")"

    # Loop through all environment variables
    for var in $(compgen -e); do
        # Check if the variable starts with "CTR_"
        if [[ $var == CTR_* ]]; then
            # Remove the "CTR_" prefix and write the variable and its value to the secrets file
            echo "${var#CTR_}=${!var}" >>"${1}"
        fi
    done
}

resolve_init_vars() {
    local init_script="${1}"

    envsubst <"${init_script}" >"${init_script}.tmp"
    mv "${init_script}.tmp" "${init_script}"
    chmod +x "${init_script}"

    # cat "${init_script}"
}

populate_rootfs() {
    echo "Populating rootfs..."

    local src_rootfs="${1}"
    local dst_rootfs="${2}"

    local rootfs_mnt="/tmp/rootfs"

    mkdir -p "$(dirname "${dst_rootfs}")"
    rm -f "${dst_rootfs}"

    truncate -s "${ROOTFS_SIZE}" "${dst_rootfs}"
    mkfs.ext4 -q "${dst_rootfs}"
    mkdir -p "${rootfs_mnt}"
    mount "${dst_rootfs}" "${rootfs_mnt}"

    rsync -a "${src_rootfs}"/ "${rootfs_mnt}"/
    for dir in dev proc run sys var; do mkdir -p "${rootfs_mnt}/${dir}"; done

    # rsync -a --keep-dirlinks --ignore-existing /usr/src/app/overlay/ "${rootfs_mnt}/"

    # alpine already has /sbin/init that we should replace
    rsync -a --keep-dirlinks /usr/src/app/overlay/ "${rootfs_mnt}/"

    resolve_init_vars "${rootfs_mnt}/sbin/init"

    write_ctr_secrets "${rootfs_mnt}/var/secrets"

    umount "${rootfs_mnt}"

    chown firecracker:firecracker "${dst_rootfs}"
}

populate_datafs() {

    local dst_datafs="${1}"

    mkdir -p "$(dirname "${dst_datafs}")"

    if [ ! -f "${dst_datafs}" ]; then
        echo "Populating datafs..."
        truncate -s "${DATAFS_SIZE}" "${dst_datafs}"
        mkfs.ext4 -q "${dst_datafs}"
        chown firecracker:firecracker "${dst_datafs}"
    fi
}

prepare_config() {
    echo "Preparing config..."

    local src_config="${1}"
    local dst_config="${2}"

    envsubst <"${src_config}" >"${dst_config}"

    jq ".\"boot-source\".boot_args = \"${KERNEL_BOOT_ARGS}\"" "${dst_config}" >"${dst_config}".tmp
    mv "${dst_config}".tmp "${dst_config}"

    jq ".\"machine-config\".vcpu_count = ${VCPU_COUNT}" "${dst_config}" >"${dst_config}".tmp
    mv "${dst_config}".tmp "${dst_config}"

    jq ".\"machine-config\".mem_size_mib = ${MEM_SIZE_MIB}" "${dst_config}" >"${dst_config}".tmp
    mv "${dst_config}".tmp "${dst_config}"

    jq ".\"network-interfaces\"[0].iface_id = \"${iface_id}\"" "${dst_config}" >"${dst_config}".tmp
    mv "${dst_config}".tmp "${dst_config}"

    jq ".\"network-interfaces\"[0].guest_mac = \"${guest_mac}\"" "${dst_config}" >"${dst_config}".tmp
    mv "${dst_config}".tmp "${dst_config}"

    jq ".\"network-interfaces\"[0].host_dev_name = \"${tap_dev}\"" "${dst_config}" >"${dst_config}".tmp
    mv "${dst_config}".tmp "${dst_config}"

    # jq . "${dst_config}"
}

create_tap_device() {
    echo "Creating ${tap_dev} device..."

    # delete existing tap device
    ip link del "${tap_dev}" 2>/dev/null || true

    # create tap device
    # ip tuntap add dev "${tap_dev}" mode tap user firecracker
    ip tuntap add dev "${tap_dev}" mode tap
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

    # delete rules matching comment
    iptables-legacy-save | grep -v "comment ${tap_dev}" | iptables-legacy-restore

    # create rules
    iptables-legacy -t nat -A POSTROUTING -o "${iface_id}" -j MASQUERADE -m comment --comment "${tap_dev}"
    iptables-legacy -I FORWARD 1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT -m comment --comment "${tap_dev}"
    iptables-legacy -I FORWARD 1 -i "${tap_dev}" -o "${iface_id}" -j ACCEPT -m comment --comment "${tap_dev}"

    # iptables-legacy-save | grep 'comment ctr-jailer'

    # iptables-legacy -L -n -v
    # iptables-legacy -t nat -L -n -v
}

create_logs_fifo() {

    local fifo="${1}"
    local out="${2}"

    mkdir -p "$(dirname "${fifo}")"

    rm -f "${fifo}"

    # Create a named pipe
    mkfifo "${fifo}"

    # Redirect the output of the named pipe to /dev/stdout
    cat "${fifo}" >"${out}" &

    chown firecracker:firecracker "${fifo}"
}

cleanup() {

    echo "Cleaning up..."

    ip link del "${tap_dev}" 2>/dev/null || true

    # delete rules matching comment
    iptables-legacy-save | grep -v "comment ${tap_dev}" | iptables-legacy-restore
}

trap cleanup EXIT

remount_tmpfs_exec "$(dirname "${chroot_base}")"

create_tap_device
enable_forwarding
apply_routing

echo "Creating jailer chroot..."
mkdir -p "${chroot_dir}"
mount --bind /jail "${chroot_dir}"

populate_rootfs /usr/src/app/rootfs "${chroot_dir}"/boot/rootfs.ext4
populate_datafs "${chroot_dir}"/data/datafs.ext4
prepare_config /usr/src/app/config.json "${chroot_dir}"/config.json
create_logs_fifo "${chroot_dir}"/logs.fifo /dev/stdout

# /usr/local/bin/firecracker --help

echo "Starting firecracker via jailer..."
# https://github.com/firecracker-microvm/firecracker/blob/main/docs/jailer.md
/usr/local/bin/jailer --id "${id}" \
    --exec-file /usr/local/bin/firecracker \
    --chroot-base-dir "${chroot_base}" \
    --uid "$(id -u firecracker)" \
    --gid "$(id -g firecracker)" \
    -- \
    --api-sock /run/firecracker.socket \
    --config-file config.json \
    --log-path logs.fifo
