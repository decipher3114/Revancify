#!/usr/bin/bash

parsePatchesJson() {
    if [ ! -e "$SOURCE-patches-$PATCHES_VERSION.json" ] || [ ! -e "$SOURCE-apps.json" ]; then

        AVAILABLE_PATCHES='[]'

        "${DIALOG[@]}" \
            --mixedgauge \
            "Parsing JSON from patches file" \
            -1 -1 \
            0 \
            "Extracting Packages List" \
            7 \
            "Parsing Packages to JSON" \
            9 \
            "Fetch Packages List from Apkmirror"\
            9 \
            "Extracting Patches List" \
            9 \
            "Parsing Patches to JSON" \
            9 \

        tput civis

        readarray -d '' -t VERSIONS < <(java -jar "$CLI_FILE_NAME" list-versions "$PATCHES_FILE_NAME" -u | sed 's/INFO: //' | awk -v RS='' -v ORS='\0' '1')

        TOTAL="${#VERSIONS[@]}"

        CTR=0 && for PACKAGE in "${VERSIONS[@]}"; do
            "${DIALOG[@]}" \
                --mixedgauge \
                "Parsing JSON from patches file" \
                -1 -1 \
                20 \
                "Extracting Packages List" \
                3 \
                "Parsing Packages to JSON" \
                "-$(($(( CTR * 100)) / TOTAL))" \
                "Fetch Packages List from Apkmirror"\
                9 \
                "Extracting Patches List" \
                9 \
                "Parsing Patches to JSON" \
                9 \

            PKG_NAME=$(grep '^P' <<< "$PACKAGE" | sed 's/.*: //')

            readarray -t PKG_VERSIONS < <(grep $'\t' <<< "$PACKAGE" | sed 's/\t//')

            ((CTR++))

            AVAILABLE_PATCHES=$(jq -nc --arg PKG_NAME "$PKG_NAME" --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '
                $AVAILABLE_PATCHES + [{
                    "pkgName": $PKG_NAME,
                    "versions": (
                        $ARGS.positional |
                        if .[0] == "Any" then
                            []
                        else
                            (.[0] | match("\\(.*\\)").string) as $MAX |
                            [
                                .[] |
                                if test($MAX) then
                                    . | match("^[^ ]+").string
                                else
                                    empty
                                end
                            ]
                        end
                    )
                }]
                ' --args "${PKG_VERSIONS[@]}"
            )
            unset PKG_NAME PKG_VERSIONS
        done

        AVAILABLE_PATCHES=$(jq -nc --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '
            $AVAILABLE_PATCHES + [{"pkgName": null, "versions": []}]'
        )

        tput civis

        unset VERSIONS

        APPS_ARRAY=$(jq -rc '.' "$SOURCE-apps.json" 2> /dev/null || echo '[]')

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

            "${DIALOG[@]}" \
                --mixedgauge \
                "Parsing JSON from patches file" \
                -1 -1 \
                40 \
                "Extracting Packages List" \
                3 \
                "Parsing Packages to JSON" \
                3 \
                "Fetch Packages List from Apkmirror"\
                7 \
                "Extracting Patches List" \
                9 \
                "Parsing Patches to JSON" \
                9 \
        
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
                                    "appName": ($APP.name | sub("( -)|( &amp;)|:"; ""; "g") | sub("[()\\|]"; ""; "g") | sub(" *[-, ] *"; "-"; "g") | sub("-Wear-OS"; ""; "g")),
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
                notify msg "API request failed for apkmirror.com.\Try again later..."
                return 1
            fi
        fi
        tput civis
        unset APPS_ARRAY PKGS_ARRAY

        "${DIALOG[@]}" \
            --mixedgauge \
            "Parsing JSON from patches file" \
            -1 -1 \
            60 \
            "Extracting Packages List" \
            3 \
            "Parsing Packages to JSON" \
            3 \
            "Fetch Packages List from Apkmirror"\
            3 \
            "Extracting Patches List" \
            7 \
            "Parsing Patches to JSON" \
            9 \

        tput civis

        readarray -d '' -t PATCHES < <(java -jar "$CLI_FILE_NAME" list-patches "$PATCHES_FILE_NAME" -iopd | sed 's/INFO: //' | awk -v RS='' -v ORS='\0' '1')

        TOTAL="${#PATCHES[@]}"

        CTR=0 && for PATCH in "${PATCHES[@]}"; do

            "${DIALOG[@]}" \
                --mixedgauge \
                "Parsing JSON from patches file" \
                -1 -1 \
                80 \
                "Extracting Packages List" \
                3 \
                "Parsing Packages to JSON" \
                3 \
                "Fetch Packages List from Apkmirror"\
                3 \
                "Extracting Patches List" \
                3 \
                "Parsing Patches to JSON" \
                "-$(($(( CTR * 100)) / TOTAL))"

            PATCH_NAME=$(grep '^N' <<< "$PATCH" | sed 's/.*: //')
            PATCH=$(sed '/^N/d;/^E/d' <<< "$PATCH")
            if grep -q '^C' <<< "$PATCH"; then
                readarray -t PACKAGES < <(grep $'^\tPackage' <<< "$PATCH" | sed 's/.*: //;s/ //g')
                PATCH=$(sed '/^C/d;/^Pa/d' <<< "$PATCH")
            fi

            OPTIONS_ARRAY='[]'
            if grep -q "Options:" <<< "$PATCH"; then
                PATCH=$(sed '/^O/d;s/^\t//g' <<< "$PATCH")
                readarray -d '' -t OPTIONS < <(awk -v RS='\n\nTitle' -v ORS='\0' '1' <<< "$PATCH")

                for OPTION in "${OPTIONS[@]}"; do

                    TITLE=$(grep -E '^Title:|^:' <<< "$OPTION" | sed 's/.*: //;')
                    KEY=$(grep '^K' <<< "$OPTION" | sed 's/.*: //;s/ //g')
                    DESCRIPTION=$(grep '^Des' <<< "$OPTION" | sed 's/.*: //')
                    REQUIRED=$(grep '^R' <<< "$OPTION" | sed 's/.*: //')
                    DEFAULT_VALUE=$(grep '^Def' <<< "$OPTION" | sed 's/.*: //')
                    VALUE_TYPE=$(grep '^Ty' <<< "$OPTION" | sed 's/.*: //;s/ //')

                    if grep -q "^Po" <<< "$OPTION"; then
                        readarray -t VALUES < <(grep $'^\t' <<< "$OPTION" | sed 's/\t//')
                    fi

                    OPTIONS_ARRAY=$(jq -nc --arg PATCH_NAME "$PATCH_NAME" --arg TITLE "$TITLE" --arg KEY "$KEY" --arg DESCRIPTION "$DESCRIPTION" --arg REQUIRED "$REQUIRED" --arg DEFAULT_VALUE "$DEFAULT_VALUE" --arg VALUE_TYPE "$VALUE_TYPE" --argjson OPTIONS_ARRAY "$OPTIONS_ARRAY" '
                        ($VALUE_TYPE |
                        if test("List") then
                            "StringArray"
                        elif test("Boolean") then
                            "Boolean"
                        elif test("Long|Int|Float") then
                            "Number"
                        else
                            "String"
                        end) as $VALUE_TYPE |
                        ($DEFAULT_VALUE |
                        if . != "" then
                            (if $VALUE_TYPE == "String" then
                                tostring
                            elif $VALUE_TYPE == "Number" then
                                tonumber
                            elif $VALUE_TYPE == "Boolean" then
                                test("true")
                            elif $VALUE_TYPE == "StringArray" then
                                gsub("(?<a>([^,\\[\\] ]+))" ; "\"" + .a + "\"") | fromjson
                            end)
                        else
                            null
                        end) as $DEFAULT_VALUE |
                        . += [{
                            "patchName": $PATCH_NAME,
                            "title": $TITLE,
                            "key": $KEY,
                            "description": $DESCRIPTION,
                            "required": $REQUIRED,
                            "defaultValue": $DEFAULT_VALUE,
                            "valueType": $VALUE_TYPE,
                            "values": $ARGS.positional
                        }]' --args "${VALUES[@]}"
                    )
                    unset TITLE KEY DESCRIPTION REQUIRED DEFAULT_VALUE VALUE_TYPE VALUES
                done
                unset OPTIONS
            fi
            ((CTR++))
            AVAILABLE_PATCHES=$(jq -nc --arg PATCH_NAME "$PATCH_NAME" --argjson OPTIONS_ARRAY "$OPTIONS_ARRAY" --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '
                $ARGS.positional as $COMPATIBLE_PACKAGES |
                    $AVAILABLE_PATCHES |
                    reduce ($COMPATIBLE_PACKAGES[] // null) as $PKG_NAME (
                        .;
                        map(
                            if .pkgName == $PKG_NAME then
                                .patches += [$PATCH_NAME] |
                                .options += $OPTIONS_ARRAY
                            else
                                .
                            end
                        )
                    )
                ' --args "${PACKAGES[@]}"
            )
            unset PATCH_NAME PACKAGES OPTIONS_ARRAY
        done

        tput civis

        unset PATCHES CTR TOTAL

        jq -nc --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '$AVAILABLE_PATCHES' > "$SOURCE-patches-$PATCHES_VERSION.json"

        "${DIALOG[@]}" \
                --mixedgauge \
                "Parsing JSON from patches file" \
                -1 -1 \
                100 \
                "Extracting Packages List" \
                3 \
                "Parsing Packages to JSON" \
                3 \
                "Fetch Packages List from Apkmirror"\
                3 \
                "Extracting Patches List" \
                3 \
                "Parsing Patches to JSON" \
                3
        tput civis
        sleep 0.5
    fi
    
    [ -n "$AVAILABLE_PATCHES" ] || AVAILABLE_PATCHES=$(jq -rc '.' "$SOURCE-patches-$PATCHES_VERSION.json")
    [ -n "$APPS_INFO" ] || APPS_INFO=$(jq -rc '.' "$SOURCE-apps.json")
    [ -n "$APPS_LIST" ] || readarray -t APPS_LIST < <(jq -nrc --argjson APPS_INFO "$APPS_INFO" '$APPS_INFO[] | .pkgName, .appName')
    [ -n "$ENABLED_PATCHES" ] || ENABLED_PATCHES=$(jq -rc '.' "$STORAGE/$SOURCE-patches.json" 2> /dev/null || echo '[]')
    return 0
}
