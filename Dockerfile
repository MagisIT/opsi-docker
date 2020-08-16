############################################################
# Defines a Dockerfile running OPSI-Server
# 08.08.2020
# by Sören Busse @ Magis IT
############################################################

# Use debian stretch latest image
FROM debian:buster

# Install required basis packages
RUN apt-get update && apt-get -y install supervisor rsyslog netcat wget host pigz samba samba-common smbclient cifs-utils openssh-server debconf-utils cpio ssh passwd patch winbind libnss-winbind libpam-winbind cron acl

# Gucci version
ARG GUCCI_VERSION=1.2.2

# Install gucci templating
RUN wget -q https://github.com/noqcks/gucci/releases/download/${GUCCI_VERSION}/gucci-v${GUCCI_VERSION}-linux-amd64 && \
    chmod +x gucci-v${GUCCI_VERSION}-linux-amd64 && \
    mv gucci-v${GUCCI_VERSION}-linux-amd64 /usr/local/bin/gucci

# Add OPSI-sources to apt
RUN echo "deb http://download.opensuse.org/repositories/home:/uibmz:/opsi:/4.1:/stable/Debian_10/ /" > /etc/apt/sources.list.d/opsi.list

# Add key for repository
RUN wget -nv https://download.opensuse.org/repositories/home:uibmz:opsi:4.1:stable/Debian_10/Release.key -O Release.key && apt-key add - < Release.key && rm Release.key

# Backend should be created manually on init
RUN touch /tmp/.opsi.no_backend_configuration

# Predefined values for opsi installation using debconf
# This is only a dummy certificate and will be replaced during the docker startup
RUN echo "opsiconfd opsiconfd/cert_locality string Internet" | debconf-set-selections && \
	echo "opsiconfd opsiconfd/cert_organization string example.com" | debconf-set-selections && \
	echo "opsiconfd opsiconfd/cert_commonname string example.com" | debconf-set-selections && \
	echo "opsiconfd opsiconfd/cert_country string DE" | debconf-set-selections && \
	echo "opsiconfd opsiconfd/cert_state string NDS" | debconf-set-selections && \
	echo "opsiconfd opsiconfd/cert_unit string" | debconf-set-selections && \
	echo "opsiconfd opsiconfd/cert_email string" | debconf-set-selections

# Install opsi packages
RUN apt-get update && apt-get -y install opsi-tftpd-hpa opsi-server opsi-configed opsi-windows-support

# Move OPSI files to different directory to prevent overwrite from volumes
RUN mv /etc/opsi /etc/opsi-default && mv /var/lib/opsi /var/lib/opsi-default && mv /tftpboot /tftpboot-default && mv /etc/samba /etc/samba-default

# Allow ssh root access
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config

# Add scripts to image
COPY scripts /opt/

# Set permissions on bash scripts
RUN chmod +x /opt/*.sh

COPY files/patches /opt/
COPY files/templates /templates
COPY files/system/opsi-package-updater-cron /etc/cron.d/opsi-package-updater

# Install CronJob
RUN chmod 0644 /etc/cron.d/opsi-package-updater && crontab /etc/cron.d/opsi-package-updater

# Apply patch
# Solves an error because OPSI isn't allowing the Docker-IP to access the MySQL Server with the OPSI-User
# When running OPSI in docker the MySQL-Server is normally only rechable in the internal docker network
# so we allow any host (%) to connect with the opsi user
RUN patch /usr/lib/python2.7/dist-packages/OPSI/Util/Task/ConfigureBackend/MySQL.py < /opt/patch.mysql.installer

# Apply patch
# After certificate renew the opsi-setup script tries to restart the opsi services using systemd
# This obviously doesn't work so we add an unattended variable to disable this behaviour
RUN patch /usr/bin/opsi-setup < /opt/patch.opsi-setup

# Apply patch
# OPSI only retrieves the groups of a user from the /etc/group file, which prevents using Domain Groups in acl.conf
# This patch makes OPSI to retrieve the groups using the libc function getgrouplist which uses the nsswitch backend
RUN patch /usr/lib/python2.7/dist-packages/OPSI/Backend/BackendManager.py < /opt/patch.backendmanager

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
