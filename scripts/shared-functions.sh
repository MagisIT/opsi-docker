# Creates an OPSI-User
# $1: Username
# $2: Password
function addOpsiUser {
    if [[ -z $1 || -z $2 ]]; then
        echo "Wrong parameters for addOpsiUser Function. addOpsiUser <USERNAME> <PASSWORD>"
        exit 1
    fi

    username=$1
    password=$2

    # Create OPSI-User
    useradd -m -s /bin/bash $username

   # Set password for this user
    echo "${username}:${password}" | chpasswd

    # Set Samba Password
    printf "${password}\n${password}\n" | smbpasswd -a -s ${username}

    # Add User to Groups
    usermod -aG opsiadmin $username
    usermod -aG pcpatch $username
}

# Sets the FQDN to the container
# $1: Hostname
# $2: Domain
# $3: External IP
function setFqdn {
    if [[ -z $1 || -z $2 || -z $3 ]]; then
        echo "Cannot set FQDN. Missing parameter Hostname, Domain or External IP"
        exit 1
    fi

    # Overwrite hosts file
    echo "${3} ${1}.${2} ${1}" > /etc/hosts
}
