#!/usr/bin/bash

parsePatchesJson() {
    while [ ! -e "assets/$SOURCE/Patches-$PATCHES_VERSION.json" ]; do
        if [ -n "$JSON_URL" ]; then
            parseJsonFromAPI
            continue
        fi
        parseJsonFromCLI | "${DIALOG[@]}" --gauge "Please Wait!!\nParsing JSON file for $SOURCE patches from CLI Output.\nThis might take some time." -1 -1 0
        tput civis
    done

    [ -n "$AVAILABLE_PATCHES" ] || AVAILABLE_PATCHES=$(jq -rc '.' "assets/$SOURCE/Patches-$PATCHES_VERSION.json")

    [ -n "$ENABLED_PATCHES" ] || ENABLED_PATCHES=$(jq -erc '.' "$STORAGE/$SOURCE-patches.json" 2> /dev/null || echo '[]')

    while [ -z "$APPS_LIST" ]; do
        if [ -e "assets/$SOURCE/Apps-$PATCHES_VERSION.json" ]; then
            readarray -t APPS_LIST < <(
                jq -rc '
                    reduce .[] as $APP_INFO (
                        [];
                        if any(.[]; .[1] == $APP_INFO.appName) then
                            . += [[$APP_INFO, "\($APP_INFO.appName) [\($APP_INFO.pkgName)]"]] |
                            .[-2] |= (.[0] as $APP_INFO | .[1] as $APP_NAME | [$APP_INFO, "\($APP_NAME) [\($APP_INFO.pkgName)]"])
                        else
                            . += [[$APP_INFO, $APP_INFO.appName]]
                        end
                    ) |
                    .[][]
                ' "assets/$SOURCE/Apps-$PATCHES_VERSION.json"
            )
        fi
        if [ ${#APPS_LIST[@]} -eq 0 ]; then
            unset APPS_LIST
            rm assets/"$SOURCE"/Apps-*.json &> /dev/null
            fetchAppsInfo || return 1
        fi
    done
}
