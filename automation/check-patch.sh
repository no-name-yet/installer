#!/bin/bash -xe


main() {
    local installer="openshift-install"
    local installer_local_path="bin/${installer}"
    local installer_remote_path="/root/${installer}"
    local install_script="run-openshift-install.sh"
    local install_script_local_path="$install_script"
    local install_script_remote_path="/root/${install_script}"
    local install_config="install-config.yaml"
    local asset_dir="/root"
    local install_config_local_path="$install_config"
    local install_config_remote_path="${asset_dir}/${install_config}"
    local artifacts_dir="exported-artifacts"
    local private_key_local_path="keys/id_rsa"
    local private_key_remote_path="/root/.ssh"
    local ret=0
    local env_container
    local logs_to_collect=("${asset_dir}/.openshift_install.log")

    mkdir -p "$artifacts_dir"

    build_installer
    build_env_container
    env_container="$(run_env_container)"
    copy_to \
        "$env_container" \
        "$installer_local_path" \
        "$installer_remote_path"
    copy_to \
        "$env_container" \
        "$install_script_local_path" \
        "$install_script_remote_path"
    copy_to \
        "$env_container" \
        "$install_config_local_path" \
        "$install_config_remote_path"

    _exec "$env_container" mkdir /root/.ssh

    copy_to \
        "$env_container" \
        "$private_key_local_path" \
        "$private_key_remote_path"

    _exec \
        "$env_container" \
        "$install_script_remote_path" \
        "$installer_remote_path" \
        "$asset_dir" \
        || ret="$?"

    for p in "${logs_to_collect[@]}"; do
        copy_from \
            "$env_container" \
            "$p" \
            "$artifacts_dir" \
            || echo "Failed to collect $p"
    done

    export_booktube_log "$env_container" "$artifacts_dir" || :
    ls -l "$artifacts_dir"

    if [[ "$ret" -ne 0 ]]; then
        echo "Failed to install Openshift"
    else
        echo "Success"
    fi


    return "$ret"
}


build_installer() {
    ENV="TAGS=libvirt" ./hack/dockerized.sh hack/build.sh
}


build_env_container() {
    docker build -t "$(get_env_container_tag)" container
}


run_env_container() {
    docker run -d --privileged "$(get_env_container_tag)"
}


get_env_container_tag() {
    echo "openshift-env"
}


export_booktube_log() {
    local cid="${1:?}"
    local where="${2:?}"
    local cred="${3:-core@api.test1.tt.testing}"

    _exec \
        "$cid" \
        ssh \
        -o StrictHostKeyChecking=no \
        "$cred" \
            journalctl \
            --no-pager \
            -b \
            -u \
            bootkube.service \
    > "${where}/booktube.log"
}


copy_to() {
    local cid="${1:?}"
    local what="${2:?}"
    local where="${3:?}"

    docker cp "$what" "${cid}:${where}"
}


copy_from() {
    local cid="${1:?}"
    local what="${2:?}"
    local where="${3:?}"

    docker cp "${cid}:${what}" "$where"
}



_exec() {
    local cid="${1:?}"
    local tty_flag
    shift

    tty -s && tty_flag="t"
    docker exec "-i${tty_flag}" "$cid" "$@"
}


[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
