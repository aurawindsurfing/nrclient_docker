#!/bin/bash
#nrclient start script
#written by Adam Schultz <adam.schultz@live.com>

# Check environment variables
if [ -z "$NR_DOMAIN" ] ; then
	echo "No domain set"
	exit 1
fi
if [ -z "$NR_USER" ] ; then
	echo "No user set"
	exit 1
fi
if [ -z "$NR_USER_PASSWD" ] ; then
	echo "No user password set"
	exit 1
fi

# Set hostname if desired
if [ ! -z "$HOSTNAME" ] ; then
        if [ "$HOSTNAME" != $(hostname) ] ; then
                echo "$HOSTNAME" > /etc/hostname
                /bin/hostname "$HOSTNAME"
        fi
fi

# Get and install the NeoRouter client
if [ ! -f /usr/bin/nrservice ] ; then 
	wget -q http://download.neorouter.com/Downloads/NRPro/Update_2.6.2.5020/Linux/Ubuntu/nrclient-2.6.2.5020-pro-ubuntu-amd64.deb -O /tmp/neorouter.deb && \
		dpkg -i /tmp/neorouter.deb && rm -f /tmp/neorouter.deb
fi


# Create tun node if necessary
if [ ! -c /dev/net/tun ] ; then
        if [ ! -d /dev/net ] ; then
                mkdir -m 755 /dev/net
        fi
        mknod /dev/net/tun c 10 200
	chmod 666 /dev/net/tun
fi

# Install the tun module if necessary
if ( !(lsmod | grep -q "^tun\s") ); then
        insmod /lib/modules/tun.ko
fi

# Create the nrtap interface
tap=`/sbin/ip tuntap | grep nrtap`
if [ ! -z "$tap" ] ; then
        type=`echo $tap | sed 's/.*nrtap:\s*//'`
        if [ "$type" != "tap" ] ; then
                /sbin/ip tuntap del dev nrtap mode tun
        else
		/sbin/ip tuntap del dev nrtap mode tap
	fi
fi
/sbin/ip tuntap add dev nrtap mode tap

# Start nrservice
/usr/bin/nrservice -dbroot /config >/dev/null &
PID=$!

NETWORK=
IF_IP=
IF_MASK=

# Register interrupt handler
trap ctrl_c INT
function ctrl_c()
{
        kill -9 $PID
        if [ ! -z "$NETWORK" ] ; then
                /sbin/ip route del $NETWORK/$IF_MASK dev nrtap
        fi
}

# Set nrservice to connect to the configured domain
/usr/bin/nrclientcmd -d "$NR_DOMAIN" -u "$NR_USER" -p "$NR_USER_PASSWD" -register -dbroot /config

# Functions to manipulate IP strings
function ip2int()
{
	local a b c d
	{ IFS=. read a b c d; } <<< $1
	echo $(((((((a << 8) | b) << 8) | c) << 8) | d))
}

function int2ip()
{
	local ui32=$1; shift
	local ip n
	for n in 1 2 3 4; do
		ip=$((ui32 & 0xff))${ip:+.}$ip
		ui32=$((ui32 >> 8))
	done
	echo $ip
}

function network()
{
	local addr=$(ip2int $1); shift
	local mask=$((0xffffffff << (32 -$1))); shift
	int2ip $((addr & mask))
}

# Get the nrtap interface address
IFADDR=`/sbin/ip addr show dev nrtap | grep 'inet ' | cut -d ' ' -f6`
while [ -z $IFADDR ]
do
	echo "No interface address detected... Retrying in 1 second."
	sleep 1
	IFADDR=`/sbin/ip addr show dev nrtap | grep 'inet ' | cut -d ' ' -f6`
done

# Convert the addr to IP and Mask
IFS='/' read IF_IP IF_MASK <<< "$IFADDR"; shift
# Get the network address
NETWORK=$(network $IF_IP $IF_MASK)

# Add route for interface
/sbin/ip route add $NETWORK/$IF_MASK dev nrtap

# Wait forever (or until nrservice dies)
wait $PID
