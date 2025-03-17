#!/usr/bin/bash

fetchAssetsInfo() {
    unset CLI_VERSION CLI_URL CLI_SIZE PATCHES_VERSION PATCHES_URL PATCHES_SIZE JSON_URL
    local SOURCE_INFO VERSION PATCHES_API_URL

    internet || return 1

    if [ "$("${CURL[@]}" "https://api.github.com/rate_limit" | jq -r '.resources.core.remaining')" -gt 5 ]; then

        mkdir -p "assets/$SOURCE"

        rm "assets/$SOURCE/.data" "assets/.data" &> /dev/null

        notify info "Fetching Assets Info..."

        if ! "${CURL[@]}" "https://api.github.com/repos/ReVanced/revanced-cli/releases/latest" |
            jq -r '
                "CLI_VERSION='\''\(.tag_name)'\''",
                (
                    .assets[] |
                    if (.name | endswith(".jar")) then
                        "CLI_URL='\''\(.browser_download_url)'\''",
                        "CLI_SIZE='\''\(.size|tostring)'\''"
                    else
                        empty
                    end
                )
            ' > assets/.data 2> /dev/null; then
            notify msg "Unable to fetch latest CLI info from API!!\nRetry later."
            return 1
        fi

        source <(
            jq -r --arg SOURCE "$SOURCE" '
                .[] | select(.source == $SOURCE) |
                "REPO=\(.repository)",
                (
                    .api // empty |
                    (
                        (.json // empty | "JSON_URL=\(.)"),
                        (.version // empty | "VERSION_URL=\(.)")
                    )
                )
            ' sources.json
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

        if ! "${CURL[@]}" "$PATCHES_API_URL" |
            jq -r '
                if type == "array" then .[0] else . end |
                "PATCHES_VERSION='\''\(.tag_name)'\''",
                (
                    .assets[] |
                    if (.name | endswith(".rvp")) then
                        "PATCHES_URL='\''\(.browser_download_url)'\''",
                        "PATCHES_SIZE='\''\(.size|tostring)'\''"
                    else
                        empty
                    end
                )
            ' > "assets/$SOURCE/.data" \
                2> /dev/null; then
            notify msg "Unable to fetch latest Patches info from API!!\nRetry later."
            return 1
        fi

        [ -n "$JSON_URL" ] && setEnv JSON_URL "$JSON_URL" init "assets/$SOURCE/.data"
    else
        notify msg "Unable to check for update.\nYou are probably rate-limited at this moment.\nTry again later or Run again with '-o' argument."
        return 1
    fi
    source "assets/.data"
    source "assets/$SOURCE/.data"
}

fetchAssets() {
    local CTR

    if [ -e "assets/.data" ] && [ -e "assets/$SOURCE/.data" ]; then
        source "assets/.data"
        source "assets/$SOURCE/.data"
    else
        fetchAssetsInfo || return 1
    fi

    CLI_FILE="assets/CLI-$CLI_VERSION.jar"
    [ -e "$CLI_FILE" ] || rm -- assets/CLI-* &> /dev/null

    CTR=2 && while [ "$CLI_SIZE" != "$(stat -c %s "$CLI_FILE" 2> /dev/null || echo 0)" ]; do
        if [ $CTR -eq 0 ]; then
            rm "$CLI_FILE" &> /dev/null
            notify msg "Oops! Unable to download completely.\n\nRetry or change your Network."
            return 1
        fi
        ((CTR--))
        "${WGET[@]}" "$CLI_URL" -O "$CLI_FILE" |&
            stdbuf -o0 cut -b 63-65 |
            stdbuf -o0 grep '[0-9]' |
            "${DIALOG[@]}" --gauge "File    : CLI-$CLI_VERSION.jar\nSize    : $(numfmt --to=iec --format="%0.1f" "$CLI_SIZE")\n\nDownloading..." -1 -1 "$(($(($(stat -c %s "$CLI_FILE" 2> /dev/null || echo 0) * 100)) / CLI_SIZE))"
        tput civis
    done

    PATCHES_FILE="assets/$SOURCE/Patches-$PATCHES_VERSION.rvp"
    [ -e "$PATCHES_FILE" ] || rm -- assets/"$SOURCE"/Patches-* &> /dev/null

    CTR=2 && while [ "$PATCHES_SIZE" != "$(stat -c %s "$PATCHES_FILE" 2> /dev/null || echo 0)" ]; do
        if [ $CTR -eq 0 ]; then
            rm "$PATCHES_FILE" &> /dev/null
            notify msg "Oops! Unable to download completely.\n\nRetry or change your Network."
            return 1
        fi
        ((CTR--))
        "${WGET[@]}" "$PATCHES_URL" -O "$PATCHES_FILE" |&
            stdbuf -o0 cut -b 63-65 |
            stdbuf -o0 grep '[0-9]' |
            "${DIALOG[@]}" --gauge "File    : Patches-$PATCHES_VERSION.rvp\nSize    : $(numfmt --to=iec --format="%0.1f" "$PATCHES_SIZE")\n\nDownloading..." -1 -1 "$(($(($(stat -c %s "$PATCHES_FILE" 2> /dev/null || echo 0) * 100)) / PATCHES_SIZE))"
        tput civis
    done

    parsePatchesJson || return 1
}

deleteAssets() {
    if "${DIALOG[@]}" \
        --title '| Delete Assets |' \
        --defaultno \
        --yesno "Please confirm to delete the assets.\nIt will delete the CLI and patches." -1 -1 \
        ; then
        unset CLI_VERSION CLI_URL CLI_SIZE PATCHES_VERSION PATCHES_URL PATCHES_SIZE JSON_URL
        rm -rf assets &> /dev/null
        mkdir assets
    fi
}
