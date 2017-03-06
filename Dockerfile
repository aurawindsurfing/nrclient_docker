# NeoRouter Client (Free) Docker
#
# Running a NeoRouter client in Docker may be useful in embedded devices
# where the NeoRouter client will not install or run. This client was 
# built on a Synology but should be applicable to many environments.
#
# Host networking is strongly recommended to avoid duplicate NeoRouter HW IDs 
# in the NeoRouter network. Duplicate HW IDs cause the NeoRouter network to 
# tread the clients as the same and will give them the same IP address.
#
# Elevated Permissions (--priviledged) are required in order to create and
# manager the tap device used by NeoRouter.
#
# Environment variables expected:
# NR_DOMAIN      = name of the NeoRouter domain to connect to
# NR_USER        = username with permissions to connect to the domain
# NR_USER_PASSWD = password for NR_USER

# Start from ubuntu 16.04 LTS
FROM ubuntu:16.04

MAINTAINER Adam Schultz <adam.schultz@live.com>

# Set environment variables for aptitute package management
ENV DEBIAN_FRONTEND="noninteractive" HOME="/root" LC_ALL="C.UTF-8" LANG="en_US.UTF-8" LANGUAGE="en_US.UTF-8"

# Avoid docker bug
RUN ln -s -f /bin/true /usr/bin/chfn

# Install required tools
RUN apt-get -q update && apt-get install -qy wget module-init-tools iproute2 arping && \
    apt-get -y clean && apt-get -y autoclean && apt-get -y autoremove

# Install debug utilities
#RUN apt-get -q update && apt-get install -qy nano less net-tools inetutils-ping traceroute tcpdump \
#    apt-get -y clean && apt-get -y autoclean && apt-get -y autoremove

# Add startup script
ADD nrclient.sh /
RUN chmod +x /nrclient.sh

# Add persistent confiuration volume
VOLUME ["/config"]

# Call startup script on run
CMD ["/nrclient.sh"]
