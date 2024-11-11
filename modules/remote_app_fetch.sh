#!/usr/bin/bash

scrapeVersionsList() {
    PAGE=$("${CURL[@]}" -A "$USER_AGENT" "https://www.apkmirror.com/uploads/?appcategory=$APKMIRROR_APP_NAME" 2>&1)

    if [ "$PAGE" == "" ]; then
        notify msg "Unable to fetch versions !!\nThere is some problem with your internet connection. Disable VPN or Change your network."
        TASK="CHOOSE_APP"
        return 1
    fi

    readarray -t VERSIONS < <(pup -p 'div.widget_appmanager_recentpostswidget h5 a.fontBlack text{}' <<<"$PAGE")

    unset PAGE

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
                $VERSION | sub("(?<=[0-9])-[a-zA-Z]$"; ""), "[ALPHA]"
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
    unset SELECTED_VERSION APP_VER
    if [ "$ROOT_ACCESS" == true ]; then
        getInstalledVersion
    fi
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
    unset SUPPORTED_VERSIONS SELECTED_VERSION
}

scrapeAppInfo() {
    PAGE1=$("${CURL[@]}" \
        -A "$USER_AGENT" \
        "https://www.apkmirror.com/apk/$DEVELOPER_NAME/$APKMIRROR_APP_NAME/$APKMIRROR_APP_NAME-$APP_VER-release"
    )
    CANONICAL_URL=$(pup -p --charset utf-8 'link[rel="canonical"] attr{href}' <<<"$page1"  2> /dev/null)
    if grep -q "apk-download" <<< "$CANONICAL_URL"; then
        URL1="${CANONICAL_URL/"https://www.apkmirror.com/"//}"
    else
        if [ "$PREFER_SPLIT_APK" == "on" ]; then
            APP_FORMAT="BUNDLE"
        else
            APP_FORMAT="APK"
        fi
        readarray -t VARIANT_INFO < <(pup -p --charset utf-8 'div.variants-table json{}' <<< "$PAGE1"  2> /dev/null | jq -r --arg ARCH "$ARCH" --arg APP_FORMAT "$APP_FORMAT" '
            [
                .[].children[1:][].children |
                if (.[1].text | test("universal|noarch|\($ARCH)")) then
                    .[0].children
                else
                    empty
                end
            ] | [
                if any(.[]; .[1].text == $APP_FORMAT) then
                    .[] |
                    if (.[1].text == $APP_FORMAT) then
                        [.[1].text, .[0].href]
                    else
                        empty
                    end
                else
                    .[] | 
                    [.[1].text, .[0].href]
                end
            ][-1][]' \
        2> /dev/null)
        APP_FORMAT="${VARIANT_INFO[0]}"
        URL1="${VARIANT_INFO[1]}"
        unset VARIANT_INFO
    fi
    unset CANONICAL_URL PAGE1
    echo 33
    PAGE2=$("${CURL[@]}" -A "$USER_AGENT" "https://www.apkmirror.com$URL1")
    unset URL1
    URL2=$(pup -p --charset utf-8 'a.downloadButton attr{href}' <<< "$PAGE2" 2> /dev/null)
    APP_SIZE=$(pup -p --charset utf-8 ':parent-of(:parent-of(svg[alt="APK file size"])) div text{}' <<< "$PAGE2" 2> /dev/null | sed -n 's/.*(//;s/ bytes.*//;s/,//gp' 2> /dev/null)
    unset PAGE2
    [ "$URL2" == "" ] && return 1
    echo 66
    URL3=$("${CURL[@]}" -A "$USER_AGENT" "https://www.apkmirror.com$URL2" | pup -p --charset UTF-8 'a:contains("here") attr{href}' 2> /dev/null | head -n 1)
    unset URL2
    [ "$URL3" == "" ] && return 1
    APP_URL="https://www.apkmirror.com$URL3"
    unset URL3
    setEnv APP_FORMAT "$APP_FORMAT" update "apps/$APP_NAME/.info"
    setEnv APP_URL "$APP_URL" update "apps/$APP_NAME/.info"
    setEnv APP_SIZE "$APP_SIZE" update "apps/$APP_NAME/.info"
    echo 100
}

fetchDownloadURL() {
    internet || return 1
    mkdir -p "apps/$APP_NAME"
    rm "apps/$APP_NAME/.info" &> /dev/null
    scrapeAppInfo | "${DIALOG[@]}" --gauge "App    : $APP_NAME\nVersion: $APP_VER\n\nScraping Download Link..." -1 -1 0
    if [ -e "apps/$APP_NAME/.info" ]; then
        source "apps/$APP_NAME/.info"
        if [ "$APP_FORMAT" == "BUNDLE" ]; then
            export APP_EXT="apkm"
        else
            export APP_EXT="apk"
        fi
    else
        notify msg "Unable to fetch link !!\nThere is some problem with your internet connection. Disable VPN or Change your network."
        return 1
    fi
    tput civis
}

downloadApp() {
    "${WGET[@]}" "$APP_URL" -O "apps/$APP_NAME/$APP_VER.$APP_EXT" |& stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' |
    "${DIALOG[@]}" \
        --gauge "File: $APP_NAME-$APP_VER.$APP_EXT\nSize: $(numfmt --to=iec --format="%0.1f" "$APP_SIZE")\n\nDownloading..." -1 -1 \
        "$(($(( $(stat -c%s "apps/$APP_NAME/$APP_VER.$APP_EXT" || echo 0) * 100)) / APP_SIZE))"
    tput civis
    if [ "$APP_SIZE" != "$(stat -c%s "apps/$APP_NAME/$APP_VER.$APP_EXT" || echo 0)" ]; then
        notify msg "Oh No !!\nUnable to complete download. Please Check your internet connection and Retry."
        return 1
    fi
}

antisplitApp() {
    [ "$APP_FORMAT" == "BUNDLE" ] || return 0

    notify info "Please Wait !!\nReducing app size..."
    SPLITS="apps/splits"
    mkdir -p "$SPLITS"
    unzip -qqo "apps/$APP_NAME/$APP_VER.apkm" -d "$SPLITS"
    rm "apps/$APP_NAME/$APP_VER.apkm"
    APP_DIR="apps/$APP_NAME/$APP_VER"
    mkdir -p "$APP_DIR"
    cp "$SPLITS/base.apk" "$APP_DIR"
    cp "$SPLITS/split_config.${ARCH//-/_}.apk" "$APP_DIR" &> /dev/null
    LOCALE=$(getprop persist.sys.locale | sed 's/-.*//g')
    if [ ! -e "$SPLITS/split_config.${LOCALE}.apk" ]; then
        LOCALE=$(getprop ro.product.locale | sed 's/-.*//g')
    fi
    cp "$SPLITS/split_config.${LOCALE}.apk" "$APP_DIR" &> /dev/null
    cp "$SPLITS"/split_config.*dpi.apk "$APP_DIR" &> /dev/null
    rm -rf "$SPLITS"
    java -jar ApkEditor.jar m -i "$APP_DIR" -o "apps/$APP_NAME/$APP_VER.apk" &> /dev/null
    setEnv "APP_SIZE" "$(stat -c%s "apps/$APP_NAME/$APP_VER.apk")" update "apps/$APP_NAME/.info"
    unset APP_DIR
}

remoteAppFetch() {
    chooseVersion || return 1
    findPatchedApp || return 1
    if [ -e "apps/$APP_NAME/$APP_VER.apk" ] && [ -e "apps/$APP_NAME/.info" ]; then
        source "apps/$APP_NAME/.info"
        if [ "$(stat -c%s "apps/$APP_NAME/$APP_VER.apk" || echo 0)" == "$APP_SIZE" ]; then
            TASK="MANAGE_PATCHES"
            return 0
        fi
    else
        rm -rf apps/"$APP_NAME"/* &> /dev/null
    fi
    fetchDownloadURL || return 1
    downloadApp || return 1
    antisplitApp
}
