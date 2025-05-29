#!/usr/bin/bash

installAppRish() {
    notify info "Please Wait !!\nInstalling $APP_NAME using Rish..."
    if installerRish ; then
        notify msg "$APP_NAME Installed Successfully using Rish!!"
    else
        notify msg "Installation Failed using Rish !!\nShare logs to developer."
        termux-open --send "$STORAGE/mount_log.txt"
        return 0
    fi
    if [ "$LAUNCH_APP_AFTER_MOUNT" == "on" ]; then
        # The su version used kill -9, I replaced it with the adb command 'am force-stop' avaliable in rish
        rish -c 'settings list secure | sed -n -e "s/\/.*//" -e "s/default_input_method=//p" | xargs am force-stop && pm resolve-activity --brief '"$PKG_NAME"' | tail -n 1 | xargs am start -n && am force-stop com.termux'
    fi
}

installerRish() {
    local INSTALL_DOWNGRADE=false
    local UNINSTALL_STOCK=false

    log() {
        echo "- $1" >> "$STORAGE/mount_log.txt"
    }

    rm "$STORAGE/mount_log.txt"

    log "START"

    log "Checking if $PKG_NAME is installed"
    # Chech the signatures to see if we can upgrade the app or if we need to uninstall the current app first.
    if [ "$(rish -c 'pm list packages --user 0 | grep -q "'"$PKG_NAME"'" && echo Installed')" == "Installed" ]; then
        log "$APP_NAME is installed, checking signature..."
        local STOCK_APP_PATH=$(rish -c 'pm path "'"$PKG_NAME"'" | sed -n "/base/s/package://p"')
        local STOCK_APP_SIGNATURE=$(keytool -printcert -jarfile "$STOCK_APP_PATH" 2>/dev/null | awk '/SHA256:/{print $2}' | tr -d ':')
        local PATCHED_APP_SIGNATURE=$(keytool -printcert -jarfile "apps/$APP_NAME/$APP_VER-$SOURCE.apk" 2>/dev/null | awk '/SHA256:/{print $2}' | tr -d ':')

        log "Current APP signature is:"
        log "$STOCK_APP_SIGNATURE"
        log "Patched APK signature is:"
        log "$PATCHED_APP_SIGNATURE"

        if [ "$STOCK_APP_SIGNATURE" != "$PATCHED_APP_SIGNATURE" ]; then
            log "Signature mismatch: We need to uninstall the current APP."

            dialog --backtitle 'Revancify' \
                --yesno "The current app has a different signature than the patched one.\n\nDo you want to uninstall the current app and proceed?" 12 45

            if [ $? -eq 0 ]; then
                UNINSTALL_STOCK=true
                notify info "Please Wait !!\nInstalling $APP_NAME using Rish..."
            else
                notify msg "User canceled the uninstallation.\n\nAborting..."
                return 1
            fi
        else
            log "Signature match, we can upgrade the app."
        fi
    else
        log "$APP_NAME is NOT installed, we can install the patched APK directly."
    fi

    log "Copying patched APK to file system..."
    # Rish can't access termux directories, so we copy the APK to storage, this is the same as when there's no root or rish
    # I decided to keep CANONICAL_VER because that's the format used in the non su version, although it'll be changed anyway.
    CANONICAL_VER=${APP_VER//:/}
    cp -f "apps/$APP_NAME/$APP_VER-$SOURCE.apk" "$STORAGE/Patched/$APP_NAME-$CANONICAL_VER-$SOURCE.apk"

    if [ ! -e "$STORAGE/Patched/$APP_NAME-$CANONICAL_VER-$SOURCE.apk" ]; then
        log "Failed to copy patched APK to $STORAGE/Patched/$APP_NAME-$CANONICAL_VER-$SOURCE.apk"
        return 1
    else 
        log "Copied patched APK to $STORAGE/Patched/"
    fi

    log "Checking if it's a downgrade..."
    ## This is the same as before
    getInstalledVersion
    if jq -e '.[0] > .[1]' <<< "[\"${INSTALLED_VERSION:-0}\", \"$APP_VER\"]" &> /dev/null; then
        log "Installed version $INSTALLED_VERSION is greater than the new version $APP_VER, skipping installation."
        if [ "$ALLOW_APP_VERSION_DOWNGRADE" == "on" ]; then
            INSTALL_DOWNGRADE=true
            log "Downgrades are allowed, proceeding with installation."
            notify info "Please Wait !!\nInstalling $APP_NAME using Rish...\n\nDowngrading to version $APP_VER"
        else
            log "Downgrades are not allowed, exiting."
            notify msg "Downgrades are not allowed in Configuration, exiting."
            return 1
        fi
    else
        log "No version conflict detected, proceeding with installation."
    fi

    # It's needed for pm install to have the APK in the /data/local/tmp/ directory
    local PATCHED_APP_PATH="/data/local/tmp/revancify/$PKG_NAME.apk"

    # This is almost the same as the mouth.sh script from the su version.
    if [ "$(rish -c '[ -d "/data/local/tmp/revancify" ] && echo Exists || echo Missing')" == "Missing" ]; then
        rish -c 'mkdir "/data/local/tmp/revancify"'
        log "/data/local/tmp/revancify created."
    else
        log "/data/local/tmp/revancify already exists."
    fi

    # Named the same as the su version, maybe so people can choose to use su or rish, idk.
    if [ "$(rish -c '[ -e "'"$PATCHED_APP_PATH"'" ] && echo Exists || echo Missing')" == "Exists" ]; then
        rish -c 'rm "'"$PATCHED_APP_PATH"'"'
        log "Residual $PATCHED_APP_PATH deleted"
    else
        log "Residual $PATCHED_APP_PATH does not exist, skipping deletion."
    fi

    log "Moving patched APK to /data/local/tmp/revancify..."
    local ABSOLUTE_PATCHED_APP_PATH="/storage/emulated/0/Revancify/Patched/$APP_NAME-$CANONICAL_VER-$SOURCE.apk"

    rish -c 'mv "'"$ABSOLUTE_PATCHED_APP_PATH"'" "'"$PATCHED_APP_PATH"'"'

    if [ "$(rish -c '[ -e "'"$PATCHED_APP_PATH"'" ] && echo Exists || echo Missing')" == "Missing" ]; then
        log "Failed to move patched APK to $PATCHED_APP_PATH"
        return 1
    else
        log "Moved patched APK to $PATCHED_APP_PATH"
    fi
    
    if [ "$UNINSTALL_STOCK" == true ]; then
        log "Uninstalling stock $APP_NAME..."
        local UNINSTALL_RESULT=$(rish -c 'pm uninstall --user 0 "'"$PKG_NAME"'"')
        log "Uninstall log: $UNINSTALL_RESULT"
        log "Stock $APP_NAME uninstalled."
    fi
    
    if [ "$INSTALL_DOWNGRADE" == true ]; then
        log "Installing $APP_NAME $APP_VER with downgrade..."
        local INSTALL_RESULT=$(rish -c 'pm install --user 0 -r -d "'"$PATCHED_APP_PATH"'"')
        log "pm install result: $INSTALL_RESULT"
        if echo "$INSTALL_RESULT" | grep -q "INSTALL_FAILED_VERSION_DOWNGRADE"; then
            log "Downgrade failed, trying full uninstall and reinstall..."
            local UNINSTALL_RESULT=$(rish -c 'pm uninstall --user 0 "'"$PKG_NAME"'"')
            log "Uninstall result: $UNINSTALL_RESULT"
            INSTALL_RESULT=$(rish -c 'pm install --user 0 -r "'"$PATCHED_APP_PATH"'"')
            log "Final install result: $INSTALL_RESULT"
        fi
    else
        log "Installing $APP_NAME $APP_VER withouth downgrading..."
        local INSTALL_RESULT=$(rish -c 'pm install --user 0 -r "'"$PATCHED_APP_PATH"'"')
        log "pm install result: $INSTALL_RESULT"
    fi

    log "Removing patched APK from /data/local/tmp/revancify..."
    rish -c 'rm "'"$PATCHED_APP_PATH"'"'

    getInstalledVersion
    local PACKAGE_INSTALLED=$(rish -c 'pm list packages --user 0 | grep -q "'"$PKG_NAME"'" && echo OK')

    if [ "$PACKAGE_INSTALLED" == "OK" ] && \
    jq -e '.[0] == .[1]' <<< "[\"${INSTALLED_VERSION:-0}\", \"$APP_VER\"]" &> /dev/null; then
        log "Installed $APP_NAME $APP_VER successfully."
    else
        log "Failed to install $PKG_NAME $APP_VER."
        log "Current installed version is $INSTALLED_VERSION."
        return 1
    fi

}