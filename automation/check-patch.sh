#!/bin/bash -xe


main() {
    build
}


build() {
    ENV="TAGS=libvirt" ./hack/dockerized.sh hack/build.sh
}


[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
