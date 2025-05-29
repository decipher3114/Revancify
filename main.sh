#!/usr/bin/bash

main() {

    setEnv SOURCE "ReVanced" init .config
    setEnv LIGHT_THEME "off" init .config
    setEnv PREFER_SPLIT_APK "on" init .config
    setEnv LAUNCH_APP_AFTER_MOUNT "on" init .config
    setEnv ALLOW_APP_VERSION_DOWNGRADE "off" init .config
    source .config

    mkdir -p "assets" "apps" "$STORAGE" "$STORAGE/Patched" "$STORAGE/Stock"

    [ "$ROOT_ACCESS" == true ] && MENU_ENTRY=(7 "Unmount Patched app")

    [ "$LIGHT_THEME" == "on" ] && THEME="LIGHT" || THEME="DARK"
    export DIALOGRC="config/.DIALOGRC_$THEME"

    while true; do
        MAIN=$(
            "${DIALOG[@]}" \
                --title '| Main Menu |' \
                --ok-label 'Select' \
                --cancel-label 'Exit' \
                --menu "$NAVIGATION_HINT" -1 -1 0 1 "Patch App" 2 "Update Assets" 3 "Change Source" 4 "Configure" 5 "Delete Assets" 6 "Delete Apps" "${MENU_ENTRY[@]}" \
                2>&1 > /dev/tty
        ) || break
        case "$MAIN" in
            1)
                initiateWorkflow
                ;;
            2)
                fetchAssetsInfo || break
                fetchAssets
                ;;
            3)
                changeSource
                ;;
            4)
                configure
                ;;
            5)
                deleteAssets
                ;;
            6)
                deleteApps
                ;;
            7)
                umountApp
                ;;
        esac
    done
}

tput civis
ROOT_ACCESS="$1"
RISH_ACCESS="$2"

for MODULE in $(find modules -type f -name "*.sh"); do
    source "$MODULE"
done

trap terminate SIGTERM SIGINT SIGABRT
main || terminate 1
terminate "$?"
