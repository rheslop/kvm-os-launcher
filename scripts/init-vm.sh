#!/bin/bash

CONF=$1
ID=$2
source ${CONF}

function SSH_KEY_MANAGEMENT {
# Create an SSH key for root if one does not already exist

if [ ! -f /root/.ssh/id_rsa ]; then
	ssh-keygen -t rsa -b 2048 -N "" -f /root/.ssh/id_rsa
fi

# If the VM's name or IP is in known_hosts from a previous deploy, remove it

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

function NETWORK_CHECK {
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

######################################################

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

function CONFIGURE_NETWORK {
cat > exec/${ID}-conf-networking.sh << EOF

nmcli con add type ethernet con-name eth0 ifname eth0 ipv4.method manual ipv4.addresses ${NETWORK}.${ID}/24 gw4 ${NETWORK}.1
nmcli con modify eth0 ipv4.dns ${DNS:-8.8.8.8}
nmcli con up eth0
nmcli con add type ethernet con-name eth1 ifname eth1 ipv4.method manual ipv4.addresses ${NETWORK_2}.${ID}/24
nmcli con modify eth1 ipv4.dns ${DNS:-8.8.8.8}
nmcli con up eth1
EOF

echo "eth0 configuration:"
echo "-------------------"
echo "IP Address: ${NETWORK}.${ID}"
echo "Gateway:    ${NETWORK}.1"
echo "DNS:        ${DNS:-8.8.8.8}"
echo -e "\n"

echo "eth1 configuration:"
echo "-------------------"
echo "IP Address: ${NETWORK_2}.${ID}"
echo "Gateway:    ${NETWORK_2}.1"
echo "DNS:        ${DNS:-8.8.8.8}"
echo -e "\n"
}

function CONFIGURE_DISK {
qemu-img create -f qcow2 ${DISK} ${DISK_SIZE}
virt-resize --expand ${DISK_EXPAND_PART:-/dev/sda1} ${TEMPLATE} ${DISK}
}

function CUSTOMIZE_AND_START { 
cat > exec/${ID}-customize_disk_and_create.sh << EOF

export LIBGUESTFS_BACKEND=direct

sudo virt-customize -v -x -a ${DISK} \
--root-password password:password \
--hostname ${NAME}.${NETWORK_NAME_2}.local \
--edit /etc/ssh/sshd_config:s/PasswordAuthentication\ no/PasswordAuthentication\ yes/g \
--edit /etc/ssh/sshd_config:s/\#PermitRootLogin\ prohibit-password/PermitRootLogin\ yes/ \
--firstboot exec/${ID}-conf-networking.sh \
--ssh-inject root \
--run-command '/usr/bin/yum -y remove cloud-init' \
--run-command 'echo "UseDNS no" >> /etc/ssh/sshd_config' \
--selinux-relabel

sudo qemu-img snapshot -c VANILLA ${DISK}
rm exec/${ID}-conf-networking.sh

sudo /usr/bin/virt-install \
--disk path=${DISK} \
--import \
--vcpus ${VCPUS} \
--network network=${NETWORK_NAME} \
--network network=${NETWORK_NAME_2} \
--name ${NAME} \
--ram ${MEMORY} \
--os-variant=${OS_VARIANT:-linux2022} \
--dry-run --print-xml > /tmp/${NAME}.xml

sudo virsh define --file /tmp/${NAME}.xml && sudo rm /tmp/${NAME}.xml
sudo virsh start ${NAME}

rm exec/${ID}-customize_disk_and_create.sh

EOF
}

function HELPER_SCRIPTS {
cat > exec/${ID}-remove_vm.sh << EOF
#!/bin/bash

sudo virsh destroy ${NAME}
sudo virsh undefine ${NAME} --remove-all-storage || sudo rm /var/lib/libvirt/images/${NAME}.qcow2
sudo rm exec/${ID}-*
EOF

cat > exec/${ID}-reset_vm.sh << EOF
if [[ \$(id -u) -ne 0 ]]; then
   echo "You must use sudo to reset the VM." 
   exit 1
fi

if [ \$(virsh domstate ${NAME}) == "running" ]; then virsh destroy ${NAME}; fi
qemu-img snapshot -a VANILLA ${DISK}
virsh start ${NAME}

if [ -f /root/.ssh/known_hosts ]; then
        ssh-keygen -R ${NAME}
        ssh-keygen -R ${NETWORK}.${ID}
fi

EOF
}

SSH_KEY_MANAGEMENT
PACKAGE_MANAGEMENT
TEMPLATE_CHECK

NETWORK_CHECK
CONFIGURE_NETWORK
CONFIGURE_DISK

CUSTOMIZE_AND_START
HELPER_SCRIPTS

chmod +x exec/*

# virsh start ${NAME}
# ANSIBLE_PLAY
