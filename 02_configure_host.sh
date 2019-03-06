#!/usr/bin/env bash
set -xe

source common.sh
source ocp_install_env.sh
# Allow local non-root-user access to libvirt ref
# https://github.com/openshift/installer/blob/master/docs/dev/libvirt-howto.md#make-sure-you-have-permissions-for-qemusystem
if sudo test ! -f /etc/polkit-1/rules.d/80-libvirt.rules ; then
  cat <<EOF | sudo dd of=/etc/polkit-1/rules.d/80-libvirt.rules
polkit.addRule(function(action, subject) {
  if (action.id == "org.libvirt.unix.manage" && subject.local && subject.active && subject.isInGroup("wheel")) {
      return polkit.Result.YES;
  }
});
EOF
fi
# Allow local non-root-user access to libvirt
sudo usermod -a -G "libvirt" $USER

sudo systemctl restart libvirtd

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
