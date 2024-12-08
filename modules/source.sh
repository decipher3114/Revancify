#!/usr/bin/bash

changeSource() {
    local SELECTED_SOURCE
    [ -n "$SOURCES" ] || readarray -t SOURCES < <(jq -r --arg SOURCE "$SOURCE" '.[] | .source | ., if . == $SOURCE then "on" else "off" end' "$SRC"/sources.json)
    SELECTED_SOURCE=$("${DIALOG[@]}" \
        --title '| Source Selection Menu |' \
        --no-cancel \
        --no-items \
        --ok-label 'Done' \
        --radiolist "$NAVIGATION_HINT\n$SELECTION_HINT" -1 -1 0 \
        "${SOURCES[@]}" 2>&1 > /dev/tty
    )

    [ "$SOURCE" == "$SELECTED_SOURCE" ] && return
    SOURCE="$SELECTED_SOURCE"
    unset AVAILABLE_PATCHES APPS_INFO APPS_LIST AVAILABLE_PATCHES
    fetchAssetsInfo || return 1
}
