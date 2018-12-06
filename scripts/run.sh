#!/bin/bash
#######################
# Runs an OPSI-Server
#######################

# Fetch the signal from docker
function stop() {
	echo "Received SIGTERM. Stopping $SERVICE_NAME..."

	PIDFILES=("/var/run/samba/smbd.pid" "/var/run/samba/nmbd.pid" "/var/run/opsiconfd/opsiconfd.pid" "/var/run/tftpd.pid")

    FAILED=0

	for pidfile in "${PIDFILES[@]}"
	do
	    for i in {0..2}
	    do
		    echo "Try: $i"

		    PID=$(cat $pidfile)
		    echo "Found $PID of $pidfile"

		    kill -SIGTERM $PID
		    RET=$?

		    if [ $RET -eq 0 ]; then
			    echo "$pidfile successfully quit"
			    break
		    else
			    echo "$pidfile was't stopped. Get kill exit code: $RET"
			    echo "Try again..."
			    if [ $i -eq 2 ]; then
			        echo "Failed to stop $pidfile"
                    FAILED=$((FAILED+1))
			    fi
		    fi
	    done
	done

	if [ $FAILED -eq 0 ]; then
	    echo "Stopped OPSI successfully"
	    exit 0;
	else
	    echo "$FAILED services couldn't be stopped gracefully"
	    exit 1;
	fi
}

# Add dependencies
source "$(dirname "$0")/shared-functions.sh"

# The Container requires the external IP on which the server will be rechable.
# This must be specified during setup so that the right IP is written to the depot config
# With the default behaviour OPSI-Setup is writing the container internal IP to the config which isn't rechable from outside
if [[ -z $EXTERNAL_IP || -z $DOMAIN ]]; then
    echo "Missing required EXTERNAL_IP or DOMAIN environment variable"
    exit 1
fi

# Set Hostname
setFqdn $(hostname) $DOMAIN $EXTERNAL_IP

# Add-OPSI user which automatically assign user to the right groups
echo "Add OPSI-user and add to group..."
addOpsiUser $OPSI_USER $OPSI_PASSWORD

# Set rights
echo "Set file permissions..."
opsi-setup --set-rights

# Add graceful stop on docker stop
trap stop SIGTERM SIGINT

# Starting software
echo "Starting smbd..."
/usr/sbin/smbd &

echo "Starting nmbd..."
/usr/sbin/nmbd &

echo "Starting OPSI-Confd..."
/usr/bin/opsiconfd &

echo "Starting TFTPD-Server..."
/usr/sbin/in.tftpd -v --ipv4 --listen --address :69 --secure /tftpboot/ &
echo $(pgrep tftpd) > /var/run/tftpd.pid

# Bash should continue
while true;
do
    sleep 10
done

