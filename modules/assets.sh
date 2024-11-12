#!/usr/bin/bash

fetchAssetsInfo() {
    internet || return 1
    if [ "$("${CURL[@]}" "https://api.github.com/rate_limit" | jq -r '.resources.core.remaining')" -gt 5 ]; then
        notify info "Fetching Assets Info..."

        source <("${CURL[@]}" "https://api.github.com/repos/ReVanced/revanced-cli/releases$ENDPOINT" | jq -r '
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
        )
        if [ -z "$SOURCE" ]; then
            SOURCE="ReVanced"
            setEnv SOURCE "$SOURCE" init .assets
        fi

        readarray -t SOURCE_INFO < <(jq -r --arg SOURCE "$SOURCE" '
            .[] | select(.source == $SOURCE) |
            .api |
            .patches,
            (.json // empty),
            ((.version | .endpoint, .key) // empty)
            ' "$SRC/sources.json"
        )

        if [ "${#SOURCE_INFO[@]}" -gt 2 ]; then
            VERSION=$("${CURL[@]}" "${SOURCE_INFO[2]}" | jq -r --arg KEY "${SOURCE_INFO[3]}" '.[$KEY]')
            eval "PATCHES_API_URL=\"${SOURCE_INFO[0]}\""
        else
            PATCHES_API_URL="${SOURCE_INFO[0]}"
        fi

        JSON_URL="${SOURCE_INFO[1]}"

        source <("${CURL[@]}" "$PATCHES_API_URL" | jq -r '
                if type == "array" then .[0] else . end |
                "PATCHES_VERSION="+.tag_name,
                (
                    .assets[] |
                    if .content_type == "text/plain" then
                        "PATCHES_FILE_URL="+.browser_download_url,
                        "PATCHES_FILE_SIZE="+(.size|tostring)
                    else
                        empty
                    end
                )
            '
        )
        setEnv CLI_VERSION "$CLI_VERSION" update .assets
        setEnv CLI_FILE_URL "$CLI_FILE_URL" update .assets
        setEnv CLI_FILE_SIZE "$CLI_FILE_SIZE" update .assets
        setEnv PATCHES_VERSION "$PATCHES_VERSION" update .assets
        setEnv PATCHES_FILE_URL "$PATCHES_FILE_URL" update .assets
        setEnv PATCHES_FILE_SIZE "$PATCHES_FILE_SIZE" update .assets
        setEnv JSON_URL "$JSON_URL" update .assets
    else
        notify msg "Unable to check for update.\nYou are probably rate-limited at this moment.\nTry again later or Run again with '-o' argument."
        return 1
    fi
    source .assets
}

fetchAssets() {
    CLI_FILE_NAME="ReVanced-cli-$CLI_VERSION.jar"
    [ -e "$CLI_FILE_NAME" ] || rm -- *-cli-* &> /dev/null
    CTR=2 && while [ "$CLI_FILE_SIZE" != "$(stat -c%s "$CLI_FILE_NAME" 2> /dev/null)" ]; do
        [ $CTR -eq 0 ] && notify msg "Oops! Unable to download completely.\n\nRetry or change your Network." && return 1
        ((CTR--))
        "${WGET[@]}" "$CLI_FILE_URL" -O "$CLI_FILE_NAME" |& stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' |
        "${DIALOG[@]}" --gauge "File    : $CLI_FILE_NAME\nSize    : $(numfmt --to=iec --format="%0.1f" "$CLI_FILE_SIZE")\n\nDownloading..." -1 -1 "$(($(($(stat -c%s "$CLI_FILE_NAME" 2> /dev/null || echo 0) * 100)) / CLI_FILE_SIZE))"
        tput civis
    done
    PATCHES_FILE_NAME="$SOURCE-patches-$PATCHES_VERSION.rvp"
    [ -e "$PATCHES_FILE_NAME" ] || rm -- *-patches-* &> /dev/null
    CTR=2 && while [ "$PATCHES_FILE_SIZE" != "$(stat -c%s "$PATCHES_FILE_NAME" 2> /dev/null)" ]; do
        [ $CTR -eq 0 ] && notify msg "Oops! Unable to download completely.\n\nRetry or change your Network." && return 1
        ((CTR--))
        "${WGET[@]}" "$PATCHES_FILE_URL" -O "$PATCHES_FILE_NAME" |& stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' |
        "${DIALOG[@]}" --gauge "File    : $PATCHES_FILE_NAME\nSize    : $(numfmt --to=iec --format="%0.1f" "$PATCHES_FILE_SIZE")\n\nDownloading..." -1 -1 "$(($(($(stat -c%s "$PATCHES_FILE_NAME" 2> /dev/null || echo 0) * 100)) / PATCHES_FILE_SIZE))"
        tput civis
    done
    parsePatchesJson || return 1
}
