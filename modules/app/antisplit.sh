#!/usr/bin/bash

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
