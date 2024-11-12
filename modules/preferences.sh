#!/usr/bin/bash

preferences() {
    PREFERENCES_ARRAY=("LIGHT_THEME" "$LIGHT_THEME" "PREFER_SPLIT_APK" "$PREFER_SPLIT_APK" "LAUNCH_APP_AFTER_MOUNT" "$LAUNCH_APP_AFTER_MOUNT" ALLOW_APP_VERSION_DOWNGRADE "$ALLOW_APP_VERSION_DOWNGRADE")

    readarray -t UPDATED_PREFERENCES < <("${DIALOG[@]}" \
        --title '| Preferences Menu |' \
        --no-items \
        --separate-output \
        --no-cancel \
        --ok-label 'Save' \
        --checklist "$NAVIGATION_HINT\n$SELECTION_HINT" -1 -1 -1 \
        "${PREFERENCES_ARRAY[@]}" \
        2>&1 > /dev/tty
    )

    sed -i "s|='on'|='off'|" .config

    for PREFERENCE in "${UPDATED_PREFERENCES[@]}"; do
        setEnv "$PREFERENCE" on update .config
    done

    source .config

    [ "$LIGHT_THEME" == "on" ] && THEME="LIGHT" || THEME="DARK"
    export DIALOGRC="$SRC/config/.DIALOGRC_$THEME"
    unset UPDATED_PREFERENCES THEME
}
