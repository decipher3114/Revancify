#!/system/bin/sh

PKG_NAME="$1"

am force-stop "$PKG_NAME"
grep "$PKG_NAME" /proc/mounts | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l
am force-stop "$PKG_NAME"
pm clear --cache-only "$PKG_NAME"
rm -f "/data/adb/service.d/mount_$PKG_NAME.sh"
rm -f "/data/adb/post-fs-data.d/umount_$PKG_NAME.sh"
rm -f "/data/local/tmp/revancify/$PKG_NAME.apk"
