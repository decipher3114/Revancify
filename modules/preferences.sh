#!/usr/bin/bash

configure() {
    local CONFIG_OPTS UPDATED_CONFIG THEME
    CONFIG_OPTS=("LIGHT_THEME" "$LIGHT_THEME" "PREFER_SPLIT_APK" "$PREFER_SPLIT_APK" "LAUNCH_APP_AFTER_MOUNT" "$LAUNCH_APP_AFTER_MOUNT" ALLOW_APP_VERSION_DOWNGRADE "$ALLOW_APP_VERSION_DOWNGRADE")

    readarray -t UPDATED_CONFIG < <(
        "${DIALOG[@]}" \
            --title '| Configure |' \
            --no-items \
            --separate-output \
            --no-cancel \
            --ok-label 'Save' \
            --checklist "$NAVIGATION_HINT\n$SELECTION_HINT" -1 -1 -1 \
            "${CONFIG_OPTS[@]}" \
            2>&1 > /dev/tty
    )

    sed -i "s|='on'|='off'|" .config

    for CONFIG_OPT in "${UPDATED_CONFIG[@]}"; do
        setEnv "$CONFIG_OPT" on update .config
    done

    source .config

    [ "$LIGHT_THEME" == "on" ] && THEME="LIGHT" || THEME="DARK"
    export DIALOGRC="config/.DIALOGRC_$THEME"
}
