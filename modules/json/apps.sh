#!/usr/bin/bash

fetchAppsInfo() {
    local APPS_ARRAY PKGS_ARRAY RESPONSE_JSON
    APPS_ARRAY=$(jq -rc '[.[]]' "$SOURCE"-apps-*.json 2> /dev/null || echo '[]')

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

        notify info "Fetching apps info from apkmirror.com..."
    
        if RESPONSE_JSON=$(
            "${CURL[@]}" 'https://www.apkmirror.com/wp-json/apkm/v1/app_exists/' \
                -H 'Accept: application/json' \
                -H 'Content-Type: application/json' \
                -H 'Authorization: Basic YXBpLXRvb2xib3gtZm9yLWdvb2dsZS1wbGF5OkNiVVcgQVVMZyBNRVJXIHU4M3IgS0s0SCBEbmJL' \
                -H 'User-Agent: Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.5414.86 Mobile Safari/537.36' \
                -d "$(jq -nr --argjson PKGS_ARRAY "$PKGS_ARRAY" '{"pnames": $PKGS_ARRAY}')" |
            jq -c '
                reduce .data[] as {
                    pname: $PKG_NAME,
                    exists: $EXISTS,
                    app: {
                        name: $APP_NAME,
                        link: $APP_URL
                    }
                } (
                    [];
                    if $EXISTS then
                        . += [{
                            "pkgName": $PKG_NAME,
                            "appName": $APP_NAME,
                            "appUrl": $APP_URL
                        }]
                    else
                        .
                    end
                )
            ' 2> /dev/null
        ); then
            rm "$SOURCE"-apps-*.json 2> /dev/null

            echo "$RESPONSE_JSON" | jq -c --argjson APPS_ARRAY "$APPS_ARRAY" '
                reduce .[] as {pkgName: $PKG_NAME, appName: $APP_NAME, appUrl: $APP_URL} (
                    $APPS_ARRAY;
                    if any(.[]; .pkgName == $PKG_NAME) | not then
                        . += [{
                            "pkgName": $PKG_NAME,
                            "appName": ($APP_NAME | sub("( -)|( &amp;)|:"; ""; "g") | sub("[()\\|]"; ""; "g") | sub(" *[-, ] *"; "-"; "g") | sub("-Wear-OS"; ""; "g")) | split("-")[:4] | join("-"),
                            "apkmirrorAppName": ($APP_URL | sub("-wear-os"; "") | match("(?<=\\/)(((?!\\/).)*)(?=\\/$)").string),
                            "developerName": ($APP_URL | match("(?<=apk\\/).*?(?=\\/)").string)
                        }]
                    else
                        .
                    end
            )' > "$SOURCE-apps-$PATCHES_VERSION.json" \
            2> /dev/null

        else
            notify msg "API request failed for apkmirror.com.\nTry again later..."
            return 1
        fi
    fi
}
