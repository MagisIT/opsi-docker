############################################################
# Defines a Dockerfile running OPSI-Server
# 29.11.2018
# by Sören Busse @ magis.school
#
# INFO: You've to set the hostname with docker-compose as
# descriped in the README
############################################################

# Use debian stretch latest image
FROM debian:stretch

# Install required basis packages
RUN apt-get update && apt-get -y install wget host pigz samba samba-common smbclient cifs-utils debconf-utils cpio ssh passwd patch

# Add OPSI-sources to apt
RUN echo "deb http://download.opensuse.org/repositories/home:/uibmz:/opsi:/4.1:/stable/Debian_9.0/ /" > /etc/apt/sources.list.d/opsi.list

# Add key for repository
RUN wget -nv https://download.opensuse.org/repositories/home:uibmz:opsi:4.1:stable/Debian_9.0/Release.key -O Release.key && apt-key add - < Release.key && rm Release.key

# Backend should be created manually on init
RUN touch /tmp/.opsi.no_backend_configuration

# Predefined values for opsi installation using debconf
# This is only a dummy certificate and will be replaced during the docker startup
RUN echo "opsiconfd opsiconfd/cert_locality string Internet" | debconf-set-selections && \
	echo "opsiconfd opsiconfd/cert_organization string example.com" | debconf-set-selections && \
	echo "opsiconfd opsiconfd/cert_commonname string test-schule.de" | debconf-set-selections && \
	echo "opsiconfd opsiconfd/cert_country string DE" | debconf-set-selections && \
	echo "opsiconfd opsiconfd/cert_state string NDS" | debconf-set-selections && \
	echo "opsiconfd opsiconfd/cert_unit string" | debconf-set-selections && \
	echo "opsiconfd opsiconfd/cert_email string" | debconf-set-selections

# Install opsi packages
RUN apt-get update && apt-get -y install opsi-tftpd-hpa opsi-server opsi-configed opsi-windows-support

# Move OPSI files to different directory to prevent overwrite from volumes
RUN mv /etc/opsi /etc/opsi-default && mv /var/lib/opsi /var/lib/opsi-default && mv /tftpboot /tftpboot-default && mv /etc/samba /etc/samba-default

# Add scripts to image
COPY scripts/install.sh scripts/run.sh /opt/
COPY scripts/shared-functions.sh /opt/shared-functions.sh

# Set permissions on bash scripts
RUN chmod +x /opt/install.sh && chmod +x /opt/run.sh

COPY files/patch.mysql.installer /opt/patch.mysql.installer

# Apply Patch
# Solves an error because OPSI isn't allowing the Docker-IP to access the MySQL Server with the OPSI-User
# When running OPSI in docker the MySQL-Server is normally only rechable in the internal docker network
# so we allow any host (%) to connect with the opsi user
RUN patch /usr/lib/python2.7/dist-packages/OPSI/Util/Task/ConfigureBackend/MySQL.py < /opt/patch.mysql.installer
