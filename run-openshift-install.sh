#!/bin/bash -ex


main() {
    local installer="${1:?}"
    local asset_dir="${2:-.}"

    setup_libvirt
    setup_network_manager

    export \
        TF_VAR_libvirt_master_memory=10240 \
        TF_VAR_libvirt_master_vcpu=4

    "$installer" \
        --dir "$asset_dir" \
        --log-level debug \
        create \
        cluster
}


setup_libvirt() {
    wait_for libvirtd
    if ! virsh-pool info default; then
        virsh pool-define /dev/stdin <<EOF
<pool type='dir'>
  <name>default</name>
  <target>
    <path>/var/lib/libvirt/images</path>
  </target>
</pool>
EOF
    fi
    virsh pool-start default
    virsh pool-autostart default
}


setup_network_manager() {
    wait_for NetworkManager
    echo -e "[main]\ndns=dnsmasq" | tee /etc/NetworkManager/conf.d/openshift.conf
    original_dns=$(grep nameserver /etc/resolv.conf | head -n 1 | awk '{print $2}')
    echo "nameserver 127.0.0.1" > /etc/resolv.conf
    echo server=/tt.testing/192.168.126.1 | tee /etc/NetworkManager/dnsmasq.d/openshift.conf
    echo "server=/#/$original_dns" >> /etc/NetworkManager/dnsmasq.d/openshift.conf
    systemctl reload NetworkManager.service
    wait_for NetworkManager
    # Give dnsmasq time to boot
    sleep 5
}


wait_for() {
    local svc="${1:?}"
    local tries=60

    for ((i=0; i < "$tries"; i++)); do
        systemctl is-active "$svc" && return 0
        sleep 1
    done

    return 1
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
