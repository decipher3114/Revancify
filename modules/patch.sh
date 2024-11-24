#!/usr/bin/bash

findPatchedApp() {
    if [ -e "apps/$APP_NAME/$APP_VER-$SOURCE.apk" ]; then
        "${DIALOG[@]}" \
            --title '| Patched apk found |' \
            --defaultno \
            --yes-label 'Patch' \
            --no-label 'Install' \
            --help-button \
            --help-label 'Back' \
            --yesno "Current directory already contains Patched $APP_NAME version $SELECTED_VERSION.\n\n\nDo you want to patch $APP_NAME again?" -1 -1
        case "$?" in
        0 )
            rm "apps/$APP_NAME/$APP_VER-$SOURCE.apk"
            ;;
        1 )
            TASK="INSTALL_APP"
            return 1
            ;;
        2 )
            unset APP_VER
            return 1
            ;;
        esac
    else
        return 0
    fi
}

patchApp() {
    if [ ! -e "apps/$APP_NAME/$APP_VER.apk" ]; then
        notify msg "Apk not found !!\nTry importing Apk from Storage."
        return 1
    fi

    readarray -t ARGUMENTS < <(jq -nrc --arg PKG_NAME "$PKG_NAME" --argjson ENABLED_PATCHES "$ENABLED_PATCHES" '
        $ENABLED_PATCHES[] |
        select(.pkgName == $PKG_NAME) |
        .options as $OPTIONS |
        .patches[] |
        . as $PATCH_NAME |
        "--enable",
        $PATCH_NAME,
        (
            $OPTIONS[] |
            if .patchName == $PATCH_NAME then
                "--options=" +
                .key + "=" +
                (
                    .value |
                    if . != null then
                        . | tostring | sub("[\" ]"; ""; "g")
                    else
                        empty
                    end
                )
            else
                empty
            end
        )
        '
    )

    echo -e "Root Access: $ROOT_ACCESS\nArchitecture: $ARCH\nApp: $APP_NAME v$APP_VER\nCLI: $CLI_FILE_NAME\nPatches: $PATCHES_FILE_NAME\nArguments: ${ARGUMENTS[*]}\n\nLogs:\n" > "$STORAGE/patch_log.txt"

    java -jar "$CLI_FILE_NAME" patch \
        --force --exclusive --purge\
        --patches="$PATCHES_FILE_NAME" \
        --out="apps/$APP_NAME/$APP_VER-$SOURCE.apk" \
        "${ARGUMENTS[@]}" \
        --custom-aapt2-binary="./aapt2" \
        --keystore="$STORAGE/revancify.keystore" \
        "apps/$APP_NAME/$APP_VER.apk" |&
    tee -a "$STORAGE/patch_log.txt" |
    "${DIALOG[@]}" \
        --ok-label 'Continue' \
        --cursor-off-label \
        --programbox "Patching $APP_NAME $APP_VER" -1 -1

    tput civis
    if [ ! -f "apps/$APP_NAME/$APP_VER-$SOURCE.apk" ]; then
        notify msg "Patching failed !!\nShare the Patchlog to developer."
        termux-open --send "$STORAGE/install_log.txt"
        return 1
    fi
}
