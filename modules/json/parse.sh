#!/usr/bin/bash

parsePatchesJson() {
    while [ ! -e "$SOURCE-patches-$PATCHES_VERSION.json" ]; do
        if [ -n "$JSON_URL" ]; then
            parseJsonFromAPI
            continue
        fi
        parseJsonFromCLI | "${DIALOG[@]}" --gauge "Please Wait!!\nParsing JSON file for $SOURCE patches from CLI Output.\nThis might take some time." -1 -1 0
        tput civis
    done

    [ -n "$AVAILABLE_PATCHES" ] || AVAILABLE_PATCHES=$(jq -rc '.' "$SOURCE-patches-$PATCHES_VERSION.json")

    [ -n "$ENABLED_PATCHES" ] || ENABLED_PATCHES=$(jq -rc '.' "$STORAGE/$SOURCE-patches.json" 2> /dev/null || echo '[]')
    
    while [ -z "$APPS_LIST" ]; do
        if [ -e "$SOURCE-apps-$PATCHES_VERSION.json" ]; then
            readarray -t APPS_LIST < <(jq -rc '
                reduce .[] as {pkgName: $PKG_NAME, appName: $APP_NAME} (
                    [];
                    if any(.[]; .[1] == $APP_NAME) then
                        . += [[$PKG_NAME, "\($APP_NAME) [\($PKG_NAME)]"]] |
                        .[-2] |= (.[0] as $PKG_NAME | .[1] as $APP_NAME | [$PKG_NAME, "\($APP_NAME) [\($PKG_NAME)]"])
                    else
                        . += [[$PKG_NAME, $APP_NAME]]
                    end
                ) |
                .[][]' "$SOURCE-apps-$PATCHES_VERSION.json" 2> /dev/null
            )
        fi
        if [ ${#APPS_LIST[@]} -eq 0 ]; then
            unset APPS_LIST
            rm "$SOURCE"-apps-*.json 2> /dev/null
            fetchAppsInfo || return 1
        fi
    done
}
