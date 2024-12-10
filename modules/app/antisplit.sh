#!/usr/bin/bash

antisplitApp() {
    local SPLITS APP_DIR LOCALE

    notify info "Please Wait !!\nReducing app size..."

    APP_DIR="apps/$APP_NAME/$APP_VER"
    if [ ! -e "$APP_DIR" ]; then
        SPLITS="apps/splits"
        mkdir -p "$SPLITS"
        unzip -qqo "apps/$APP_NAME/$APP_VER.apkm" -d "$SPLITS"
        rm "apps/$APP_NAME/$APP_VER.apkm"
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
    fi
    java -jar bin/APKEditor.jar m -i "$APP_DIR" -o "apps/$APP_NAME/$APP_VER.apk" &> /dev/null
    if [ ! -e "apps/$APP_NAME/$APP_VER.apk" ]; then
        notify msg "Unable to run merge splits!!\nApkEditor is not working properly."
        return 1
    fi
    setEnv "APP_SIZE" "$(stat -c%s "apps/$APP_NAME/$APP_VER.apk")" update "apps/$APP_NAME/.data"
}
