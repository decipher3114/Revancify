#!/system/bin/sh

pkgName="$2"
appName="$3"
appVer="$4"
sourceName="$5"


if [ "$1" = "unmount" ]; then
    grep -q "$pkgName" /proc/mounts || exit 2
    am force-stop "$pkgName"
    grep "$pkgName" /proc/mounts | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l
    stockApp=$(pm path "$pkgName" | sed -n "/base/s/package://p")
    am force-stop "$pkgName"
    rm "/data/adb/service.d/mount_revanced_$pkgName.sh"
    rm "/data/adb/post-fs-data.d/umount_revanced_$pkgName.sh"
    rm -rf "/data/local/tmp/revancify/$pkgName.apk"
    grep -q "$pkgName" /proc/mounts && exit 1
    exit 0
fi

[ -d /data/local/tmp/revancify/ ] || mkdir -p /data/local/tmp/revancify/
[ -d /data/adb/post-fs-data.d/ ] || mkdir -p /data/adb/post-fs-data.d/
[ -d /data/adb/service.d/ ] || mkdir -p /data/adb/service.d/

rm "/data/adb/post-fs-data.d/umount_revanced_$pkgName.sh"
rm "/data/adb/service.d/mount_revanced_$pkgName.sh"
rm "/data/local/tmp/revancify/$pkgName.apk"


if pm list packages | grep -q "$pkgName" && [ "$(dumpsys package "$pkgName" | sed -n '/versionName/s/.*=//p' | sed 's/ /./1p')" = "$appVer" ]; then
    :
else
    pm install --user 0 -i com.android.vending -r -d "apps/$appName-$appVer/base.apk" || exit 1
fi

pm list packages | grep -q "$pkgName" || exit 1

stockApp=$(pm path "$pkgName" | sed -n "/base/s/package://p")
revancedApp="/data/local/tmp/revancify/$pkgName.apk"

am force-stop "$pkgName"

{
    grep "$pkgName" /proc/mounts | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -vl
    cp "apps/$appName-$appVer/base-$sourceName.apk" "/data/local/tmp/revancify/$pkgName.apk"
    chmod -v 644 "$revancedApp" && chown -v system:system "$revancedApp"
    chcon -v u:object_r:apk_data_file:s0 "$revancedApp"
    mount -vo bind "$revancedApp" "$stockApp"
} > /storage/emulated/0/Revancify/install_log.txt 2>&1

am force-stop "$pkgName"

grep -q "$pkgName" /proc/mounts || exit 1

cat <<EOF >"/data/adb/service.d/mount_revanced_$pkgName.sh"
#!/system/bin/sh
while [ "\$(getprop sys.boot_completed | tr -d '\r')" != "1" ]; do sleep 5; done

base_path="/data/local/tmp/revancify/$pkgName.apk"
stock_path="\$(pm path $pkgName | sed -n '/base/s/package://p')"
am force-stop "$pkgName"
chcon u:object_r:apk_data_file:s0 "\$base_path"
[ ! -z "\$stock_path" ] && mount -o bind "\$base_path" "\$stock_path"
am force-stop $pkgName
EOF
cat <<EOF >"/data/adb/post-fs-data.d/umount_revanced_$pkgName.sh"
#!/system/bin/sh
stock_path="\$(pm path $pkgName | sed -n '/base/s/package://p')"
[ ! -z "\$stock_path" ] && umount -l "\$stock_path"
grep $pkgName /proc/mounts | | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l
EOF
chmod 0744 "/data/adb/service.d/mount_revanced_$pkgName.sh"
chmod 0744 "/data/adb/post-fs-data.d/umount_revanced_$pkgName.sh"
