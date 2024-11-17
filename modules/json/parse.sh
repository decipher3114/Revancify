#!/usr/bin/bash

parsePatchesJson() {
    if [ ! -e "$SOURCE-patches-$PATCHES_VERSION.json" ]; then
        if [ "$JSON_URL" == "" ]; then
            parseJsonFromCLI | 
            "${DIALOG[@]}" --gauge "Please Wait!!\nParsing JSON file for $SOURCE patches from CLI Output.\nThis might take some time." -1 -1 0
            tput civis
        else
            notify info "Please Wait!!\nParsing JSON file for $SOURCE patches from API."
            if ! parseJsonFromAPI; then
                return 1
            fi
        fi
        fetchAppsInfo || return 1
    fi

    if [ ! -e "$SOURCE-apps.json" ]; then
        fetchAppsInfo || return 1
    fi

    [ -n "$AVAILABLE_PATCHES" ] || AVAILABLE_PATCHES=$(jq -rc '.' "$SOURCE-patches-$PATCHES_VERSION.json")
    [ -n "$APPS_INFO" ] || APPS_INFO=$(jq -rc '.' "$SOURCE-apps.json")
    [ -n "$APPS_LIST" ] || readarray -t APPS_LIST < <(jq -nrc --argjson APPS_INFO "$APPS_INFO" '
        reduce $APPS_INFO[] as {pkgName: $PKG_NAME, appName: $APP_NAME} (
            [];
            if any(.[]; .[1] == $APP_NAME) then
                . += [[$PKG_NAME, "\($APP_NAME) [\($PKG_NAME)]"]] |
                .[-2] |= (.[0] as $PKG_NAME | .[1] as $APP_NAME | [$PKG_NAME, "\($APP_NAME) [\($PKG_NAME)]"])
            else
                . += [[$PKG_NAME, $APP_NAME]]
            end
        ) |
        .[][]'
    )
    [ -n "$ENABLED_PATCHES" ] || ENABLED_PATCHES=$(jq -rc '.' "$STORAGE/$SOURCE-patches.json" 2> /dev/null || echo '[]')
}
