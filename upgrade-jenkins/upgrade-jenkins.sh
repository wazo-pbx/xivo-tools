#!/bin/bash -e

current_jenkins_version=$(ssh root@jenkins dpkg-query -W -f='\${Version}' jenkins)
[[ $current_jenkins_version =~ ^[0-9]+\.[0-9]+$ ]]
echo "Current Jenkins version is $current_jenkins_version"

echo "Shutting down jenkins..."
ssh root@kvm-2-dev virsh shutdown jenkins.xivo.io
while [ "$(ssh kvm-2-dev virsh dominfo jenkins.xivo.io | grep State | awk '{print $2}')" = 'running' ] ; do
	sleep 5
done
echo "Snapshotting jenkins..."
# Unplug raw volume, it can't be snapshot
ssh root@kvm-2-dev virsh detach-disk --config jenkins.xivo.io vdb
# Snapshot
ssh root@kvm-2-dev virsh snapshot-create-as jenkins.xivo.io "$current_jenkins_version"
# Plug back the raw volume
ssh root@kvm-2-dev virsh attach-disk --config jenkins.xivo.io /var/lib/libvirt/images/jenkins-docker.img vdb --targetbus virtio --driver qemu --subdriver raw
ssh root@kvm-2-dev virsh start jenkins.xivo.io

echo "Waiting for jenkins to come back up..."
while ! ssh root@jenkins echo
do
	sleep 10
done

echo "Upgrading jenkins..."
ssh root@jenkins apt-get update
ssh root@jenkins DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
ssh root@jenkins DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade
ssh root@jenkins apt-get -y autoremove

echo
echo "Things left to do:"
echo "1. (optional) reboot Jenkins: ssh root@jenkins reboot"
echo "2. delete oldest snapshot: ssh root@kvm-2-dev virsh snapshot-delete jenkins.xivo.io <snapshot>"
ssh root@kvm-2-dev virsh snapshot-list jenkins.xivo.io
echo "3. (optional) resize qcow2 image (lasts more than 10min):"
echo "  - ssh root@kvm-2-dev virsh start jenkins.xivo.io"
echo "  - ssh root@jenkins"
echo "     - dd if=/dev/zero of=/zero bs=1M; rm /zero"
echo "     - poweroff"
echo "  - ssh root@kvm-2-dev virt-sparsify --in-place /var/lib/libvirt/images/jenkins.xivo.io.qcow2"
ssh root@kvm-2-dev virsh snapshot-list jenkins.xivo.io
echo "4. update Jenkins plugins"
