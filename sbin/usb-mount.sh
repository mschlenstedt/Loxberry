#!/usr/bin/env bash
# If you are executing this script in cron with a restricted environment,
# modify the shebang to specify appropriate path; /bin/bash in most distros.
# And, also if you aren't comfortable using(abuse?) env command.

# This script is based on https://serverfault.com/a/767079 posted
# by Mike Blackwell, modified to our needs. Credits to the author.

# This script is called from systemd unit file to mount or unmount
# a USB drive.

# Modified for LoxBerry by Michael Schlenstedt
# Original: https://github.com/six-k/automount-usb

# Parse environments
. /etc/environment

PATH="$PATH:/usr/bin:/usr/local/bin:/usr/sbin:/usr/local/sbin:/bin:/sbin"
log="logger -t usb-mount.sh -s "

usage()
{
    ${log} "Usage: $0 {chkadd|add|remove} device_name (e.g. sdb1)"
    exit 1
}

if [[ $# -ne 2 ]]; then
    usage
fi

ACTION=$1
DEVBASE=$2
DEVICE="/dev/${DEVBASE}"

# Get info for this drive: $LABEL, $UUID, $TYPE $PARTUUID
eval $(blkid -o export ${DEVICE})

# See if this drive is already mounted, and if so where
MOUNT_POINT=$(mount | grep ${DEVICE} | awk '{ print $3 }')
if [[ ! -n ${MOUNT_POINT} ]]; then
        MOUNT_POINT=$(mount | grep ${PARTUUID} | awk '{ print $3 }')
fi
if [[ ! -n ${MOUNT_POINT} ]]; then
        MOUNT_POINT=$(mount | grep ${UUID} | awk '{ print $3 }')
fi

# See if device is mentioned in /etc/fstab
MOUNT_POINT_FSTAB=$(cat /etc/fstab | grep ${DEVICE} | awk '{ print $2 }')
if [[ ! -n ${MOUNT_POINT_FSTAB} ]]; then
        MOUNT_POINT_FSTAB=$(cat /etc/fstab | grep ${PARTUUID} | awk '{ print $2 }')
fi
if [[ ! -n ${MOUNT_POINT_FSTAB} ]]; then
        MOUNT_POINT_FSTAB=$(cat /etc/fstab | grep ${UUID} | awk '{ print $2 }')
fi

DEV_LABEL=""

check_add()
{
    if [[ -n ${MOUNT_POINT} ]]; then
        ${log} "Warning: ${DEVICE} is already mounted at ${MOUNT_POINT}"
        exit 1
    fi

    if [[ -n ${MOUNT_POINT_FSTAB} ]]; then
        ${log} "Warning: ${DEVICE} is mentioned in /etc/fstab at ${MOUNT_POINT_FSTAB}"
        exit 1
    fi
    systemctl start usb-mount@${DEVBASE}.service
}

do_mount()
{
    # Figure out a mount point to use
    LABEL=$(echo ${LABEL} | sed -e 's/[^A-Za-z0-9._-]/_/g')

    if grep -q " \"/media/usb/${LABEL}\" " /etc/mtab; then
        # Already in use, make a unique one
        LABEL+="-${PARTUUID}"
    fi
    DEV_LABEL="${LABEL}"

    # Use the PARTUUID in case the drive doesn't have label
    if [ -z "${DEV_LABEL}" ]; then
        DEV_LABEL="${PARTUUID}"
    fi

    MOUNT_POINT="/media/usb/${DEV_LABEL}"

    ${log} "Mount point: ${MOUNT_POINT}"

    mkdir -p "${MOUNT_POINT}"

    # Global mount options
    OPTS="users,rw,relatime"

    # File system type specific mount options
    # NTFS
    if [[ ${TYPE} == "ntfs" ]]; then
        OPTS+=",gid=1001,uid=1001,umask=000,nls=utf8"
    fi
    # extFAT
    if [[ ${TYPE} == "exfat" ]]; then
        OPTS+=",gid=1001,uid=1001,umask=000,iocharset=utf8"
	echo $OPTS
    fi
    # vFAT
    if [[ ${TYPE} == "vfat" ]]; then
        OPTS+=",gid=1001,uid=1001,umask=000,shortname=mixed,iocharset=utf8,flush"
    fi

    if ! mount -o ${OPTS} ${DEVICE} ${MOUNT_POINT}; then
        ${log} "Error mounting ${DEVICE} (status = $?)"
        rmdir "${MOUNT_POINT}"
        exit 1
    else
        # Track the mounted drives
        echo "${MOUNT_POINT}:${DEVBASE}" | cat >> "/var/log/usb-mount.track" 
    fi

    # ext2/3/4 
    if [[ ${TYPE} == "ext2" ]] || [[ ${TYPE} == "ext3" ]] || [[ ${TYPE} == "ext4" ]]; then
        chown loxberry:loxberry ${MOUNT_POINT}
    fi

    ${log} "Mounted ${DEVICE} at ${MOUNT_POINT}"
}

do_unmount()
{
    if [[ -z "${MOUNT_POINT}" ]]; then
        ${log} "Warning: ${DEVICE} is not mounted"
    else
        umount -l ${DEVICE}
	${log} "Unmounted ${DEVICE} from ${MOUNT_POINT}"
        /bin/rmdir "${MOUNT_POINT}"
        sed -i.bak "\@${MOUNT_POINT}@d" /var/log/usb-mount.track
    fi


}

case "${ACTION}" in
    chkadd)
	check_add
	;;
    add)
        do_mount
        ;;
    remove)
        do_unmount
        ;;
    *)
        usage
        ;;
esac
