# Creates an OPSI-User
# $1: Username
# $2: Password
function addOpsiUser {
    if [[ -z $1 || -z $2 ]]; then
        printError "Wrong parameters for addOpsiUser Function. addOpsiUser <USERNAME> <PASSWORD>"
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

# Set the root password for this container
# $1: Password
function setRootPassword {
    echo "root:${1}" | chpasswd

    if [[ $? != 0 ]]; then
        printError "Cannot set root password"
        exit 1
    fi
}

# Sets the FQDN for this container
# $1: Hostname
# $2: Domain
# $3: Host IP
function setFQDN {
    if [[ -z $1 || -z $2 || -z $3 ]]; then
        printError "Cannot set FQDN. Missing parameter Hostname, Domain or Host IP"
        exit 1
    fi

    # Overwrite hosts file
    echo "127.0.0.1     localhost" > /etc/hosts
    echo "::1	localhost ip6-localhost ip6-loopback" >> /etc/hosts
    echo "${3} ${1,,}.${2,,} ${1,,}" >> /etc/hosts
}

# Validates the environment variables
# $@: The required environment variables
function validateEnvironment {
    for required_env in "$@"; do
    if [[ -z "${!required_env}" ]]; then
        printError "Missing environment variable ${required_env}"
        exit 1
    fi
    done
}

# Waits until the server is rechable
# $1: Hostname
# $2: Port
function waitUntilRechable {
    until nc -z ${1} ${2}
    do
        printInfo "Waiting for ${1} on port ${2} to become rechable…"
        sleep 1
    done
}

# Reads a secret from a file or an environment
# $1: Value of environment name for file
# $2: Value of environment name for variable
# $3: Name of environment variable for error reporting
function getSecretFromFileOrEnvironment {
  secret_file="${1}"
  secret_variable="${2}"
  secret_name="${3}"

  secret_result=""

  # Try to read secret from file if set
  if [[ -n "${secret_file}" ]]; then
    secret_result=$(cat "${secret_file}")

    if [[ -z "${secret_result}" ]]; then
      printError "Error while reading Secret from file ${secret_file}"
      exit 1
    fi

  else
    # Check if secret is set
    if [[ -z "${secret_variable}" ]]; then
      printError "Missing ${secret_name} environment variable"
      exit 1
    fi

    secret_result="${secret_variable}"
  fi

  echo "${secret_result}"
}

# $1: Repository Name
# $2: Should the repository be disabled
function disableActiveAndAutoInstallOfRepository {
  if [[ "${2}" == "true" ]]; then
    sed -i "s/active = .*/active = false/g" "/etc/opsi/package-updater.repos.d/${1}.repo"
    sed -i "s/autoInstall = .*/autoInstall = false/g" "/etc/opsi/package-updater.repos.d/${1}.repo" 
  elif [[ "${2}" == "false" ]]; then
    sed -i "s/active = .*/active = true/g" "/etc/opsi/package-updater.repos.d/${1}.repo"
    sed -i "s/autoInstall = .*/autoInstall = true/g" "/etc/opsi/package-updater.repos.d/${1}.repo"
  else
    printError "Cannot parse ${2} to true/false for repository ${1}"
  fi
}

# $1: Repository Name
# $2: Repository URL
function addRepository {
  echo "HI"
}

function checkDcState {
  nc -w 1 -z $1 389
  echo $?
}

# Prints an informational message
# $1: Message
function printInfo {
    echo -e "\e[34m[INFO] $(date): ${1}\e[39m"
}

# Prints an error message
# $1: Message
function printError {
    echo -e "\e[31m[ERROR] $(date): ${1}\e[39m"
}
