#!/bin/sh

# Copyright 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# This script assigns IP addresses to the existing
# virtual networking devices based on their MAC address.
# It is a simple solution on which Firecracker's integration
# tests are based. Each network device attached in a test will
# assign the next available MAC.
# The IP is obtained by converting the last 4 hexa groups of the MAC into decimals.

set -e

main() {
    for dev in /sys/class/net/*; do
        dev="$(basename "$dev")"
        case $dev in
        *lo) continue ;;
        esac
        mac_ip=$(
            ip link show dev "$dev" |
                awk '/link\/ether/ {print $2}' |
                awk -F: '{print $3$4$5$6}'
        )
        ip=$(printf "%d.%d.%d.%d" 0x${mac_ip:0:2} 0x${mac_ip:2:2} 0x${mac_ip:4:2} 0x${mac_ip:6:2})
        ip addr add "$ip/30" dev "$dev"
        ip link set "$dev" up
        ip route add default via "${ip%?}1" dev "$dev"
    done
}

main
