#!/system/bin/sh

PKG_NAME="$1"
APP_NAME="$2"
APP_VER="$3"
SOURCE="$4"

[ -e /data/local/tmp/revancify/ ] || mkdir -p /data/local/tmp/revancify/
[ -e /data/adb/post-fs-data.d/ ] || mkdir -p /data/adb/post-fs-data.d/
[ -e /data/adb/service.d/ ] || mkdir -p /data/adb/service.d/

[ -e "/data/adb/post-fs-data.d/umount_$PKG_NAME.sh" ] && rm "/data/adb/post-fs-data.d/umount_$PKG_NAME.sh"
[ -e "/data/adb/service.d/mount_$PKG_NAME.sh" ] && rm "/data/adb/service.d/mount_$PKG_NAME.sh"
[ -e "/data/local/tmp/revancify/$PKG_NAME.apk" ] && rm "/data/local/tmp/revancify/$PKG_NAME.apk"


if ! (pm list packages | grep -q "$PKG_NAME" && [ "$(dumpsys package "$PKG_NAME" | sed -n '/versionName/s/.*=//p' | sed 's/ /./1p')" = "$APP_VER" ]); then
    if [ -e "apps/$APP_NAME/$APP_VER" ]; then
        pm install --user 0 -r "apps/$APP_NAME/$APP_VER/"*
    else
        pm install --user 0 -r "apps/$APP_NAME/$APP_VER.apk"
    fi
fi

pm list packages | grep -q "$PKG_NAME" || exit 1

STOCK_APP_PATH=$(pm path "$PKG_NAME" | sed -n "/base/s/package://p")
PATCHED_APP_PATH="/data/local/tmp/revancify/$PKG_NAME.apk"

am force-stop "$PKG_NAME"

{
    grep "$PKG_NAME" /proc/mounts | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -vl
    cp -vf "apps/$APP_NAME/$APP_VER-$SOURCE.apk" "$PATCHED_APP_PATH"
    chmod -v 644 "$PATCHED_APP_PATH" && chown -v system:system "$PATCHED_APP_PATH"
    chcon -v u:object_r:apk_data_file:s0 "$PATCHED_APP_PATH"
    mount -vo bind "$PATCHED_APP_PATH" "$STOCK_APP_PATH"
} > /storage/emulated/0/Revancify/mount_log.txt 2>&1

am force-stop "$PKG_NAME"
pm clear --cache-only "$PKG_NAME"

grep -q "$PKG_NAME" /proc/mounts || exit 1

cat <<EOF >"/data/adb/service.d/mount_$PKG_NAME.sh"
#!/system/bin/sh
while [ "\$(getprop sys.boot_completed | tr -d '\r')" != "1" ]; do sleep 5; done

BASE_PATH="$PATCHED_APP_PATH"
STOCK_PATH="\$(pm path $PKG_NAME | sed -n '/base/s/package://p')"
am force-stop "$PKG_NAME"
chcon u:object_r:apk_data_file:s0 "\$BASE_PATH"
[ ! -z "\$STOCK_PATH" ] && mount -o bind "\$BASE_PATH" "\$STOCK_PATH"
am force-stop "$PKG_NAME"
pm clear --cache-only "$PKG_NAME"
EOF

cat <<EOF >"/data/adb/post-fs-data.d/umount_$PKG_NAME.sh"
#!/system/bin/sh
STOCK_PATH="\$(pm path "$PKG_NAME" | sed -n '/base/s/package://p')"
[ ! -z "\$STOCK_PATH" ] && umount -l "\$STOCK_PATH"
grep "$PKG_NAME" /proc/mounts | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l
EOF

chmod 0755 "/data/adb/service.d/mount_$PKG_NAME.sh"
chmod 0755 "/data/adb/post-fs-data.d/umount_$PKG_NAME.sh"

exit 0
