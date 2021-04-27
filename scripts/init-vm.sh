#!/bin/bash

CONF=$1
ID=$2
source conf/${CONF}

function SSH_KEY_MANAGEMENT {
# Create an SSH key for root if one does not already exist

if [ ! -f /root/.ssh/id_rsa ]; then
	ssh-keygen -t rsa -b 2048 -N "" -f /root/.ssh/id_rsa
fi

# If an SSH key exists for this VM (from a previous deploy) remove it

echo -e "## Cleaning up known_hosts ##\n"

if [ -f /root/.ssh/known_hosts ]; then
	ssh-keygen -R ${NAME}
	ssh-keygen -R ${NETWORK}.${ID}
fi

echo -e "\n"
}

function PACKAGE_MANAGEMENT {
if [ ! -f /usr/bin/virt-customize ]; then
	yum -y install libguestfs-tools-c
fi

if [ ! -f /usr/bin/virt-install ]; then
	yum -y install virt-install
fi
}

function TEMPLATE_CHECK {
echo -n "Checking for template: "

if [ ! -f ${TEMPLATE} ]; then
	echo -e "\E[0;31m${TEMPLATE} not found!\E[0m"
	echo -e "Set or modify the path or template name in your configuration file."
	exit 1
else
	echo -e "\E[0;32mFound!\E[0m\n"

fi
}

function NETCHECK_ONE {
echo -e "\n## Checking for network: ${NETWORK_NAME} ##\n"

if virsh net-list --all | grep " ${NETWORK_NAME} " ; then

        echo "${NETWORK_NAME} exists."

else cat << EOF > /tmp/${NETWORK_NAME}.xml
<network>
  <name>${NETWORK_NAME}</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <ip address='${NETWORK}.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='${NETWORK}.201' end='${NETWORK}.254'/>
    </dhcp>
  </ip>
</network>
EOF

virsh net-define /tmp/${NETWORK_NAME}.xml

fi

if virsh net-list | grep " ${NETWORK_NAME} " ; then
        echo "${NETWORK_NAME} is started."
else
        virsh net-start ${NETWORK_NAME}
        virsh net-autostart ${NETWORK_NAME}
fi

# Clean up

if [ -f /tmp/${NETWORK_NAME}.xml ]; then
rm /tmp/${NETWORK_NAME}.xml
fi

echo -e "\n"
}

function NETCHECK_TWO {
echo -e "\n## Checking for network: ${NETWORK_NAME_2}"

if virsh net-list --all | grep " ${NETWORK_NAME_2} " ; then

        echo "${NETWORK_NAME_2} exists."

else cat << EOF > /tmp/${NETWORK_NAME_2}.xml
<network>
  <name>${NETWORK_NAME_2}</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <ip address='${NETWORK_2}.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='${NETWORK_2}.201' end='${NETWORK_2}.254'/>
    </dhcp>
  </ip>
</network>
EOF

virsh net-define /tmp/${NETWORK_NAME_2}.xml

fi

if virsh net-list | grep " ${NETWORK_NAME_2} " ; then
        echo "${NETWORK_NAME_2} is started."
else
        virsh net-start ${NETWORK_NAME_2}
        virsh net-autostart ${NETWORK_NAME_2}
fi

# Clean up

if [ -f /tmp/${NETWORK_NAME_2}.xml ]; then
rm /tmp/${NETWORK_NAME_2}.xml
fi

echo -e "\n"
}

function CONFIGURE_NIC_ONE {
cat > /tmp/ifcfg-eth0 << EOF
DEVICE="eth0"
BOOTPROTO="none"
ONBOOT="yes"
TYPE="Ethernet"
USERCTL="yes"
IPADDR="${NETWORK}.${ID}"
NETMASK="255.255.255.0"
GATEWAY="${NETWORK}.1"
DNS1="${NETWORK}.1"
EOF
echo "eth0 configuration:"
echo "-------------------"
cat /tmp/ifcfg-eth0
echo -e "\n"
}

function CONFIGURE_NIC_TWO {
cat > /tmp/ifcfg-eth1 << EOF
DEVICE="eth1"
BOOTPROTO="none"
ONBOOT="yes"
TYPE="Ethernet"
USERCTL="yes"
IPADDR="${NETWORK_2}.${ID}"
NETMASK="255.255.255.0"
GATEWAY="${NETWORK_2}.1"
DNS1="${NETWORK_2}.1"
EOF
echo "eth1 configuration:"
echo "-------------------"
cat /tmp/ifcfg-eth1
echo -e "\n"
}

function CONFIGURE_DISK {
qemu-img create -f qcow2 ${DISK} ${DISK_SIZE}
virt-resize --expand /dev/sda1 ${TEMPLATE} ${DISK}
DISK_CUSTOMIZATIONS
}

function CREATE_VM {

if [ ! -z "${NETWORK_NAME_2}" ] && [ ! -z "${NETWORK_2}" ]; then

/usr/bin/virt-install \
--disk path=${DISK} \
--import \
--vcpus ${VCPUS} \
--network network=${NETWORK_NAME} \
--network network=${NETWORK_NAME_2} \
--name ${NAME} \
--ram ${MEMORY} \
--os-type=linux \
--dry-run --print-xml > /tmp/${NAME}.xml

else

/usr/bin/virt-install \
--disk path=${DISK} \
--import \
--vcpus ${VCPUS} \
--network network=${NETWORK_NAME} \
--name ${NAME} \
--ram ${MEMORY} \
--os-type=linux \
--dry-run --print-xml > /tmp/${NAME}.xml

fi

virsh define --file /tmp/${NAME}.xml && rm /tmp/${NAME}.xml
}

SSH_KEY_MANAGEMENT
PACKAGE_MANAGEMENT
TEMPLATE_CHECK

NETCHECK_ONE
CONFIGURE_NIC_ONE

if [ ! -z "${NETWORK_NAME_2}" ] && [ ! -z "${NETWORK_2}" ]; then
	NETCHECK_TWO
	CONFIGURE_NIC_TWO
fi

CONFIGURE_DISK

qemu-img snapshot -c VANILLA ${DISK}

CREATE_VM
virsh start ${NAME}
ANSIBLE_PLAY
