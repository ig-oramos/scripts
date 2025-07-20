#!/bin/bash

KEYDIR="/etc/cryptsetup-keys.d"

pathtoname() {
    udevadm info -p /sys/"$1" | awk -F= '/DEVNAME/ {print $2}'
}

is_luks() {
    cryptsetup isLuks "$1" 2>/dev/null
}

unlock_luks() {
    dev="$1"
    name="luks-$(basename "$dev")"
    for keyfile in "$KEYDIR"/*; do
        if cryptsetup luksOpen "$dev" "$name" --key-file "$keyfile" 2>/dev/null; then
            echo "Unlocked $dev with $keyfile"
            echo "/dev/mapper/$name"
            return 0
        fi
    done

    echo "Failed to unlock $dev, $name" >&2
    return 1
}

stdbuf -oL -- udevadm monitor --udev -s block | while read -r -- _ _ event devpath _; do
    if [ "$event" = add ]; then
        devname=$(pathtoname "$devpath")

        # Wait a moment for the device node to be ready
        sleep 1

        if is_luks "$devname"; then
            mapper_path=$(unlock_luks "$devname") || continue
            udisksctl mount --block-device "$mapper_path" --no-user-interaction
        else
            udisksctl mount --block-device "$devname" --no-user-interaction
        fi
    fi
done
