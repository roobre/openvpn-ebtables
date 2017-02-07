#!/bin/bash

# Debian binary might be under /sbin instead
EBTABLES=ebtables

# Path to directory with whitelist files
RULEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/whitelists"

# Bridge interface
BRIDGE=br0

delete_rules () {
    # ebtables-save is a prick and strips trailing zeroes
    compactedaddr=$(echo $1 | sed -E 's/0([0-9a-f])/\1/g')

    # Delete rules related to $1
    while read rule; do
        $EBTABLES ${rule/-A/-D}
    done < <($EBTABLES-save | grep -ie "$1" -ie "$compactedaddr")
}

add_rules () {
    macaddr=$1
    rulefile=$RULEDIR/$2

    if [[ -r $rulefile ]]; then
        # Allow listed IPs
        while read ip; do
            # Allow requests about $ip
            $EBTABLES -A FORWARD --logical-in $BRIDGE -s $macaddr -p arp --arp-opcode request --arp-ip-dst $ip -j ACCEPT
            # Allow responses from $ip
            $EBTABLES -A FORWARD --logical-out $BRIDGE -d $macaddr -p arp --arp-opcode reply --arp-ip-src $ip -j ACCEPT
            
            # Allow packets to $ip
            $EBTABLES -A FORWARD --logical-in $BRIDGE -s $macaddr -p ip --ip-dst $ip -j ACCEPT
            # Allow packets from $ip
            $EBTABLES -A FORWARD --logical-out $BRIDGE -d $macaddr -p ip --ip-src $ip -j ACCEPT
        done < $rulefile

        # Then, block everything else
        $EBTABLES -A FORWARD --logical-in $BRIDGE -s $macaddr -j DROP
        $EBTABLES -A FORWARD --logical-out $BRIDGE -d $macaddr -j DROP
        # Fix to block server too
        $EBTABLES -A OUTPUT --logical-out $BRIDGE -d $macaddr -j DROP
    else
        # If no whitelist is defined, ACCEPT ALL
        $EBTABLES -A FORWARD --logical-in $BRIDGE -s $macaddr -j ACCEPT
        $EBTABLES -A FORWARD --logical-out $BRIDGE -d $macaddr -j ACCEPT
    fi
}


#Strip zeroes

case $1 in
    add)
        echo "RFW: Adding rules for $3"
        add_rules $2 $3
        ;;

    delete)
        echo "RFW: Deleting rules for $3"
        delete_rules $2
        ;;

    update)
        # TODO: Check what this scenario means
        return 2
        ;;
esac
