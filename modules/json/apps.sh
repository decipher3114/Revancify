#!/usr/bin/bash

fetchAppsInfo() {
    APPS_ARRAY=$(jq -rc '.' "$SOURCE-apps.json" 2> /dev/null || echo '[]')

    [ -n "$AVAILABLE_PATCHES" ] || AVAILABLE_PATCHES=$(jq -rc '.' "$SOURCE-patches-$PATCHES_VERSION.json")

    PKGS_ARRAY=$(jq -nc --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" --argjson APPS_ARRAY "$APPS_ARRAY" '
        $AVAILABLE_PATCHES |
        map(
            select(.pkgName != null).pkgName as $PKG_NAME |
            if any($APPS_ARRAY[]; .pkgName == $PKG_NAME) then
                empty
            else
                $PKG_NAME
            end
        )'
    )

    if [ "$PKGS_ARRAY" != '[]' ]; then
    
        if RESPONSE_JSON=$(
            "${CURL[@]}" 'https://www.apkmirror.com/wp-json/apkm/v1/app_exists/' \
            -H 'Accept: application/json' \
            -H 'Content-Type: application/json' \
            -H 'Authorization: Basic YXBpLXRvb2xib3gtZm9yLWdvb2dsZS1wbGF5OkNiVVcgQVVMZyBNRVJXIHU4M3IgS0s0SCBEbmJL' \
            -H 'User-Agent: Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.5414.86 Mobile Safari/537.36' \
            -d "$(jq -nr --argjson PKGS_ARRAY "$PKGS_ARRAY" '{"pnames": $PKGS_ARRAY}')"
        ); then

            APPS_INFO=$(echo "$RESPONSE_JSON" | jq -c --argjson APPS_ARRAY "$APPS_ARRAY" '
                reduce .data[] as {pname: $PKG_NAME, exists: $EXISTS, app: $APP} (
                    $APPS_ARRAY;
                    if $EXISTS then
                        if any(.[]; .pkgName == $PKG_NAME) | not then
                            . += [{
                                "pkgName": $PKG_NAME,
                                "appName": ($APP.name | sub("( -)|( &amp;)|:"; ""; "g") | sub("[()\\|]"; ""; "g") | sub(" *[-, ] *"; "-"; "g") | sub("-Wear-OS"; ""; "g")) | split("-")[:4] | join("-"),
                                "apkmirrorAppName": ($APP.link | sub("-wear-os"; "") | match("(?<=\\/)(((?!\\/).)*)(?=\\/$)").string),
                                "developerName": ($APP.link | match("(?<=apk\\/).*?(?=\\/)").string)
                            }]
                        else
                            .
                        end
                    else
                        .
                    end
                )'
            )
            echo "$APPS_INFO" > "$SOURCE-apps.json"
        else
            notify msg "API request failed for apkmirror.com.\nTry again later..."
            return 1
        fi
    fi
    unset APPS_ARRAY PKGS_ARRAY
}
