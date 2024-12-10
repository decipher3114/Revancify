#!/usr/bin/bash

fetchAssetsInfo() {
    unset CLI_VERSION CLI_FILE_URL CLI_FILE_SIZE PATCHES_VERSION PATCHES_FILE_URL PATCHES_FILE_SIZE JSON_URL
    local SOURCE_INFO VERSION PATCHES_API_URL

    internet || return 1
    
    if [ "$("${CURL[@]}" "https://api.github.com/rate_limit" | jq -r '.resources.core.remaining')" -gt 5 ]; then

        rm ".$SOURCE-assets" 2> /dev/null
    
        notify info "Fetching Assets Info..."

        if ! source <("${CURL[@]}" "https://api.github.com/repos/ReVanced/revanced-cli/releases" | jq -r '
                if type == "array" then .[0] else . end |
                "CLI_VERSION="+.tag_name,
                (
                    .assets[] |
                    if .content_type == "application/java-archive" then
                        "CLI_FILE_URL="+.browser_download_url,
                        "CLI_FILE_SIZE="+(.size|tostring)
                    else
                        empty
                    end
                )
            '
        ); then
            notify msg "Unable to fetch latest CLI info from API!!\nRetry later."
            return 1
        fi
        
        source <(jq -r --arg SOURCE "$SOURCE" '
            .[] | select(.source == $SOURCE) |
            "REPO=\(.repository)",
            (
                .api // empty |
                (
                    (.json // empty | "JSON_URL=\(.)"),
                    (.version // empty | "VERSION_URL=\(.)")
                )
            )
            ' "$SRC/sources.json"
        )

        if [ -n "$VERSION_URL" ]; then
            if VERSION=$("${CURL[@]}" "$VERSION_URL" | jq -r '.version' 2> /dev/null); then
                PATCHES_API_URL="https://api.github.com/repos/$REPO/releases/tags/$VERSION"
            else
                notify msg "Unable to fetch latest version from API!!\nRetry later."
                return 1
            fi
        else
            PATCHES_API_URL="https://api.github.com/repos/$REPO/releases/latest"
        fi

        if ! source <("${CURL[@]}" "$PATCHES_API_URL" | jq -r '
                if type == "array" then .[0] else . end |
                "PATCHES_VERSION="+.tag_name,
                (
                    .assets[] |
                    if (.name | endswith(".rvp")) then
                        "PATCHES_FILE_URL="+.browser_download_url,
                        "PATCHES_FILE_SIZE="+(.size|tostring)
                    else
                        empty
                    end
                )
            '
        ); then 
            notify msg "Unable to fetch latest Patches info from API!!\nRetry later."
            return 1
        fi
 
        setEnv CLI_VERSION "$CLI_VERSION" init ".$SOURCE-assets"
        setEnv CLI_FILE_URL "$CLI_FILE_URL" init ".$SOURCE-assets"
        setEnv CLI_FILE_SIZE "$CLI_FILE_SIZE" init ".$SOURCE-assets"
        setEnv PATCHES_VERSION "$PATCHES_VERSION" init ".$SOURCE-assets"
        setEnv PATCHES_FILE_URL "$PATCHES_FILE_URL" init ".$SOURCE-assets"
        setEnv PATCHES_FILE_SIZE "$PATCHES_FILE_SIZE" init ".$SOURCE-assets"
        [ -n "$JSON_URL" ] && setEnv JSON_URL "$JSON_URL" init ".$SOURCE-assets"
    else
        notify msg "Unable to check for update.\nYou are probably rate-limited at this moment.\nTry again later or Run again with '-o' argument."
        return 1
    fi
    source ".$SOURCE-assets"
}

fetchAssets() {
    local CTR

    if [ ! -e ".$SOURCE-assets" ]; then
        fetchAssetsInfo || return 1
    fi

    CLI_FILE_NAME="ReVanced-cli-$CLI_VERSION.jar"
    [ -e "$CLI_FILE_NAME" ] || rm -- ReVanced-cli-* &> /dev/null

    CTR=2 && while [ "$CLI_FILE_SIZE" != "$(stat -c%s "$CLI_FILE_NAME" 2> /dev/null)" ]; do
        [ $CTR -eq 0 ] && notify msg "Oops! Unable to download completely.\n\nRetry or change your Network." && return 1
        ((CTR--))
        "${WGET[@]}" "$CLI_FILE_URL" -O "$CLI_FILE_NAME" |& stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' |
        "${DIALOG[@]}" --gauge "File    : $CLI_FILE_NAME\nSize    : $(numfmt --to=iec --format="%0.1f" "$CLI_FILE_SIZE")\n\nDownloading..." -1 -1 "$(($(($(stat -c%s "$CLI_FILE_NAME" 2> /dev/null || echo 0) * 100)) / CLI_FILE_SIZE))"
        tput civis
    done

    PATCHES_FILE_NAME="$SOURCE-patches-$PATCHES_VERSION.rvp"
    [ -e "$PATCHES_FILE_NAME" ] || rm -- "$SOURCE"-patches-* &> /dev/null

    CTR=2 && while [ "$PATCHES_FILE_SIZE" != "$(stat -c%s "$PATCHES_FILE_NAME" 2> /dev/null)" ]; do
        [ $CTR -eq 0 ] && notify msg "Oops! Unable to download completely.\n\nRetry or change your Network." && return 1
        ((CTR--))
        "${WGET[@]}" "$PATCHES_FILE_URL" -O "$PATCHES_FILE_NAME" |& stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' |
        "${DIALOG[@]}" --gauge "File    : $PATCHES_FILE_NAME\nSize    : $(numfmt --to=iec --format="%0.1f" "$PATCHES_FILE_SIZE")\n\nDownloading..." -1 -1 "$(($(($(stat -c%s "$PATCHES_FILE_NAME" 2> /dev/null || echo 0) * 100)) / PATCHES_FILE_SIZE))"
        tput civis
    done

    parsePatchesJson || return 1
}

deleteAssets() {

    if "${DIALOG[@]}" \
            --title '| Delete Tools |' \
            --defaultno \
            --yesno "Please confirm to delete the assets.\nIt will delete the CLI and $SOURCE patches." -1 -1\
    ; then
        unset CLI_VERSION CLI_FILE_URL CLI_FILE_SIZE PATCHES_VERSION PATCHES_FILE_URL PATCHES_FILE_SIZE JSON_URL
        rm ".$SOURCE-assets" &> /dev/null
        rm ReVanced-cli-*.jar &> /dev/null
        rm "$SOURCE"-patches-*.rvp &> /dev/null
    fi
}
