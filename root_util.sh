#!/system/bin/sh

pkgName="$2"
appName="$3"
appVer="$4"

unmount() {
    if ! grep -q "$pkgName" /proc/mounts; then
        exit 2
    fi
    am force-stop "$pkgName"
    grep "$pkgName" /proc/mounts | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l
    stockApp=$(pm path "$pkgName" | sed -n "/base/s/package://p")
    am force-stop "$pkgName"
    rm "/data/adb/service.d/mount_revanced_$pkgName.sh"
    rm "/data/adb/post-fs-data.d/umount_revanced_$pkgName.sh"
    rm -rf "/data/local/tmp/revancify/$pkgName.apk"
    if grep -q "$pkgName" /proc/mounts; then
        exit 1 
    fi
    exit 0
}

if [ "$1" = "unmount" ]; then
    unmount
fi

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
    cp "$appName-"*-*"$appVer.apk" "/data/local/tmp/revancify/$pkgName.apk"
    revancedApp="/data/local/tmp/revancify/$pkgName.apk"
    chmod -v 644 "$revancedApp" && chown -v system:system "$revancedApp"
    chcon -v u:object_r:apk_data_file:s0 "$revancedApp"
    mount -vo bind "$revancedApp" "$stockApp"
} >/storage/emulated/0/Revancify/mountlog.txt 2>&1
am force-stop "$pkgName"

if ! grep -q "$pkgName" /proc/mounts; then
    exit 1
fi

cat <<EOF >"mount_revanced_$pkgName.sh"
#!/system/bin/sh
while [ "\$(getprop sys.boot_completed | tr -d '\r')" != "1" ]; do sleep 5; done

base_path="/data/local/tmp/revancify/$pkgName.apk"
stock_path="\$(pm path $pkgName | sed -n '/base/s/package://p')"
am force-stop "$pkgName"
chcon u:object_r:apk_data_file:s0 "\$base_path"
[ ! -z "\$stock_path" ] && mount -o bind "\$base_path" "\$stock_path"
am force-stop $pkgName
EOF
cat <<EOF >"umount_revanced_$pkgName.sh"
#!/system/bin/sh
stock_path="\$(pm path $pkgName | sed -n '/base/s/package://p')"
[ ! -z "\$stock_path" ] && umount -l "\$stock_path"
grep $pkgName /proc/mounts | | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l
EOF
mv "mount_revanced_$pkgName.sh" /data/adb/service.d
chmod 0744 "/data/adb/service.d/mount_revanced_$pkgName.sh"
mv "umount_revanced_$pkgName.sh" /data/adb/post-fs-data.d
chmod 0744 "/data/adb/post-fs-data.d/umount_revanced_$pkgName.sh"
