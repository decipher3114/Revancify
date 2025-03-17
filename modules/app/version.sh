#!/usr/bin/bash

scrapeVersionsList() {
    local PAGE VERSIONS
    PAGE=$("${CURL[@]}" -A "$USER_AGENT" "https://www.apkmirror.com/uploads/?appcategory=$APKMIRROR_APP_NAME" 2>&1)

    if [ "$PAGE" == "" ]; then
        notify msg "Unable to fetch versions !!\nThere is some problem with your internet connection. Disable VPN or Change your network."
        TASK="CHOOSE_APP"
        return 1
    fi

    readarray -t VERSIONS_LIST < <(
        pup -c 'div.widget_appmanager_recentpostswidget div.listWidget div:not([class]) json{}' <<< "$PAGE" |
            jq -rc \
                --arg PKG_NAME "$PKG_NAME" \
                --arg INSTALLED_VERSION "$INSTALLED_VERSION" \
                --arg ALLOW_APP_VERSION_DOWNGRADE "$ALLOW_APP_VERSION_DOWNGRADE" \
                --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '
                (
                    $AVAILABLE_PATCHES[] |
                    select(.pkgName == $PKG_NAME) |
                    .versions
                ) as $SUPPORTED_VERSIONS |
                [
                    .[].children |
                    .[1].children.[0].children.[1].text as $VERSION |
                    .[0].children.[0].children.[1].children.[0].children.[0].children.[0] as $INFO |
                    {
                        "version": ($VERSION),
                        "tag": (
                            if ($SUPPORTED_VERSIONS | index($VERSION)) != null then
                                "[RECOMMENDED]"
                            else
                                (
                                    $INFO.text |
                                    if test("beta"; "i") then
                                        "[BETA]"
                                    elif test("alpha"; "i") then
                                        "[ALPHA]"
                                    else
                                        "[STABLE]"
                                    end
                                )
                            end
                        ),
                        "url": $INFO.href
                    }
                ] |
                if $INSTALLED_VERSION != "" then
                    if ($ALLOW_APP_VERSION_DOWNGRADE | test("off")) then
                        .[0:(map(.version == $INSTALLED_VERSION) | index(true) + 1)]
                    end |
                    map(
                        if .version == $INSTALLED_VERSION then
                            .tag |= "[INSTALLED]"
                        end
                    )
                end |
                (
                    if any(.[]; .tag == "[RECOMMENDED]") then
                        (first(.[] | select(.tag == "[RECOMMENDED]"))), "Auto Select|[RECOMMENDED]"
                    elif $INSTALLED_VERSION != "" then
                        .[-1], "Auto Select|[INSTALLED]"
                    else
                        empty
                    end,
                    (
                        .[] |
                        ., "\(.version)|\(.tag)"
                    )
                )
            '
    )
}

chooseVersion() {
    unset APP_VER APP_DL_URL
    local INSTALLED_VERSION SELECTED_VERSION
    internet || return 1
    getInstalledVersion
    if [ "${#VERSIONS_LIST[@]}" -eq 0 ]; then
        notify info "Please Wait !!\nScraping versions list for $APP_NAME from apkmirror.com..."
        scrapeVersionsList || return 1
    fi
    if ! SELECTED_VERSION=$(
        "${DIALOG[@]}" \
            --title '| Version Selection Menu |' \
            --no-tags \
            --column-separator "|" \
            --default-item "$SELECTED_VERSION" \
            --ok-label 'Select' \
            --cancel-label 'Back' \
            --menu "$NAVIGATION_HINT" -1 -1 0 \
            "${VERSIONS_LIST[@]}" \
            2>&1 > /dev/tty
    ); then
        TASK="CHOOSE_APP"
        return 1
    fi
    APP_VER=$(jq -nrc --argjson SELECTED_VERSION "$SELECTED_VERSION" '$SELECTED_VERSION.version | sub(" "; ""; "g")')
    APP_DL_URL=$(jq -nrc --argjson SELECTED_VERSION "$SELECTED_VERSION" '"https://www.apkmirror.com" + $SELECTED_VERSION.url')
}
