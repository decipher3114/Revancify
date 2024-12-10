#!/usr/bin/bash

scrapeVersionsList() {
    local PAGE VERSIONS
    PAGE=$("${CURL[@]}" -A "$USER_AGENT" "https://www.apkmirror.com/uploads/?appcategory=$APKMIRROR_APP_NAME" 2>&1)

    if [ "$PAGE" == "" ]; then
        notify msg "Unable to fetch versions !!\nThere is some problem with your internet connection. Disable VPN or Change your network."
        TASK="CHOOSE_APP"
        return 1
    fi

    readarray -t VERSIONS < <(pup -p 'div.widget_appmanager_recentpostswidget h5 a.fontBlack text{}' <<<"$PAGE")

    readarray -t VERSIONS_LIST < <(jq -nrc --arg APP_NAME "$APP_NAME-"\
        --arg INSTALLED_VERSION "$INSTALLED_VERSION"\
        --argjson SUPPORTED_VERSIONS "$SUPPORTED_VERSIONS"\
        '($INSTALLED_VERSION | sub(" *[-, ] *"; "-"; "g")) as $INSTALLED_VERSION |
        [
            [
                $ARGS.positional[] |
                sub("( -)|( &)"; ""; "g") |
                sub("[()\\|]"; ""; "g") |
                sub(" *[-, ] *"; "-"; "g") |
                sub($APP_NAME; "")
            ] |
            . |= . + $SUPPORTED_VERSIONS |
            unique |
            reverse |
            index($INSTALLED_VERSION) as $index |
            if $index == null then
                .[]
            else
                .[0:($index + 1)][]
            end | . as $VERSION |
            if (($SUPPORTED_VERSIONS | index($VERSION)) != null) then
                $VERSION, "[RECOMMENDED]"
            elif ($VERSION | test("beta|Beta|BETA")) then
                $VERSION | sub("(?<=[0-9])-[a-zA-Z]*$"; ""), "[BETA]"
            elif ($VERSION | test("alpha|Alpha|ALPHA")) then
                $VERSION | sub("(?<=[0-9])-[a-zA-Z]*$"; ""), "[ALPHA]"
            else
                $VERSION, "[STABLE]"
            end
        ] |
        if (. | index($INSTALLED_VERSION)) != null then
            .[-1] |= "[INSTALLED]"
        else
            .
        end |
        if ((. | index("[RECOMMENDED]")) != null) then
            . |= ["Auto Select", "[RECOMMENDED]"] + .
        else
            .
        end | 
        .[]' --args "${VERSIONS[@]}"
    )
}

chooseVersion() {
    unset APP_VER
    local INSTALLED_VERSION SUPPORTED_VERSIONS SELECTED_VERSION
    internet || return 1
    SUPPORTED_VERSIONS=$(jq -nc --arg PKG_NAME "$PKG_NAME" --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '
        [
            $AVAILABLE_PATCHES[] |
            select(.pkgName == $PKG_NAME) | 
            .versions |
            if length != 0 then
                .[] | sub(" *[-, ] *"; "-"; "g")
            else
                empty
            end
        ]'
    )
    getInstalledVersion
    if [ "${#VERSIONS_LIST[@]}" -eq 0 ]; then
        notify info "Please Wait !!\nScraping versions list for $APP_NAME from apkmirror.com..."
        scrapeVersionsList || return 1
    fi
    if ! SELECTED_VERSION=$("${DIALOG[@]}" \
        --title '| Version Selection Menu |' \
        --default-item "$SELECTED_VERSION" \
        --ok-label 'Select' \
        --cancel-label 'Back' \
        --menu "$NAVIGATION_HINT" -1 -1 0 "${VERSIONS_LIST[@]}" \
        2>&1 > /dev/tty
    ); then
        TASK="CHOOSE_APP"
        return 1
    fi
    if [ "$SELECTED_VERSION" == "Auto Select" ]; then
        SELECTED_VERSION=$(jq -nrc --arg PKG_NAME "$PKG_NAME" --argjson SUPPORTED_VERSIONS "$SUPPORTED_VERSIONS" '$SUPPORTED_VERSIONS[-1]')
    fi
    if [ "$(jq -nrc --arg PKG_NAME "$PKG_NAME" --arg SELECTED_VERSION "$SELECTED_VERSION" --argjson SUPPORTED_VERSIONS "$SUPPORTED_VERSIONS" '$SUPPORTED_VERSIONS | index($SELECTED_VERSION)')" == "null" ]; then
        if ! "${DIALOG[@]}" --title '| Proceed |' --yesno "The version $SELECTED_VERSION is not supported.\nDo you still want to proceed with version this for $APP_NAME?" -1 -1; then
            return 1
        fi
    fi
    APP_VER="${SELECTED_VERSION// /-}"
}
