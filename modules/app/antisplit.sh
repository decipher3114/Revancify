#!/usr/bin/bash

antisplitApp() {
    local APP_DIR LOCALE

    notify info "Please Wait !!\nReducing app size..."

    APP_DIR="apps/$APP_NAME/$APP_VER"
    if [ ! -e "$APP_DIR" ]; then
        LOCALE=$(getprop persist.sys.locale | sed 's/-.*//g')
        if [ ! -e "$SPLITS/split_config.${LOCALE}.apk" ]; then
            LOCALE=$(getprop ro.product.locale | sed 's/-.*//g')
        fi
        unzip -qqo \
            "apps/$APP_NAME/$APP_VER.apkm" \
            "base.apk"\
            "split_config.${ARCH//-/_}.apk" \
            "split_config.${LOCALE}.apk" \
            split_config.*dpi.apk \
            -d "$APP_DIR"
        rm "apps/$APP_NAME/$APP_VER.apkm"
    fi
    java -jar bin/APKEditor.jar m -i "$APP_DIR" -o "apps/$APP_NAME/$APP_VER.apk" &> /dev/null
    if [ ! -e "apps/$APP_NAME/$APP_VER.apk" ]; then
        notify msg "Unable to run merge splits!!\nApkEditor is not working properly."
        return 1
    fi
    if [ "$ROOT_ACCESS" == false ]; then
        rm -rf "apps/$APP_NAME/$APP_VER"
    fi
    setEnv "APP_SIZE" "$(stat -c %s "apps/$APP_NAME/$APP_VER.apk")" update "apps/$APP_NAME/.data"
}
