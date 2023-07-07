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
    base_option_array=$(cat /mnt/onie-boot/grub/grubenv | grep onie_network_option_ | grep -v "\#" | grep -v "onie_network_option_bond_")
    bond_option_array=$(cat /mnt/onie-boot/grub/grubenv | grep onie_network_option_bond_ | grep -v "\#")
    bonding_masters=$(cat /mnt/onie-boot/grub/grubenv | grep onie_network_option_bond_bonding_masters | grep -v "\#")

    for base_args in $base_option_array; do
        cmd_run export $base_args
    done

    env | sort

    if [ -n "$bonding_masters" ]; then
        bonding_masters_value=$(echo $bonding_masters | grep onie_network_option_bond_ | awk -F '=' '{print $2}')
        cmd_run ifconfig $bonding_masters_value down

        for bond_args in $bond_option_array; do

            if [ "$bond_args" = "$bonding_masters" ]; then
                continue
            fi

            option_name=$(echo $bond_args | grep onie_network_option_bond_ | awk -F '=' '{print $1}' | awk -F "onie_network_option_bond_" '{print $2}' | tr 'A-Z' 'a-z')
            option_value=$(echo $bond_args | grep onie_network_option_bond_ | awk -F '=' '{print $2}')

            echo "Bond Param: $option_name, $option_value"
            
            if [ -n "$option_name" ] || [ -n "$option_value" ]; then

                if [ "$option_name" = "active_slave" ] || [ "$option_name" = "slave" ]; then
                    eth=$(echo $option_value | tr '+' ' ')
                    cmd_run ifconfig $eth down
                fi

                cmd_run echo $option_value >/sys/class/net/bond0/bonding/$option_name
                echo "echo $option_value >/sys/class/net/bond0/bonding/$option_name"
                log_console_msg "echo $option_value >/sys/class/net/bond0/bonding/$option_name"

                if [ "$option_name" = "active_slave" ] || [ "$option_name" = "slave" ]; then
                    eth=$(echo $option_value | tr '+' ' ')
                    cmd_run ifconfig $eth up
                fi

            fi
        done
    fi

    if [ -n "$onie_network_option_interface" ] && [ -n "$onie_network_option_address" ] && [ -n "$onie_network_option_netmask" ]; then
        cmd_run ifconfig $onie_network_option_interface $onie_network_option_address netmask $onie_network_option_netmask up
        log_console_msg "$onie_network_option_interface: Using static IP config: ip=$onie_network_option_address, netmask=$onie_network_option_netmask"
    fi

    if [ -n "$onie_network_option_gateway" ]; then
        cmd_run route add default gw $onie_network_option_gateway
        log_console_msg "Add default gateway $onie_network_option_gateway"
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
