#!/usr/bin/bash

scrapeAppInfo() {
    PAGE1=$(
        "${CURL[@]}" \
            -A "$USER_AGENT" \
            "$APP_DL_URL"
    )
    unset APP_DL_URL

    CANONICAL_URL=$(pup -p --charset utf-8 'link[rel="canonical"] attr{href}' <<< " $PAGE1" 2> /dev/null)

    if grep -q "apk-download" <<< "$CANONICAL_URL"; then
        URL1="${CANONICAL_URL/"https://www.apkmirror.com/"//}"
    else
        if [ "$PREFER_SPLIT_APK" == "on" ]; then
            APP_FORMAT="BUNDLE"
        else
            APP_FORMAT="APK"
        fi

        readarray -t VARIANT_INFO < <(
            pup -p --charset utf-8 'div.variants-table json{}' <<< "$PAGE1" |
                jq -r \
                    --arg ARCH "$ARCH" \
                    --arg DPI "$DPI" \
                    --arg APP_FORMAT "$APP_FORMAT" '
                    [
                        .[].children[1:][].children |
                        if (.[1].text | test("universal|noarch|\($ARCH)")) and
                            (
                                .[3].text |
                                test("nodpi") or
                                (
                                    capture("(?<low>\\d+)-(?<high>\\d+)dpi") |
                                    (($DPI | tonumber) <= (.high | tonumber)) and (($DPI | tonumber) >= (.low | tonumber))
                                )
                            )
                        then
                            .[0].children
                        else
                            empty
                        end
                    ] |
                    if length != 0 then
                        [
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
                        ][-1][]
                    else
                        empty
                    end
                '
        )

        [ "${#VARIANT_INFO[@]}" -eq 0 ] && echo 1 >&2 && exit

        APP_FORMAT="${VARIANT_INFO[0]}"
        URL1="${VARIANT_INFO[1]}"
    fi
    echo 33

    PAGE2=$("${CURL[@]}" -A "$USER_AGENT" "https://www.apkmirror.com$URL1")
    readarray -t DL_URLS < <(pup -p --charset utf-8 'a.downloadButton attr{href}' <<< "$PAGE2" 2> /dev/null)

    if [ "$APP_FORMAT" == "APK" ]; then
        URL2="${DL_URLS[0]}"
    else
        URL2="${DL_URLS[-1]}"
    fi

    APP_SIZE=$(pup -p --charset utf-8 ':parent-of(:parent-of(svg[alt="APK file size"])) div text{}' <<< "$PAGE2" 2> /dev/null | sed -n 's/.*(//;s/ bytes.*//;s/,//gp' 2> /dev/null)
    [ "$URL2" == "" ] && echo 2 >&2 && exit
    echo 66

    URL3=$("${CURL[@]}" -A "$USER_AGENT" "https://www.apkmirror.com$URL2" | pup -p --charset UTF-8 'a:contains("here") attr{href}' 2> /dev/null | head -n 1)
    [ "$URL3" == "" ] && echo 2 >&2 && exit

    APP_URL="https://www.apkmirror.com$URL3"
    setEnv APP_FORMAT "$APP_FORMAT" update "apps/$APP_NAME/.data"
    setEnv APP_SIZE "$APP_SIZE" update "apps/$APP_NAME/.data"
    setEnv APP_URL "$APP_URL" update "apps/$APP_NAME/.data"
    echo 100
}

fetchDownloadURL() {
    local EXIT_CODE

    internet || return 1

    mkdir -p "apps/$APP_NAME"
    if [ $((($(date +%s) - $(stat -c %Y "apps/$APP_NAME/.data" 2> /dev/null || echo 0)) / 60)) -le 5 ]; then
        if [ "$APP_FORMAT" == "BUNDLE" ]; then
            export APP_EXT="apkm"
        else
            export APP_EXT="apk"
        fi
        return 0
    fi

    EXIT_CODE=$(
        {
            scrapeAppInfo 2>&3 |
                "${DIALOG[@]}" --gauge "App    : $APP_NAME\nVersion: $APP_VER\n\nScraping Download Link..." -1 -1 0 2>&1 > /dev/tty
        } 3>&1
    )
    if [ $(($(date +%s) - $(stat -c %Y "apps/$APP_NAME/.data" 2> /dev/null || echo 0))) -le 5 ]; then
        source "apps/$APP_NAME/.data"
        if [ "$APP_FORMAT" == "BUNDLE" ]; then
            export APP_EXT="apkm"
        else
            export APP_EXT="apk"
        fi
    else
        case $EXIT_CODE in
            1)
                notify msg "No apk or bundle found matching device architecture. Please select a different version."
                ;;
            2)
                notify msg "Unable to fetch link !!\nEither there is some problem with your internet connection or blocked by cloudflare protection. Disable VPN or Change your network."
                ;;
        esac
        return 1
    fi
    tput civis
}

downloadAppFile() {
    "${WGET[@]}" "$APP_URL" -O "apps/$APP_NAME/$APP_VER.$APP_EXT" |&
        stdbuf -o0 cut -b 63-65 |
        stdbuf -o0 grep '[0-9]' |
        "${DIALOG[@]}" \
            --gauge "File: $APP_NAME-$APP_VER.$APP_EXT\nSize: $(numfmt --to=iec --format="%0.1f" "$APP_SIZE")\n\nDownloading..." -1 -1 \
            "$(($(($(stat -c %s "apps/$APP_NAME/$APP_VER.$APP_EXT" || echo 0) * 100)) / APP_SIZE))"
    tput civis
    if [ "$APP_SIZE" != "$(stat -c %s "apps/$APP_NAME/$APP_VER.$APP_EXT" || echo 0)" ]; then
        notify msg "Oh No !!\nUnable to complete download. Please Check your internet connection and Retry."
        return 1
    fi
}

downloadApp() {
    local APP_FORMAT APP_EXT APP_SIZE APP_URL
    if ! chooseVersion; then
        TASK="CHOOSE_APP"
        return 1
    fi

    findPatchedApp || return 1

    [ -e "apps/$APP_NAME/.data" ] && source "apps/$APP_NAME/.data"

    if [ "$(stat -c %s "apps/$APP_NAME/$APP_VER.apk" 2> /dev/null || echo 0)" == "$APP_SIZE" ]; then
        if "${DIALOG[@]}" \
            --title '| App Found |' \
            --defaultno \
            --yesno "Apk file already exists!!\nDo you want to download again?" -1 -1; then
            rm -rf "apps/$APP_NAME" &> /dev/null
        else
            return 0
        fi
    elif [ -e "apps/$APP_NAME/$APP_VER" ]; then
        antisplitApp && return 0 || return 1
    elif ! ls "apps/$APP_NAME/$APP_VER"* &> /dev/null; then
        rm -rf "apps/$APP_NAME" &> /dev/null
    fi

    fetchDownloadURL || return 1
    downloadAppFile || return 1

    if [ "$APP_FORMAT" == "BUNDLE" ]; then
        antisplitApp || return 1
    fi
}
