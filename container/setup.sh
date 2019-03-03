#!/bin/bash -ex

# dnsmasq configuration
echo -e "[main]\ndns=dnsmasq" | tee /etc/NetworkManager/conf.d/openshift.conf
original_dns="$(grep nameserver /etc/resolv.conf | head -n 1 | awk '{print $2}')"
echo server=/tt.testing/192.168.126.1 | tee /etc/NetworkManager/dnsmasq.d/openshift.conf
echo "server=/#/$original_dns" >> /etc/NetworkManager/dnsmasq.d/openshift.conf

# create libvirt storage pool
mkdir -p /etc/libvirt/storage/autostart
cat > /etc/libvirt/storage/default.xml <<EOF
<pool type='dir'>
  <name>default</name>
  <target>
    <path>/var/lib/libvirt/images</path>
  </target>
</pool>
EOF

ln -s /etc/libvirt/storage/default.xml /etc/libvirt/storage/autostart/default.xml
