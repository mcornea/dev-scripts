#!/usr/bin/env bash
set -xe

source common.sh
source ocp_install_env.sh

# Allow local non-root-user access to libvirt
sudo usermod -a -G "libvirt" $USER
sudo systemctl restart libvirtd

# As per https://github.com/openshift/installer/blob/master/docs/dev/libvirt-howto.md#configure-default-libvirt-storage-pool
# Usually virt-manager/virt-install creates this: https://www.redhat.com/archives/libvir-list/2008-August/msg00179.html
if ! virsh pool-uuid default > /dev/null 2>&1 ; then
    virsh pool-define /dev/stdin <<EOF
<pool type='dir'>
  <name>default</name>
  <target>
    <path>/var/lib/libvirt/images</path>
  </target>
</pool>
EOF
    virsh pool-start default
    virsh pool-autostart default
fi


cat >> provisioning.xml << EOF
<network >
 <name>provisioning</name>
 <bridge name='provisioning' stp='on' delay='0'/>
</network>
EOF

cat >> baremetal.xml << EOF
<network >
 <name>baremetal</name>
 <bridge name='baremetal' stp='on' delay='0'/>
</network>
EOF

sudo virsh net-define provisioning.xml
sudo virsh net-define baremetal.xml
sudo virsh net-start provisioning
sudo virsh net-start baremetal
sudo brctl addif baremetal eth1
sudo brctl addif provisioning eth2
sudo ip link set dev eth1 up
sudo ip link set dev eth2 up
