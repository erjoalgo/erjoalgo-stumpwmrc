#!/bin/bash -x

set -euo pipefail

MNT=${HOME}/.usb-drive-symlink

# REALPATH=$(python -c "import os; print(os.path.realpath('${MNT}'))")
# MOUNT_LINE=$(sudo mount | grep -F "${REALPATH}")
# PARTITION=$(grep -o "^[^ 	]*" <<< "${MOUNT_LINE}")

for PART in $(findmnt -n -o SOURCE --target ${MNT}); do
    if test -e ${PART}; then
        PARTITION=${PART}
        break
    fi
done


BLOCK_DEVICE="/dev/$(lsblk -no pkname ${PARTITION})"

sudo umount ${MNT}
sudo udisksctl power-off --block-device  ${BLOCK_DEVICE}
