#!/system/bin/sh

PKG_NAME="$1"
APP_NAME="$2"
APP_VER="$3"
SOURCE="$4"

log() {
    echo "- $1" >> "/storage/emulated/0/Revancify/mount_log.txt"
}

rm "/storage/emulated/0/Revancify/mount_log.txt"

log "START"

for DIR in /data/local/tmp/revancify/ /data/adb/post-fs-data.d/ /data/adb/service.d/; do
    if [ ! -e $DIR ]; then
        mkdir "$DIR"
        log "$DIR created."
    fi
done

for FILE in "/data/adb/post-fs-data.d/umount_$PKG_NAME.sh" "/data/adb/service.d/mount_$PKG_NAME.sh" "/data/local/tmp/revancify/$PKG_NAME.apk"; do
    if [ -e "$FILE" ]; then
        rm "$FILE"
        log "$FILE deleted."
    fi
done

log "Checking if $APP_NAME $APP_VER is installed"
if ! (pm list packages | grep -q "$PKG_NAME" && [ "$(dumpsys package "$PKG_NAME" | sed -n '/versionName/s/.*=//p' | sed 's/ /./1p')" = "$APP_VER" ]); then

    log "$APP_NAME $APP_VER is NOT installed !!"
    log "Installing $APP_NAME $APP_VER..."

    if [ -e "apps/$APP_NAME/$APP_VER" ]; then
        pm install --user 0 -r "apps/$APP_NAME/$APP_VER/"*
        log "$APP_NAME $APP_VER [split] installed."
    else
        pm install --user 0 -r "apps/$APP_NAME/$APP_VER.apk"
        log "$APP_NAME $APP_VER installed."
    fi
fi

if ! pm list packages | grep -q "$PKG_NAME"; then
    log "$APP_NAME $APP_VER installation failed !!"
    log "Exit !!"
    exit 1
fi

STOCK_APP_PATH=$(pm path "$PKG_NAME" | sed -n "/base/s/package://p")
PATCHED_APP_PATH="/data/local/tmp/revancify/$PKG_NAME.apk"

log "Force stopping..."
am force-stop "$PKG_NAME"

log "Unmounting previous mounts..."
grep "$PKG_NAME" /proc/mounts | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l

log "Copying apk to $PATCHED_APP_PATH..."
cp -f "apps/$APP_NAME/$APP_VER-$SOURCE.apk" "$PATCHED_APP_PATH"
if [ ! -e "$PATCHED_APP_PATH" ]; then
    log "Path: $PATCHED_APP_PATH does not exist !!"
    log "Exit !!"
    exit 1
fi

log "Setting up permissions..."
chmod 644 "$PATCHED_APP_PATH"
chown system:system "$PATCHED_APP_PATH"
chcon u:object_r:apk_data_file:s0 "$PATCHED_APP_PATH"

log "Mounting app..."
mount -o bind "$PATCHED_APP_PATH" "$STOCK_APP_PATH"

if ! grep -q "$PKG_NAME" /proc/mounts; then
    log "Mount failed !!"
    log "Exit !!"
    exit 1
fi

log "Force stopping..."
am force-stop "$PKG_NAME"

log "Clearing cache..."
pm clear --cache-only "$PKG_NAME"

log "Creating boot scripts..."
cat << EOF > "/data/adb/service.d/mount_$PKG_NAME.sh"
#!/system/bin/sh
while [ "\$(getprop sys.boot_completed | tr -d '\r')" != "1" ]; do sleep 5; done

BASE_PATH="$PATCHED_APP_PATH"
STOCK_PATH="\$(pm path $PKG_NAME | sed -n '/base/s/package://p')"
am force-stop "$PKG_NAME"
chcon u:object_r:apk_data_file:s0 "\$BASE_PATH"
[ ! -z "\$STOCK_PATH" ] && mount -o bind "\$BASE_PATH" "\$STOCK_PATH"
am force-stop "$PKG_NAME"
EOF

cat << EOF > "/data/adb/post-fs-data.d/umount_$PKG_NAME.sh"
#!/system/bin/sh
STOCK_PATH="\$(pm path "$PKG_NAME" | sed -n '/base/s/package://p')"
[ ! -z "\$STOCK_PATH" ] && umount -l "\$STOCK_PATH"
grep "$PKG_NAME" /proc/mounts | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l
EOF

chmod 0755 "/data/adb/service.d/mount_$PKG_NAME.sh"
chmod 0755 "/data/adb/post-fs-data.d/umount_$PKG_NAME.sh"

log "Install Successful."
log "End."

exit 0
