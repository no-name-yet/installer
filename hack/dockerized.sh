#!/bin/bash
set -ex

PROJECT_ROOT="$(realpath $(dirname "$BASH_SOURCE[0]")/..)"
DOCKER_DIR=${PROJECT_ROOT}/hack/docker-builder

BUILDER=openshift-installer

TEMPFILE=".rsynctemp"

SYNC_OUT=${SYNC_OUT:-true}
SYNC_VENDOR=${SYNC_VENDOR:-false}
SYNC_GENERATED=${SYNC_GENERATED:-false}
PROJECT="github.com/openshift/installer"

OUT_DIR="${PROJECT_ROOT}/bin"
VENDOR_DIR="${PROJECT_ROOT}/vendor"
TESTS_OUT_DIR=$OUT_DIR/tests

# Build the build container
(cd ${DOCKER_DIR} && docker build . -t ${BUILDER})

# Create the persistent docker volume
if [ -z "$(docker volume list | grep ${BUILDER})" ]; then
    docker volume create --name ${BUILDER}
fi

# Make sure that the output directory exists
docker run -v "${BUILDER}:/root:rw,z" --security-opt label:disable --rm ${BUILDER} mkdir -p "/root/go/src/${PROJECT}/bin"

# Make sure that the vendor directory exists
docker run -v "${BUILDER}:/root:rw,z" --security-opt label:disable --rm ${BUILDER} mkdir -p "/root/go/src/${PROJECT}/vendor"

# Start an rsyncd instance and make sure it gets stopped after the script exits
RSYNC_CID=$(docker run -d -v "${BUILDER}:/root:rw,z" --security-opt label:disable --expose 873 -P ${BUILDER} /usr/bin/rsync --no-detach --daemon --verbose)

function finish() {
    docker stop ${RSYNC_CID} >/dev/null 2>&1 &
    docker rm -f ${RSYNC_CID} >/dev/null 2>&1 &
}
trap finish EXIT

RSYNCD_PORT=$(docker port $RSYNC_CID 873 | cut -d':' -f2)

rsynch_fail_count=0

while ! rsync "${PROJECT_ROOT}/${RSYNCTEMP}" "rsync://root@127.0.0.1:${RSYNCD_PORT}/build/${RSYNCTEMP}" &>/dev/null; do
    if [[ "$rsynch_fail_count" -eq 0 ]]; then
        printf "Waiting for rsyncd to be ready"
        sleep .1
    elif [[ "$rsynch_fail_count" -lt 30 ]]; then
        printf "."
        sleep 1
    else
        printf "failed"
        break
    fi
    rsynch_fail_count=$((rsynch_fail_count + 1))
done

printf "\n"

rsynch_fail_count=0

_rsync() {
    rsync -al "$@"
}

_rsync \
    --delete \
    --include 'hack/***' \
    --include 'vendor/***' \
    --include 'Gopkg*' \
    --include 'tests/***' \
    --include 'Makefile' \
    --include 'data/***' \
    --include '.git/***' \
    --include 'cmd/***' \
    --include 'pkg/***' \
    --exclude '*' \
    --verbose \
    ${PROJECT_ROOT}/ \
    "rsync://root@127.0.0.1:${RSYNCD_PORT}/build"


# Run the command
test -t 1 && USE_TTY="-it"

docker run --rm $(printf -- '-e %s ' $ENV) -v "${BUILDER}:/root:rw,z" --security-opt label:disable ${USE_TTY} -w "/root/go/src/${PROJECT}" ${BUILDER} "$@"

if [ "$SYNC_VENDOR" = "true" ]; then
    _rsync --delete "rsync://root@127.0.0.1:${RSYNCD_PORT}/vendor" "${PROJECT_ROOT}/vendor"
fi
# Copy the build output out of the container, make sure that _out exactly matches the build result
if [ "$SYNC_OUT" = "true" ]; then
    _rsync --delete "rsync://root@127.0.0.1:${RSYNCD_PORT}/out" ${OUT_DIR}
fi
# Copy generated sources
if [ "$SYNC_GENERATED" = "true" ]; then
    _rsync --delete "rsync://root@127.0.0.1:${RSYNCD_PORT}/build/tests/" ${PROJECT_ROOT}/tests
fi
