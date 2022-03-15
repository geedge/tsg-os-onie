#!/bin/sh

#  Copyright (C) 2013,2014,2016 Curt Brune <curt@cumulusnetworks.com>
#  Copyright (C) 2014 david_yang <david_yang@accton.com>
#  Copyright (C) 2013 Doron Tsur <doront@mellanox.com>
#
#  SPDX-License-Identifier:     GPL-2.0

PATH=/usr/bin:/usr/sbin:/bin:/sbin

. /lib/onie/functions

import_cmdline

arch_networking="/lib/onie/networking-${onie_switch_asic}"
platform_networking="/lib/onie/networking-platform"

[ -r "$arch_networking" ] && . "$arch_networking"
[ -r "$platform_networking" ] && . "$platform_networking"

config_ethmgmt() {
    onie_env_array=$(cat /mnt/onie-boot/grub/grubenv | grep ONIE_NETWORK_ | grep -v "\#")
    onie_env_num=$(cat /mnt/onie-boot/grub/grubenv | grep ONIE_NETWORK_ | grep -v "\#" | wc -l)

    if [ "$onie_env_num" == 0 ]; then
        log_info_msg "Please use onie-netcfg-set config ONIE network !!!"
        return 0
    fi

    for onie_env in $onie_env_array; do
        cmd_run export $onie_env
    done

    dump_env=$(env | grep ONIE_NETWORK | sort)
    log_console_msg "$dump_env"

    if [ -n "ONIE_NETWORK_BOND_SLAVES" ]; then
        cmd_run ifconfig bond0 down
        #cmd_run echo +bond0 >/sys/class/net/bonding_masters
        cmd_run echo active-backup >/sys/class/net/bond0/bonding/mode
        cmd_run echo 100 >/sys/class/net/bond0/bonding/miimon

        interface_array=$(echo $ONIE_NETWORK_BOND_SLAVES | tr ',' ' ')
        for eth in $interface_array; do
            cmd_run ifconfig $eth down
            cmd_run echo +$eth >/sys/class/net/bond0/bonding/slaves
            cmd_run ifconfig $eth up
        done
    fi

    if [ -n "ONIE_NETWORK_INTERFACE" ] || [ -n "ONIE_NETWORK_ADDRESS" ] || [ -n "ONIE_NETWORK_MASK" ]; then
        cmd_run ifconfig $ONIE_NETWORK_INTERFACE $ONIE_NETWORK_ADDRESS netmask $ONIE_NETWORK_MASK up
        log_console_msg "$ONIE_NETWORK_INTERFACE: Using static IP config: ip=$ONIE_NETWORK_ADDRESS"
    fi

    if [ -z "$ONIE_NETWORK_GATEWAY" ]; then
        cmd_run route add default gw $ONIE_NETWORK_GATEWAY
        log_console_msg "Add default gateway $ONIE_NETWORK_INTERFACE"
    fi

    return 0
}

if [ "$1" = "start" ]; then
    # Bring up the loopback interface
    cmd_run ip link set dev lo up

    # When starting the network at boot time configure the MAC
    # addresses for all the Ethernet management interfaces.
    intf_list=$(net_intf)
    intf_counter=0

    # Set MAC addr for all interfaces, but leave the interfaces down.
    base_mac=$(onie-sysinfo -e)
    for intf in $intf_list; do
        if [ "$onie_skip_ethmgmt_macs" = "no" ]; then
            mac="$(mac_add $base_mac $intf_counter)"
            if [ $? -eq 0 ]; then
                cmd_run ifconfig $intf down
                cmd_run ifconfig $intf hw ether $mac down
            else
                log_failure_msg "Unable to configure MAC address for $intf"
            fi
        else
            mac="$(cat /sys/class/net/${intf}/address)"
        fi
        log_info_msg "Using $intf MAC address: $mac"
        intf_counter=$(($intf_counter + 1))
    done

    config_ethmgmt
fi
