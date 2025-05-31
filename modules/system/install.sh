#!/usr/bin/bash

installApp() {
    local CANONICAL_VER
    if [ "$ROOT_ACCESS" == true ]; then
        mountApp
    elif [ "$RISH_ACCESS" == true ]; then
        installAppRish
    else
        notify info "Copying patched $APP_NAME apk to Internal Storage..."
        CANONICAL_VER=${APP_VER//:/}
        cp -f "apps/$APP_NAME/$APP_VER-$SOURCE.apk" "$STORAGE/Patched/$APP_NAME-$CANONICAL_VER-$SOURCE.apk" &> /dev/null
        termux-open --view "$STORAGE/Patched/$APP_NAME-$CANONICAL_VER-$SOURCE.apk"
    fi
    unset PKG_NAME APP_NAME APKMIRROR_APP_NAME APP_VER
}
