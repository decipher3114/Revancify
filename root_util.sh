#!/system/bin/sh

pkgName="$2"
appName="$3"
appVer="$4"
sourceName="$5"

if [ "$1" = "unlink" ]; then
    stockApp=$(pm path "$pkgName" | sed -n "/base/s/package://p")
    stockAppBackup="/data/local/tmp/revancify/$pkgName.orig.apk"
    [ -f "$stockAppBackup" ] || exit 2
    am force-stop "$pkgName"
    rm -f "$stockApp"
    ln "$stockAppBackup" "$stockApp"
    rm -f "$stockAppBackup"
    am force-stop "$pkgName"
    rm "/data/adb/service.d/link_revanced_$pkgName.sh"
    rm "/data/adb/post-fs-data.d/unlink_revanced_$pkgName.sh"
    # For compatibility with older Revancify revisions, let's remove the old scripts as well
    rm "/data/adb/service.d/mount_revanced_$pkgName.sh"
    rm "/data/adb/post-fs-data.d/umount_revanced_$pkgName.sh"
    exit 0
fi

[ -d /data/local/tmp/revancify/ ] || mkdir -p /data/local/tmp/revancify/
[ -d /data/adb/post-fs-data.d/ ] || mkdir -p /data/adb/post-fs-data.d/
[ -d /data/adb/service.d/ ] || mkdir -p /data/adb/service.d/

rm "/data/adb/post-fs-data.d/unlink_revanced_$pkgName.sh"
rm "/data/adb/service.d/link_revanced_$pkgName.sh"
rm "/data/adb/post-fs-data.d/umount_revanced_$pkgName.sh"
rm "/data/adb/service.d/mount_revanced_$pkgName.sh"
rm "/data/local/tmp/revancify/$pkgName.apk"
rm "/data/local/tmp/revancify/$pkgName.orig.apk"

if pm list packages | grep -q "$pkgName" &&
    [ $(dumpsys package "$pkgName" | sed -n '/versionName/s/.*=//p' | sed 's/ /./1p') = "$appVer" ] &&
    [ $(pm path "$pkgName" | sed -n "/base/s/package://p" | cut -d '/' -f 2) = "data" ]; then
    :
else
    pm install --user 0 -r "apps/$appName-$appVer/base.apk"
fi

pm list packages | grep -q "$pkgName" || exit 1

stockApp=$(pm path "$pkgName" | sed -n "/base/s/package://p")
stockAppBackup="/data/local/tmp/revancify/$pkgName.orig.apk"
revancedApp="/data/local/tmp/revancify/$pkgName.apk"

am force-stop "$pkgName"

{
    ln -v "$stockApp" "$stockAppBackup"                                                         # Back up the stock app
    cp -v "apps/$appName-$appVer/base-$sourceName.apk" "/data/local/tmp/revancify/$pkgName.apk" # Copy the patched app

    chmod -v 644 "$revancedApp" && chown -v system:system "$revancedApp"
    chcon -v u:object_r:apk_data_file:s0 "$revancedApp"

    rm -fv "$stockApp"               # Remove the app from the stock location in /data/app
    ln -v "$revancedApp" "$stockApp" # Link the patched app in place of the stock app
} >/storage/emulated/0/Revancify/install_log.txt 2>&1

am force-stop "$pkgName"

cat <<EOF >"/data/adb/post-fs-data.d/unlink_revanced_$pkgName.sh"
#!/system/bin/sh
stock_path="\$(pm path $pkgName | sed -n '/base/s/package://p')"
stock_backup_path="/data/local/tmp/revancify/$pkgName.orig.apk"
[ -e "\$stock_backup_path" ] || exit 2
[ ! -z "\$stock_path" ] && [ -e "\$stock_path" ] || exit 2
rm -f "\$stock_path"
mount -o bind "\$stock_backup_path" "\$stock_path"
EOF

cat <<EOF >"/data/adb/service.d/link_revanced_$pkgName.sh"
#!/system/bin/sh
while [ "\$(getprop sys.boot_completed | tr -d '\r')" != "1" ]; do sleep 5; done

stock_path="\$(pm path $pkgName | sed -n '/base/s/package://p')"
am force-stop "$pkgName"
[ ! -z "$revancedApp" ] || exit 2
[ ! -z "\$stock_path" ] || exit 2
umount -l "\$stock_path"
grep $pkgName /proc/mounts | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l
ln "$revancedApp" "\$stock_path"
am force-stop $pkgName
EOF

chmod 0744 "/data/adb/service.d/link_revanced_$pkgName.sh"
chmod 0744 "/data/adb/post-fs-data.d/unlink_revanced_$pkgName.sh"
