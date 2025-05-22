#!/usr/bin/bash

scrapeVersionsList() {
    local PAGE_CONTENTS PAGE_JSON MERGED_JSON
    local IDX MAX_PAGE_COUNT

    MAX_PAGE_COUNT=5

    for ((IDX = 1; IDX <= MAX_PAGE_COUNT; IDX++)); do
        TMP_FILES[IDX]=$(mktemp)
        "${CURL[@]}" -A "$USER_AGENT" "https://www.apkmirror.com/uploads/page/$IDX/?appcategory=$APKMIRROR_APP_NAME" > "${TMP_FILES[$IDX]}" 2> /dev/null &
    done
    wait

    for ((IDX = 1; IDX <= MAX_PAGE_COUNT; IDX++)); do
        PAGE_CONTENTS[IDX]=$(cat "${TMP_FILES[$IDX]}")
        rm -f "${TMP_FILES[$IDX]}"
    done

    for ((IDX = 1; IDX <= MAX_PAGE_COUNT; IDX++)); do
        PAGE_JSON[IDX]=$(
            pup -c 'div.widget_appmanager_recentpostswidget div.listWidget div:not([class]) json{}' <<< "${PAGE_CONTENTS[$IDX]}" |
                jq -rc '
                .[].children as $CHILDREN |
                {
                    version: $CHILDREN[1].children[0].children[1].text,
                    info: $CHILDREN[0].children[0].children[1].children[0].children[0].children[0]
                } |
                {
                    version: .version,
                    tag: (
                        .info.text | ascii_downcase |
                        if test("beta") then
                            "[BETA]"
                        elif test("alpha") then
                            "[ALPHA]"
                        else
                            "[STABLE]"
                        end
                    ),
                    url: .info.href
                }
            '
        )
    done

    MERGED_JSON=$(jq -s '.' <<< "$(printf '%s\n' "${PAGE_JSON[@]}")")

    if [[ "$MERGED_JSON" == "[]" ]]; then
        notify msg "Unable to fetch versions !!\nThere is some problem with your internet connection. Disable VPN or Change your network."
        TASK="CHOOSE_APP"
        return 1
    fi

    readarray -t VERSIONS_LIST < <(
        jq -rc \
            --arg PKG_NAME "$PKG_NAME" \
            --arg INSTALLED_VERSION "$INSTALLED_VERSION" \
            --arg ALLOW_APP_VERSION_DOWNGRADE "$ALLOW_APP_VERSION_DOWNGRADE" \
            --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '
            . as $ALL_VERSIONS |
            (
                $AVAILABLE_PATCHES[] |
                select(.pkgName == $PKG_NAME) |
                .versions
            ) as $SUPPORTED_VERSIONS |
            $ALL_VERSIONS |
            map(
                .version as $VERSION |
                if ($SUPPORTED_VERSIONS | index($VERSION)) != null then
                    .tag = "[RECOMMENDED]"
                elif .version == $INSTALLED_VERSION then
                    .tag = "[INSTALLED]"
                else
                    .
                end
            ) |
            (
                if any(.[]; .tag == "[RECOMMENDED]") then
                    (first(.[] | select(.tag == "[RECOMMENDED]"))), "Auto Select|[RECOMMENDED]"
                elif $INSTALLED_VERSION != "" then
                    .[-1], "Auto Select|[INSTALLED]"
                else
                    empty
                end
            ),
            (
                .[] |
                ., "\(.version)|\(.tag)"
            )
        ' <<< "$MERGED_JSON"
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
