#!/usr/bin/bash


getInstalledVersion() {
    if su -c "pm list packages | grep -q $PKG_NAME" && [ "$ALLOW_APP_VERSION_DOWNGRADE" == "off" ]; then
        INSTALLED_VERSION=$(su -c dumpsys package "$PKG_NAME" | sed -n '/versionName/s/.*=//p' | sed -n '1p')
        if [ "$1" == "compare" ] && [ "$INSTALLED_VERSION" != "$SELECTED_VERSION" ]; then
            SORTED=$(jq -nrc --arg INSTALLED_VERSION "$INSTALLED_VERSION" --arg SELECTED_VERSION "$SELECTED_VERSION" '[$INSTALLED_VERSION, $SELECTED_VERSION] | sort | .[0]')
            if [ "$SORTED" != "$INSTALLED_VERSION" ]; then
                notify msg "The selected version $SELECTED_VERSION is lower then version $INSTALLED_VERSION installed on your device.\nPlease Select a higher version !!"
                return 1
            fi
        fi
    fi
}

mountApp() {
    notify info "Please Wait !!\nMounting $APP_NAME..."
    if su -mm -c "/system/bin/sh $SRC/root_scripts/mount.sh $PKG_NAME $APP_NAME $APP_VER" &> /dev/null; then
        notify msg "$APP_NAME Mounted Successfully !!"
    else
        notify msg "Installation Failed !!\n Share logs to developer."
        termux-open --send "$STORAGE/mount_log.txt"
        return 0
    fi
    if [ "$LAUNCH_APP_AFTER_MOUNT" == "on" ]; then
        su -c "settings list secure | sed -n -e 's/\/.*//' -e 's/default_input_method=//p' | xargs pidof | xargs kill -9 && pm resolve-activity --brief $PKG_NAME | tail -n 1 | xargs am start -n && pidof com.termux | xargs kill -9" &> /dev/null
    fi
}

unmountApp() {
    readarray -t MOUNTED_PKGS < <(su -c 'ls /data/local/tmp/revancify/* 2> /dev/null | xargs -I APK basename APK .apk')
    if [ ${#MOUNTED_PKGS[@]} == 0 ]; then
        notify msg "No mounted app present!!"
        return
    fi
    if ! PKG_NAME=$("${DIALOG[@]}" \
            --title '| Unmount App |' \
            --no-items \
            --ok-label 'Select' \
            --cancel-label 'Back' \
            --menu "$NAVIGATION_HINT" -1 -1 0 \
            "${MOUNTED_PKGS[@]}" \
            2>&1 > /dev/tty
    ); then
        return
    fi
    notify info "Unmounting $PKG_NAME..."
    sleep 1
    su -mm -c "/system/bin/sh $SRC/root_scripts/umount.sh $PKG_NAME" &> /dev/null
    notify msg "Unmount Successful !!"
    unset MOUNTED_PKGS PKG_NAME
}
