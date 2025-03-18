#!/bin/vbash

if [ "$(id -g -n)" != 'vyattacfg' ] ; then
    exec sg vyattacfg -c "/bin/vbash $(readlink -f $0) $1 $2"
fi

# Use FD 19 to capture the debug stream caused by "set -x":
exec 19>/tmp/failover.log

# Tell bash about it  (there's nothing special about 19, its arbitrary)
export BASH_XTRACEFD=19

set -x

OLD_GW="$1"
NEW_GW="$2"

set +x

source /opt/vyatta/etc/functions/script-template

configure

if [ ! -z "$NEW_GW" ]; then
    delete protocols failover route 0.0.0.0/0

    set protocols failover route 0.0.0.0/0 next-hop $NEW_GW check target '1.1.1.1'
    set protocols failover route 0.0.0.0/0 next-hop $NEW_GW check target '1.0.0.1'
    set protocols failover route 0.0.0.0/0 next-hop $NEW_GW check timeout '5'
    set protocols failover route 0.0.0.0/0 next-hop $NEW_GW check type 'icmp'
    set protocols failover route 0.0.0.0/0 next-hop $NEW_GW interface 'eth1'
    set protocols failover route 0.0.0.0/0 next-hop $NEW_GW metric '10'

    delete protocols static route 1.1.1.1/32
    delete protocols static route 1.0.0.1/32
    if [ ! -z "$OLD_GW" ]; then
        delete protocols static route $OLD_GW/32
    fi

    set protocols static route $NEW_GW/32 interface eth1
    set protocols static route 1.1.1.1/32 next-hop $NEW_GW interface 'eth1'
    set protocols static route 1.0.0.1/32 next-hop $NEW_GW interface 'eth1'
fi

commit
exit
