#!/usr/bin/bash

installAppRish() {
    log() {
        echo "- $1" >> "$STORAGE/rish_log.txt"
    }
    rm "$STORAGE/rish_log.txt"
    log "START INSTALL"

    local UNINSTALL_CURRENT_INSTALLATION=false
    local HIDDEN_APP_INSTALL=false

    # Case 1: App is installed in a different user with a different signature, we might need to uninstall the app from all users (if the system allows it)
    # Case 2: App is installed in the current user with a different signature, we might need to uninstall the app from all users or just the current user (if the system doesn't allow uninstalling from all users)
    # Case 3: We're installing a downgrade, no matter the signature, we need to uninstall the current app first, from current user, if it fails we can try to uninstall from all users
    # Case 4: Clean install, no app installed, we can proceed with the installation

    # Case 1 is literally the worst, and there's even cases where we cannot know if there's a hidden installation or not, so we need to ask the user if they want to uninstall the app from all users

    notify info "Please Wait !!\nInstalling $APP_NAME using Rish..."
    # Copy the patched APK to the storage
    CANONICAL_VER=${APP_VER//:/}
    local EXPORTED_APK_NAME="$APP_NAME-$CANONICAL_VER-$SOURCE"
    cp -f "apps/$APP_NAME/$APP_VER-$SOURCE.apk" "$STORAGE/Patched/$EXPORTED_APK_NAME.apk" &> /dev/null
    
    # Verify current installed version and signatures
    log "Checking if $PKG_NAME is installed"
    getInstalledVersion
    if [ "$INSTALLED_VERSION" != "" ]; then
        log "Installed version of $APP_NAME is $INSTALLED_VERSION"
        log "Verifying signatures..."
        local STOCK_APP_PATH
        if [ "$(rish -c 'pm list packages --user current | grep -q "'"$PKG_NAME"'" && echo Installed')" == "Installed" ]; then
            STOCK_APP_PATH=$(rish -c 'pm path --user current "'"$PKG_NAME"'" | sed -n "/base/s/package://p"')
        else
            # If the app is not installed in the current user, we try to get the stock app path from dumpsys
            # This means the app is installed in a different user
            STOCK_APP_PATH=$(rish -c 'dumpsys package "'"$PKG_NAME"'" | sed -n "s/^[[:space:]]*path: \(.*base\.apk\)/\1/p"')
            log "Dumpsys used to get stock app path, that means the app is installed but in a different user."
            HIDDEN_APP_INSTALL=true
        fi
        local STOCK_APP_SIGNATURE=$(keytool -printcert -jarfile "$STOCK_APP_PATH" 2>/dev/null | awk '/SHA256:/{print $2}' | tr -d ':')
        local PATCHED_APP_SIGNATURE=$(keytool -printcert -jarfile "apps/$APP_NAME/$APP_VER-$SOURCE.apk" 2>/dev/null | awk '/SHA256:/{print $2}' | tr -d ':')
        if [ "$STOCK_APP_SIGNATURE" != "$PATCHED_APP_SIGNATURE" ]; then
            log "Signature mismatch: We need to uninstall the current APP."
            if [ "$HIDDEN_APP_INSTALL" == true ]; then
                # Case 1: App is installed in a different user with a different signature
                # We can try the installation, but we cannot guarantee it will succeed, so we need to ask the user if they want to uninstall the app from all users
                # That can possibly fail.
                log "Case 1: App installed in a different user with a different signature, we'll try to install the app in current user."
            else
                # Case 2: App is installed in the current user with a different signature, we can uninstall it and proceed with the installation
                # We use a dialog to ask the user if they want to uninstall the current app
                dialog --backtitle 'Revancify' --defaultno \
                    --yesno "The current app has a different signature than the patched one.\n\nDo you want to uninstall the current app and proceed?" 12 45
                if [ $? -eq 0 ]; then
                    # User accepted to uninstall the current app for Case 2
                    # We will try to uninstall from curent user first, if it fails we will try to uninstall from all users
                    log "Case 2: User accepted to uninstall the current app for current user."
                    UNINSTALL_CURRENT_INSTALLATION=true
                else
                    # User declined to uninstall the current app for Case 2
                    log "Case 2: User declined to uninstall the current app."
                    notify msg "User declined to uninstall the current app.\n\nAborting installation...\n\nCopied patched $APP_NAME apk to Internal Storage..."
                    return 1
                fi
            fi
        else
            log "Signature match, we can upgrade the app."
        fi
    else
        log "No installed version found for $APP_NAME found, proceeding with installation."
    fi

    # Check if we're already due for uninstallation
    if [ "$UNINSTALL_CURRENT_INSTALLATION" == false ]; then
        log "Checking if it's a downgrade..."
        if jq -e '.[0] > .[1]' <<< "[\"${INSTALLED_VERSION:-0}\", \"$APP_VER\"]" &> /dev/null; then
            # Case 3: Installed version is greater than the new version, we are downgrading
            # We need to uninstall the current app first, from current user, if it fails we can try to uninstall from all users
            log "Case 3: Installed version $INSTALLED_VERSION is greater than the new version $APP_VER, we are downgrading."
            if [ "$ALLOW_APP_VERSION_DOWNGRADE" == "on" ]; then
                log "Case 3: Downgrades are allowed, asking user for permission to uninstall the current app."
                
                dialog --backtitle 'Revancify' --defaultno \
                    --yesno "The current app version $INSTALLED_VERSION is greater than the new version $APP_VER.\n\nDo you want to uninstall the current version and proceed with the downgrade?" 12 45

                if [ $? -eq 0 ]; then
                    log "Case 3: User agreed to uninstall for clean reinstall."
                    UNINSTALL_CURRENT_INSTALLATION=true
                else
                    log "Case 3: User decided not to uninstall to continue the downgrade. Aborting..."
                    notify msg "User declined to uninstall the current version.\n\nAborting installation...\n\nCopied patched $APP_NAME apk to Internal Storage..."
                    return 1
                fi
            else
                log "Case 3: Downgrades are not allowed, exiting."
                notify msg "Downgrades are not allowed in Configuration, exiting.\n\nCopied patched $APP_NAME apk to Internal Storage..."
                return 1
            fi
        else
            log "Case 4: No version conflict detected or signatures, proceeding with installation."
        fi
    fi

    if [ "$UNINSTALL_CURRENT_INSTALLATION" == true ]; then
        notify info "Please Wait !!\nUninstalling $APP_NAME $APP_VER using Rish..."
        if uninstallAppRish false true "$STORAGE"; then
            log "Uninstallation successful, proceeding with installation."
            if ! rish -c 'dumpsys package "'"$PKG_NAME"'"' 2>&1 | grep -q "Unable to find package"; then
                log "Found hidden installation post uninstallation. This might be a different user."
                HIDDEN_APP_INSTALL=true
            fi
        else
            log "Uninstallation failed."
            mesage="Failed to uninstall the current app.\n\nAborting installation...\n\nCopied patched $APP_NAME apk to Internal Storage..."
            return 1
        fi
    fi

    notify info "Please Wait !!\nInstalling $APP_NAME $APP_VER using Rish..."

    log "Attempting to install the patched APK..."
    if bash system/rish-install.sh "$PKG_NAME" "$APP_NAME" "$EXPORTED_APK_NAME" "$STORAGE"; then
        log "Installation command executed successfully."
        notify msg "$APP_NAME $APP_VER installed successfully using Rish!"
    elif [ "$HIDDEN_APP_INSTALL" == true ] ; then
        # Second attempt to install the APK, if we had to uninstall the current app
        log "First installation attempt failed, trying again after uninstallation."
    else
        log "Installation of $APP_NAME $APP_VER failed."
        notify msg "Installation Failed !!\nShare logs to developer."
        termux-open --send "$STORAGE/rish_log.txt"
        return 1
    fi

    if [ "$HIDDEN_APP_INSTALL" = true ]; then
        # We try to uninstall the app again, this can happen in Cases 1, 2, 3 if we have multiple users in the device with the app
        log "Getting second attempt, this can happen in Cases 1, 2, 3, if we have multiple users in the device with the app..."
        
        dialog --backtitle 'Revancify' --defaultno \
            --yesno "We coudn't install the App.\nA different user probably has an incompatible $APP_NAME app.\n\nDo you want to uninstall $APP_NAME from all users and proceed?\nWe cannot guarantee this will succeed..." 12 45
        if [ $? -eq 0 ]; then
            log "User accepted to uninstall the app from all users."
            # We try to uninstall the app from all users, this can fail if the system doesn't allow it
            notify info "Please Wait !!\nUninstalling $APP_NAME from all users using Rish..."
            if uninstallAppRish true true "$STORAGE"; then
                log "Uninstallation from all users successful, proceeding with installation."
                notify info "Please Wait !!\nInstalling $APP_NAME $APP_VER using Rish..."
                if bash system/rish-install.sh "$PKG_NAME" "$APP_NAME" "$EXPORTED_APK_NAME" "$STORAGE"; then
                    log "Installation command executed successfully after uninstallation from all users."
                    notify msg "$APP_NAME $APP_VER installed successfully using Rish!"
                else
                    log "Installation failed after uninstallation from all users."
                    notify msg "Installation Failed !!\nShare logs to developer. \n\nCopied patched $APP_NAME apk to Internal Storage..."
                    termux-open --send "$STORAGE/rish_log.txt"
                    return 1
                fi
            else
                log "Uninstallation from all users failed, aborting installation."
                notify msg "Failed to uninstall the app from all users.\n\nAborting installation...\n\nCopied patched $APP_NAME apk to Internal Storage..."
                return 1
            fi
        else
            log "User declined to uninstall the app from all users, aborting installation."
            notify msg "User declined to uninstall the app from all users.\n\nAborting installation...\n\nCopied patched $APP_NAME apk to Internal Storage..."
            return 1
        fi
    fi
    
    # If we reach this point, the installation was successful
    log "Installation of $APP_NAME $APP_VER completed successfully, finalized code."
    if [ "$LAUNCH_APP_AFTER_MOUNT" == "on" ]; then
        # The su version used kill -9, I replaced it with the adb command 'am force-stop' avaliable in rish
        rish -c 'settings list secure | sed -n -e "s/\/.*//" -e "s/default_input_method=//p" | xargs am force-stop && pm resolve-activity --brief '"$PKG_NAME"' | tail -n 1 | xargs am start -n && am force-stop com.termux'
    fi
    return 0
}

uninstallAppRish() {
    local UNINSTALL_FROM_ALL_USERS="$1"
    local KEEP_LOG="$2"

    log () {
        echo "- $1" >> "$STORAGE/rish_log.txt"
    }
    if [ "$KEEP_LOG" != true ] && [ -f "$STORAGE/rish_log.txt" ]; then
        rm "$STORAGE/rish_log.txt"
    fi


    if [ "$UNINSTALL_FROM_ALL_USERS" = true ]; then
        log "Uninstalling from all users..."
        if bash system/rish-uninstall.sh "$PKG_NAME" true "$STORAGE"; then
            return 0
        else
            return 1
        fi
    else
        log "Uninstalling from current user..."
        if bash system/rish-uninstall.sh "$PKG_NAME" false "$STORAGE"; then
            return 0
        else
            return 1
        fi
    fi
}