#!/bin/bash

# Add dependencies
source "$(dirname "$0")/shared-functions.sh"

# This files configures pam.d, which requires a running winbind to lookup it's sid
if [[ -z $1 ]]; then
    printError "RUNTIME-INIT: Invalid arguments: ./${0} <OPSI AD GROUP>"
    exit 1
fi

# Wait until winbindd becomes rechable. This makes sure that we're able to get information from winbind
try=0
while ! /usr/bin/wbinfo --ping-dc > /dev/null 2>&1; do
    printInfo "RUNTIME-INIT: Waiting for Winbindd to come up and connect to Domain Controller"
    sleep 1

    if [[ $try == 10 ]]; then
        printError "RUNTIME-INIT: Cannot reach Winbindd. Giving up…"
        exit 1
    fi

    try=$((try+1))
done

# Set SID of the OPSI AD Group to PAM.d
group_sid=$(wbinfo -n "${1}" | cut -f1 -d ' ')

if [[ -z $group_sid ]]; then
    printError "RUNTIME-INIT: Cannot get SID from group. Empty result. Exiting…"
    exit 1
fi

printInfo "RUNTIME-INIT: Update common-auth PAM configuration"
sed -i "/.*pam_winbind.so krb5_auth/ s/$/ require_membership_of=${group_sid}/" /etc/pam.d/common-auth

# OPSI set rights. The scripts needs to know the AD OPSI GROUP, which is only possible during runtime
printInfo "RUNTIME-INIT: Set correct file permissions to OPSI directories"
opsi-set-rights

# Two things are infinite: the universe and human stupidity; and I'm not sure about the universe.
sleep infinity