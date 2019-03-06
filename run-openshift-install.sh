#!/bin/bash -ex


main() {
    local installer="${1:?}"
    local asset_dir="${2:-.}"

    export \
        TF_VAR_libvirt_master_memory=10240 \
        TF_VAR_libvirt_master_vcpu=4

    "$installer" \
        --dir "$asset_dir" \
        --log-level debug \
        create \
        cluster
}


[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
