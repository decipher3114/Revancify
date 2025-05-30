#!/usr/bin/bash

getInstalledVersion() {
    if [ "$ROOT_ACCESS" == true ] && su -c "pm list packages | grep -q $PKG_NAME"; then
        INSTALLED_VERSION=$(su -c dumpsys package "$PKG_NAME" | sed -n '/versionName/s/.*=//p' | sed -n '1p')
    # We use pm list and dumpsys as fallback.
    elif [ "$RISH_ACCESS" = true ] && ( rish -c "pm list packages --user current | grep -q $PKG_NAME" || ! rish -c "dumpsys package $PKG_NAME" 2>&1 | grep -q "Unable to find package:" ); then
        INSTALLED_VERSION=$(rish -c "dumpsys package $PKG_NAME" | sed -n '/versionName/s/.*=//p' | sed -n '1p')
    fi
}

mountApp() {
    notify info "Please Wait !!\nMounting $APP_NAME..."
    if su -mm -c "/system/bin/sh system/mount.sh $PKG_NAME $APP_NAME $APP_VER $SOURCE" &> /dev/null; then
        notify msg "$APP_NAME Mounted Successfully !!"
    else
        notify msg "Installation Failed !!\nShare logs to developer."
        termux-open --send "$STORAGE/mount_log.txt"
        return 0
    fi
    if [ "$LAUNCH_APP_AFTER_MOUNT" == "on" ]; then
        su -c "settings list secure | sed -n -e 's/\/.*//' -e 's/default_input_method=//p' | xargs pidof | xargs kill -9 && pm resolve-activity --brief $PKG_NAME | tail -n 1 | xargs am start -n && pidof com.termux | xargs kill -9" &> /dev/null
    fi
}

umountApp() {
    local PKG_NAME
    readarray -t MOUNTED_PKGS < <(su -c 'ls /data/local/tmp/revancify | xargs basename -s ".apk" -a 2> /dev/null')
    if [ ${#MOUNTED_PKGS[@]} == 0 ]; then
        notify msg "No mounted app present!!"
        return
    fi
    if ! PKG_NAME=$(
        "${DIALOG[@]}" \
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
    su -mm -c "/system/bin/sh system/umount.sh $PKG_NAME" &> /dev/null
    notify msg "Unmount Successful !!"
    unset MOUNTED_PKGS PKG_NAME
}
