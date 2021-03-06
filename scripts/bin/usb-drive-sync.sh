#!/bin/bash -x

set -euo pipefail

UNISON_OPTS=${*}
MNT=${HOME}/.usb-drive-symlink

HOME_TWO_WAY=${HOME}/private-data
MNT_TWO_WAY=${MNT}/sync-two-ways

mkdir -p ${HOME_TWO_WAY}

unison -fat\
       ${UNISON_OPTS} \
       ${MNT_TWO_WAY} ${HOME_TWO_WAY}

# -ignore 'Path *'
# -path 'Name *.prf' \
# hard-code default.prf for now
unison -fat  \
  ${UNISON_OPTS} \
  ${MNT_TWO_WAY}/configs/.unison-default.prf  \
  ${HOME}/.unison/default.prf

mkdir -p ${HOME}/public-data
unison -dontchmod -perms 0  \
           ${UNISON_OPTS} \
           ${MNT}/public-data ${HOME}/public-data

ROOT_DEVICE_PATH=$(sed -E "s/[ 	]+/ /g" /etc/fstab | grep ' / ' | cut -f1 -d' ')

MACHINE_UUID=$(lsblk ${ROOT_DEVICE_PATH} -o uuid | tail -1)

MNT_ONE_WAY=${MNT}/sync-one-way/${MACHINE_UUID}

mkdir -p ${MNT_ONE_WAY}
mkdir -p ${HOME}/private-data-one-way

for ONE_WAY_REL in .bash_history  \
                       private-data-one-way/ \
                   ; do
    SRC=${HOME}/${ONE_WAY_REL}
    DEST=${MNT_ONE_WAY}/${ONE_WAY_REL}
    if test -e ${SRC}; then
        rsync -rv ${SRC} ${DEST}
    fi
done

# TODO rsnapshot
