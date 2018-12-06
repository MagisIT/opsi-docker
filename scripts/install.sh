#!/bin/bash
####################################################################
# Installs the OPSI-Server in Docker
# Calling this Skript twice the current OPSI-Config will be lost
####################################################################

# Add dependencies
source "$(dirname "$0")/shared-functions.sh"

# Check if all environment variables for certificate creation are set?
if [[ -z $CERT_LOCALITY || -z $CERT_ORGANIZATION || -z $CERT_COUNTRY || -z $CERT_STATE ]]; then
    echo "Missing required CERT-environment variables: CERT_LOCALITY, CERT_ORGANIZATION, CERT_COUNTRY, CERT_STATE"
    exit 1
fi

# MYSQL is required.
if [[ -z $MYSQL_USER || -z $MYSQL_PASSWORD || -z $MYSQL_DATABASE || -z $MYSQL_HOST ]]; then
    echo "Missing required MYSQL-environment variables: MYSQL_USER, MYSQL_ROOT_PASSWORD, MYSQL_DATABASE, MYSQL_HOST"
    exit 1
fi

# The Container requires the external IP on which the server will be rechable.
# This must be specified during setup so that the right IP is written to the depot config
# With the default behaviour OPSI-Setup is writing the container internal IP to the config which isn't rechable from outside
if [[ -z $EXTERNAL_IP || -z $DOMAIN ]]; then
    echo "Missing required EXTERNAL_IP or DOMAIN environment variable"
    exit 1
fi

# Is OPSI already installed
if [[ -n "$(ls -A /etc/opsi/)" ]]; then
    echo "OPSI is already installed. Please manually remove the contents from the volume if you really want to reinstall opsi"
    exit 1
fi

# Write-Back default OPSI-Files from docker-image installation
mv /etc/opsi-default/* /etc/opsi/
mv /var/lib/opsi-default/* /var/lib/opsi
mv /tftpboot-default/* /tftpboot
mv /etc/samba-default/* /etc/samba/

# Set Hostname
setFqdn $(hostname) $DOMAIN $EXTERNAL_IP

# Add-OPSI user which automatically assign user to the right groups
echo "Add OPSI-user and add to group..."
addOpsiUser $OPSI_USER $OPSI_PASSWORD

# Configure MySQL
echo "Configure Mysql..."
opsi-setup --configure-mysql --unattended="{\"dbAdminPass\": \"${MYSQL_PASSWORD}\", \"dbAdminUser\": \"${MYSQL_USER}\", \"database\": \"${MYSQL_DATABASE}\", \"address\": \"${MYSQL_HOST}\"}"

# Was there any error during setup
if [[ $? != 0 ]]; then
    echo "Error while setting up the MYSQl-backend. Is your external MySQL Docker running and on the same network? See logs for more information."
    exit 1
fi

# Init configuration with external ip
echo "Running Config setup..."
opsi-setup --init-current-config --ip-address $EXTERNAL_IP

# Was there any error during config init
if [[ $? != 0 ]]; then
    echo "Error while init configuration. See logs for more information"
    exit 1
fi

# Set correct file permissions on OPSI directorys
echo "Set file permissions..."
opsi-setup --set-rights

# Was there any error during file permission change
if [[ $? != 0 ]]; then
    echo "Error while changing file permissions. See logs for more information"
    exit 1
fi

# Configure Samba
echo "Configure Samba..."
opsi-setup --auto-configure-samba

# Was there any error during configuring samba
if [[ $? != 0 ]]; then
    echo "Error while configuring samba. See logs for more information"
    exit 1
fi

# Create certificate
echo "Creating certificate..."
fqdn=$(hostname -f)
opsi-setup --renew-opsiconfd-cert --unattended="{\"country\": \"${CERT_COUNTRY}\", \"state\": \"${CERT_STATE}\", \"locality\": \"${CERT_LOCALITY}\", \"organization\": \"${CERT_ORGANIZATION}\", \"commonName\": \"${fqdn}\"}"

echo "We're ignoring the error above, because we have not systemd installed"
exit 0






