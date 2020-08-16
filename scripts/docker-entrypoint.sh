#!/bin/bash
####################################################################
# Docker-Entry script for opsi-docker
####################################################################

# Exit if any error occours
set -e

# Add dependencies
source "$(dirname "$0")/shared-functions.sh"

# Functions
function initialize {
    # Write back default OPSI-files from docker-image installation
    printInfo "Write back opsi files from docker image…"
    mv /etc/opsi-default/* /etc/opsi/
    mv /var/lib/opsi-default/* /var/lib/opsi
    mv /tftpboot-default/* /tftpboot
    mv /etc/samba-default/* /etc/samba/

    # Configure MySQL
    printInfo "Runnig opsi-setup: Configure MySQL database…"
    opsi-setup --configure-mysql --unattended="{\"dbAdminPass\": \"${MYSQL_PASSWORD}\", \"dbAdminUser\": \"${MYSQL_USER}\", \"database\": \"${MYSQL_DATABASE}\", \"address\": \"${MYSQL_HOST}\"}"

    # Was there any error during setup
    if [[ $? != 0 ]]; then
        printError "Error while setting up the MYSQl-backend. Is your external MySQL Docker running and on the same network? See logs for more information."
        exit 1
    fi

    # Create certificate
    printInfo "Running opsi-setup: Creating certificate…"

    opsi-setup --renew-opsiconfd-cert --unattended="{\"country\": \"${CERT_COUNTRY}\", \"state\": \"${CERT_STATE}\", \"locality\": \"${CERT_LOCALITY}\", \"organization\": \"${CERT_ORGANIZATION}\", \"commonName\": \"${FQDN}\", \"expires\": \"30\", \"disableRestart\": \"true\"}"

    # Was there any error during certificate generation
    if [[ $? != 0 ]]; then
        printError "Error while generating certificate. See logs for more information"
        exit 1
    fi
}

function initAdIntegration {
    # Validate environment and retrieve join password
    printInfo "Domain-Join: Validate environment variables"
    validateEnvironment "AD_DOMAIN" "AD_REALM" "AD_JOIN_USER" "AD_DOMAIN_CONTROLLER" "AD_OPSI_GROUP"
    AD_JOIN_PASSWORD=$(getSecretFromFileOrEnvironment "${AD_JOIN_PASSWORD_FILE}" "${AD_JOIN_PASSWORD}" "AD_JOIN_PASSWORD")

    # Export AD specifc environment variables for use in Gucci
    export AD_DOMAIN
    export AD_REALM
    export AD_JOIN_USER
    export AD_DOMAIN_CONTROLLER
    export AD_OPSI_GROUP
    export SAMBA_LISTEN_IP

    # Check if samba listen ip is set
    if [[ -z "${SAMBA_LISTEN_IP}" ]]; then
        SAMBA_LISTEN_IP="all"
    fi

    # Apply templates
    printInfo "Domain-Join: Applying template configuration files"
    if ! gucci /templates/smb.tpl > /etc/samba/smb.conf; then
        printError "Cannot apply template to smb.conf"
        exit 1
    fi

    if ! gucci /templates/supervisor.tpl > /etc/supervisor.conf; then
        printError "Cannot apply template to supervisor.conf"
        exit 1
    fi

    if ! gucci /templates/sudoers.tpl > /etc/sudoers; then
        printError "Cannot apply template to sudoers"
        exit 1
    fi

    # Apply template to OPSI acl.conf
    if ! gucci /templates/acl-ad.tpl > /etc/opsi/backendManager/acl.conf; then
        printError "Cannot apply acl active directory template to opsi/backendManager/acl.conf"
        exit 1
    fi

    # Append winbind to nsswitch
    sed -i '/^passwd:/ s/$/ winbind/' /etc/nsswitch.conf
    sed -i '/^group:/ s/$/ winbind/' /etc/nsswitch.conf

    # Modify opsi-set-rights to set group acls for our AD_OPSI_GROUP
    # This would allow access using samba to the opsi shares
    # Yeah, I know it's kind of hacky, so please forgive me ;)
    echo "setfacl -R -m g:\"${AD_OPSI_GROUP}\":rwx /var/lib/opsi" >> /usr/bin/opsi-set-rights
    echo "setfacl -R -m g:\"${AD_OPSI_GROUP}\":rwx /var/log/opsi" >> /usr/bin/opsi-set-rights

    # Wait until domain controller is rechable
    printInfo "Domain-Join: Wait until Domain Controller is rechable"
    while [[ $(checkDcState "${AD_DOMAIN_CONTROLLER}") == 1 ]]; do
        printInfo "Wait for DC to come up"
        sleep 1
    done

    printInfo "Domain-Join: Joining domain"
    if ! net ads join --no-dns-updates -U"${AD_JOIN_USER}"%"${AD_JOIN_PASSWORD}"; then
        printError "Error while joining the DC"
        exit 1
    fi

    printInfo "Domain-Join: Register DNS"
    if ! net ads dns register "$(hostname -f)" "${HOST_IP}" -U"${AD_JOIN_USER}"%"${AD_JOIN_PASSWORD}"; then
        printError "Error while register DNS"
        exit 1
    fi
}

# Validate Environment variables, which aren't secrets
validateEnvironment "MYSQL_USER" "MYSQL_DATABASE" "MYSQL_HOST"
validateEnvironment "CERT_LOCALITY" "CERT_ORGANIZATION" "CERT_COUNTRY" "CERT_STATE"
validateEnvironment "OPSI_USER"
validateEnvironment "HOST_IP" "DOMAIN"

# Check for password environenment variables/files
MYSQL_PASSWORD=$(getSecretFromFileOrEnvironment "${MYSQL_PASSWORD_FILE}" "${MYSQL_PASSWORD}" "MYSQL_PASSWORD")
OPSI_USER_PASSWORD=$(getSecretFromFileOrEnvironment "${OPSI_USER_PASSWORD_FILE}" "${OPSI_USER_PASSWORD}" "OPSI_USER_PASSWORD")
OPSI_PCPATCH_PASSWORD=$(getSecretFromFileOrEnvironment "${OPSI_PCPATCH_PASSWORD_FILE}" "${OPSI_PCPATCH_PASSWORD}" "OPSI_PCPATCH_PASSWORD")

# Export general environment variables for Gucci
export ENABLE_AD

# Global variables
FIRST_RUN="false"

# Wait for dependencies
printInfo "Wait for dependencies to come up…"
waitUntilRechable ${MYSQL_HOST} 3306

# Set FQDN for container
printInfo "Set FQDN to $(hostname).${DOMAIN}"
setFQDN "$(hostname)" "${DOMAIN}" "${HOST_IP}"
FQDN="$(hostname -f)"

# Initialize opsi if it doesn't exist already
if [[ -z "$(ls -A /var/lib/opsi/)" ]]; then
    printInfo "Initialize Opsi…"
    initialize
    FIRST_RUN="true"
fi

# Add-OPSI user which automatically assign user to the right groups
printInfo "Add OPSI-user and add to opsi group…"
addOpsiUser $OPSI_USER $OPSI_USER_PASSWORD

# Configure Samba
# Delete old configuration
rm /etc/samba/smb.conf
touch /etc/samba/smb.conf

# Enable Active Directory Authentication?
if [[ -n "${ENABLE_AD}" && "${ENABLE_AD}" == "true" ]]; then
    printInfo "Initialize Active Directory integration and join domain"
    initAdIntegration
fi

# Add samba configuration
printInfo "Running opsi-setup: Configure Samba fileserver…"
opsi-setup --auto-configure-samba

# Init configuration
printInfo "Running opsi-setup: Init opsi configuration"
opsi-setup --init-current-config --ip-address $HOST_IP

# Was there any error during config init
if [[ $? != 0 ]]; then
    printError "Error while init configuration. See logs for more information"
    exit 1
fi

# Replace IP with Hostname in Opsi Configurations
# Due to opsi limitations this can only be configured on the first run of this opsi-container
if [[ -n "${OPSI_USE_HOSTNAME}" && "${OPSI_USE_HOSTNAME}" == "true" && "${FIRST_RUN}" == "true" ]]; then
    printInfo "Replace ip with hostname in opsi configuration"

    sed -i "s/${HOST_IP}/${FQDN}/g" "/var/lib/opsi/config/depots/${FQDN}.ini"
    sed -i "s/ipaddress = ${FQDN}/ipaddress = ${HOST_IP}/g" "/var/lib/opsi/config/depots/${FQDN}.ini"
    sed -i "s/${HOST_IP}/${FQDN}/g" "/var/lib/opsi/config/config.ini"
fi

# Was there any error during file permission change
if [[ $? != 0 ]]; then
    printError "Error while changing file permissopsi-setup --init-current-config ions. See logs for more information"
    exit 1
fi

# Was there any error during configuring samba
if [[ $? != 0 ]]; then
    printError "Error while configuring samba. See logs for more information"
    exit 1
fi

# Set PCPatchPassword
printInfo "Running opsi-setup: Setting pcpatch password…"
opsi-admin -d task setPcpatchPassword "${OPSI_PCPATCH_PASSWORD}"

# Was there any error during setting pcpatch password
if [[ $? != 0 ]]; then
    printError "Error while setting pcpatch password. See logs for more information"
    exit 1
fi

# Disable default OPSI repositories if requested
if [[ -n "${DISABLE_UIB_WINDOWS_REPOSITORY}" ]]; then
    disableActiveAndAutoInstallOfRepository "uib-windows" "${DISABLE_UIB_WINDOWS_REPOSITORY}"
fi

if [[ -n "${DISABLE_UIB_LINUX_REPOSITORY}" ]]; then
    disableActiveAndAutoInstallOfRepository "uib-linux" "${DISABLE_UIB_LINUX_REPOSITORY}"
fi

if [[ -n "${DISABLE_UIB_LOCAL_IMAGE_REPOSITORY}" ]]; then
    disableActiveAndAutoInstallOfRepository "uib-local_image" "${DISABLE_UIB_LOCAL_IMAGE_REPOSITORY}"
fi

printInfo "Installing OPSI package updates"
if [[ -n "${SKIP_PACKAGE_UPDATE_ON_START}" && "${SKIP_PACKAGE_UPDATE_ON_START}" == "true" ]]; then
    printInfo "Skippinng OPSI Package Update…"
else
    /usr/bin/opsi-package-updater -v update
fi

# Start OPSI
printInfo "Starting Opsi…"
exec supervisord -c /etc/supervisor.conf



