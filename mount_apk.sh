#!/system/bin/sh

appName="$1"
pkgName="$2"
appVer="$3"

am force-stop "$pkgName"
stockApp=$(pm path "$pkgName" | sed -n "/base/s/package://p")
{
    mkdir -p /data/local/tmp/revancify/
    mkdir -p /data/adb/post-fs-data.d/
    mkdir -p /data/adb/service.d/
    rm "/data/adb/post-fs-data.d/umount_revanced_$pkgName.sh"
    rm "/data/adb/service.d/mount_revanced_$pkgName.sh"
    rm "/data/local/tmp/revancify/$pkgName.apk"
    grep "$pkgName" /proc/mounts | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -vl
    cp "$appName-"*"-$appVer.apk" "/data/local/tmp/revancify/$pkgName.apk"
    revancedApp="/data/local/tmp/revancify/$pkgName.apk"
    chmod -v 644 "$revancedApp" && chown -v system:system "$revancedApp"
    chcon -v u:object_r:apk_data_file:s0 "$revancedApp"
    mount -vo bind "$revancedApp" "$stockApp"
} >/storage/emulated/0/Revancify/mountlog.txt 2>&1
am force-stop "$pkgName"
