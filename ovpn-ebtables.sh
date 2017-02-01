#!/bin/bash

# Debian binary might be under /sbin instead
EBTABLES=/usr/bin/ebtables

# Path to directory with whitelist files
RULEDIR="$(pwd)/rules.d"

# OpenVPN interface
# TODO, currently unused
#INTERFACE=tap0

delete_rules () {
    # Delete rules related to $1
    while read rule; do
        $EBTABLES ${rule/-A/-D}
    done <<< $($EBTABLES-save | grep -ie "-s $1" -e "-d $1")
}


add_rules () {
    addr=$1
    rulefile=$RULEDIR/$2

    if [[ -r $rulefile ]]; then
        # Allow listed IPs
        while read ip; do
            # Allow requests about $ip
            $EBTABLES -A OUTPUT -s $addr -p arp --arp-opcode request --arp-ip-dst $ip -j ACCEPT
            # Allow responses from $ip
            $EBTABLES -A INPUT -d $addr -p arp --arp-opcode reply --arp-ip-dst $ip -j ACCEPT
        done < $rulefile

        # Then, block everything else
        $EBTABLES -A OUTPUT -s $addr -p arp -j DROP
        $EBTABLES -A INPUT -d $addr -p arp -j DROP
    else
        # If no whitelist is defined, ACCEPT ALL
        $EBTABLES -A OUTPUT -s $addr -j ACCEPT
        $EBTABLES -A INPUT -d $addr -j ACCEPT
    fi
}


case $1 in
    add)
        add_rules $2 $3
        ;;

    delete)
        delete_rules $2
        ;;

    update)
        # TODO: Check what this scenario means
        return 2
        ;;
esac
