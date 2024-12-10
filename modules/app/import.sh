#!/usr/bin/bash

selectFile() {
    readarray -t STOCK_APPS < <(ls "$STORAGE/Stock/"*.apk | xargs basename -a 2> /dev/null)
    if [ "${#STOCK_APPS[@]}" -eq 0 ]; then
        notify msg "No apk found in Stock Apps directory !!\nMove app to 'Revancify/Stock' to import."
        TASK="CHOOSE_APP"
        return 1
    fi
    if ! SELECTED_APK_FILE=$("${DIALOG[@]}" \
        --title '| Import App |' \
        --no-items \
        --ok-label 'Select' \
        --cancel-label 'Back' \
        --menu "$NAVIGATION_HINT" -1 -1 0 \
        "${STOCK_APPS[@]}" \
        2>&1 > /dev/tty
    ); then
        TASK="CHOOSE_APP"
        return 1
    fi
}

extractProperties() {
    APP_PATH="$STORAGE/Stock/$SELECTED_APK_FILE"
    local FILE_APP_NAME SELECTED_VERSION INSTALLED_VERSION VERSION_STATUS
    notify info "Please Wait !!\nExtracting data from \"$(basename "$APP_PATH")\""
    if ! APP_PROPERTIES=$(./bin/aapt2 dump badging "$APP_PATH"); then
        notify msg "The apkfile you selected is not an valid app. Download the apk again and retry."
        return 1
    fi
    PKG_NAME=$(grep "package:" <<<"$APP_PROPERTIES" | sed -e 's/package: name='\''//' -e 's/'\'' versionCode.*//')
    FILE_APP_NAME=$(grep "application-label:" <<<"$APP_PROPERTIES" | sed -e 's/application-label://' -e 's/'\''//g')
    APP_NAME="$(sed 's/\./-/g;s/ /-/g' <<<"$FILE_APP_NAME")"
    SELECTED_VERSION=$(grep "package:" <<<"$APP_PROPERTIES" | sed -e 's/.*versionName='\''//' -e 's/'\'' platformBuildVersionName.*//')
    APP_VER="${SELECTED_VERSION// /-}"
    getInstalledVersion
    if [ "$ALLOW_APP_VERSION_DOWNGRADE" == "off" ] && \
        jq -e '.[0] < .[1]' <<< "[\"${INSTALLED_VERSION:-0}\", \"$SELECTED_VERSION\"]" \
    &> /dev/null; then
        notify msg "The selected version $SELECTED_VERSION is lower then version $INSTALLED_VERSION installed on your device.\nPlease Select a higher version !!"
        return 1
    fi
    if [ "$(jq -nrc --arg PKG_NAME "$PKG_NAME" --arg SELECTED_VERSION "$SELECTED_VERSION" --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '
        $AVAILABLE_PATCHES[] |
        select(.pkgName == $PKG_NAME) |
        .versions |
        index($SELECTED_VERSION)'
        )" == "null" ] \
    ; then
        VERSION_STATUS="[Incompatible]"
    fi
    if ! "${DIALOG[@]}" \
        --title '| Proceed |' \
        --yesno "The following data is extracted from the apk file you provided.\nApp Name    : $APP_NAME\nPackage Name: $PKG_NAME\nVersion     : $SELECTED_VERSION $VERSION_STATUS\nDo you want to proceed with this app?" -1 -1\
    ; then
        return 1
    fi
}

importApp() {
    local SELECTED_APK_FILE APP_PROPERTIES FILE_APP_NAME APP_PATH
    selectFile || return 1
    extractProperties || return 1
    mkdir -p "apps/$APP_NAME"
    cp "$APP_PATH" "apps/$APP_NAME/$APP_VER.apk"
    findPatchedApp || return 1
}
