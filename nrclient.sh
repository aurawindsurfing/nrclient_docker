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

# Get and install the NeoRouter client
if [ ! -f /usr/bin/nrservice ] ; then 
	wget -q http://download.neorouter.com/Downloads/NRFree/Update_2.3.1.4360/Linux/Ubuntu/nrclient-2.3.1.4360-free-ubuntu-amd64.deb -O /tmp/neorouter.deb && \
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

# Register interrupt handler
trap ctrl_c INT
function ctrl_c() {
	kill -9 $PID
}

# Set nrservice to connect to the configured domain
/usr/bin/nrclientcmd -d "$NR_DOMAIN" -u "$NR_USER" -p "$NR_USER_PASSWD" -register -dbroot /config

#Wait forever (or until nrservice dies)
wait $PID
