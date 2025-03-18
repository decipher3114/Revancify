#!/usr/bin/bash

changeSource() {
    local SELECTED_SOURCE SOURCES_INFO
    readarray -t SOURCES_INFO < <(jq -r --arg SOURCE "$SOURCE" '.[] | .source | ., if . == $SOURCE then "on" else "off" end' sources.json)
    SELECTED_SOURCE=$(
        "${DIALOG[@]}" \
            --title '| Source Selection Menu |' \
            --no-cancel \
            --no-items \
            --ok-label 'Done' \
            --radiolist "$NAVIGATION_HINT\n$SELECTION_HINT" -1 -1 0 \
            "${SOURCES_INFO[@]}" 2>&1 > /dev/tty
    )

    [ "$SOURCE" == "$SELECTED_SOURCE" ] && return
    SOURCE="$SELECTED_SOURCE"
    setEnv SOURCE "$SOURCE" update .config
    unset AVAILABLE_PATCHES APPS_INFO APPS_LIST ENABLED_PATCHES
}
