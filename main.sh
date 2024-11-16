#!/usr/bin/bash

SRC=$(dirname "$0")
ROOT_ACCESS="$1"

main() {

    mkdir -p "$STORAGE" "$STORAGE/Patched" "$STORAGE/Stock"
    mkdir -p apps

    [ "$ROOT_ACCESS" == true ] && MENU_ENTRY=(6 "Uninstall Patched app")

    [ "$LIGHT_THEME" == "on" ] && THEME="LIGHT" || THEME="DARK"
    export DIALOGRC="$SRC/config/.DIALOGRC_$THEME"

    if [ -e .assets ]; then
        source .assets
    else
        fetchAssetsInfo
    fi

    while true; do
        unset APP_VER APP_NAME PKG_NAME VERSIONS_LIST
        MAIN=$("${DIALOG[@]}" \
            --title '| Main Menu |' \
            --default-item "$mainMenu" \
            --ok-label 'Select' \
            --cancel-label 'Exit' \
            --menu "$NAVIGATION_HINT" -1 -1 0 1 "Patch App" 2 "Update Assets" 3 "Change Source" 4 "Preferences" 5 "Delete Assets" "${MENU_ENTRY[@]}" \
            2>&1 > /dev/tty
        ) || break
        case "$MAIN" in
        1 )
            TASK="CHOOSE_APP"
            initiateWorkflow
            ;;
        2 )
            fetchAssetsInfo || break
            fetchAssets
            ;;
        3 )
            changeSource
            ;;
        4 )
            preferences
            ;;
        5 )
            if "${DIALOG[@]}" \
                    --title '| Delete Tools |' \
                    --defaultno \
                    --yesno "Please confirm to delete the assets.\nIt will delete the CLI and $SOURCE patches." -1 -1\
            ; then
                rm ReVanced-cli-*.jar &> /dev/null
                rm "$SOURCE"-patches-*.rvp &> /dev/null
            fi
            ;;
        6 )
            umountApp
            ;;
        esac
    done
}

for MODULE in $(find "$SRC/modules" -type f -name "*.sh"); do
    source "$MODULE"
done

setEnv LIGHT_THEME "off" init .config
setEnv PREFER_SPLIT_APK "on" init .config
setEnv LAUNCH_APP_AFTER_MOUNT "on" init .config
setEnv ALLOW_APP_VERSION_DOWNGRADE "off" init .config
source .config

trap terminate SIGTERM SIGINT SIGABRT
main
terminate "$?"
