#!/usr/bin/bash

parseJsonFromCLI() {
    local PACKAGES PATCHES TOTAL CTR OPTIONS_ARRAY

    AVAILABLE_PATCHES='[]'

    readarray -d '' -t PACKAGES < <(java -jar "$CLI_FILE" list-versions "$PATCHES_FILE" -u | sed 's/INFO: //' | awk -v RS='' -v ORS='\0' '1')

    readarray -d '' -t PATCHES < <(java -jar "$CLI_FILE" list-patches "$PATCHES_FILE" -iopd | sed 's/INFO: //' | awk -v RS='' -v ORS='\0' '1')

    TOTAL=$((${#PACKAGES[@]} + ${#PATCHES[@]}))

    CTR=0

    for PACKAGE in "${PACKAGES[@]}"; do

        PKG_NAME=$(grep '^P' <<< "$PACKAGE" | sed 's/.*: //')

        readarray -t PKG_VERSIONS < <(grep $'\t' <<< "$PACKAGE" | sed 's/\t//')

        AVAILABLE_PATCHES=$(
            jq -nc --arg PKG_NAME "$PKG_NAME" --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '
            $AVAILABLE_PATCHES + [{
                "pkgName": $PKG_NAME,
                "versions": (
                    $ARGS.positional |
                    if .[0] == "Any" then
                        []
                    else
                        [ .[] | match(".*(?= \\()").string ]
                    end |
                    sort
                ),
                "patches": {
                    "recommended": [],
                    "optional": []
                },
                "options": []
            }]
            ' --args "${PKG_VERSIONS[@]}"
        )
        unset PACKAGE PKG_NAME PKG_VERSIONS

        ((CTR++))
        echo "$(((CTR * 100) / TOTAL))"
    done
    unset PACKAGES

    AVAILABLE_PATCHES=$(
        jq -nc --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '
            $AVAILABLE_PATCHES + [{
                "pkgName": null,
                "versions": [],
                "patches": {
                    "recommended": [],
                    "optional": []
                },
                "options": []
            }]
        '
    )

    for PATCH in "${PATCHES[@]}"; do

        PATCH_NAME=$(grep '^Name:' <<< "$PATCH" | sed 's/.*: //')
        USE=$(grep '^Enabled:' <<< "$PATCH" | sed 's/.*: //')
        PATCH=$(sed '/^Name:/d;/^Enabled:/d' <<< "$PATCH")

        if grep -q '^C' <<< "$PATCH"; then
            readarray -t PACKAGES < <(grep $'^\tPackage name:' <<< "$PATCH" | sed 's/.*: //;s/ //g')
            PATCH=$(sed '/^Compatible packages:/d;/^\tPackage name:/d' <<< "$PATCH")
        fi

        OPTIONS_ARRAY='[]'
        if grep -q "Options:" <<< "$PATCH"; then
            PATCH=$(sed '/^Options:/d;s/^\t//g' <<< "$PATCH")
            readarray -d '' -t OPTIONS < <(awk -v RS='\n\nTitle' -v ORS='\0' '1' <<< "$PATCH")

            for OPTION in "${OPTIONS[@]}"; do

                KEY=$(grep '^Key:' <<< "$OPTION" | sed 's/.*: //;s/ //g')
                TITLE=$(grep -E '^Title:|^:' <<< "$OPTION" | sed 's/.*: //;')
                REQUIRED=$(grep '^Required:' <<< "$OPTION" | sed 's/.*: //')
                DEFAULT=$(grep '^Default:' <<< "$OPTION" | sed 's/.*: //')
                TYPE=$(grep '^Type:' <<< "$OPTION" | sed 's/.*: //;s/ //')

                if grep -q "^Possible values:" <<< "$OPTION"; then
                    readarray -t VALUES < <(grep $'^\t' <<< "$OPTION" | sed 's/\t//')
                fi

                OPTION=$(sed '/^Key:/d;/^Title:/d;/^:/d;/^Required:/d;/^Default:/d;/^Type:/d;/^Possible values:/d;/^\t/d' <<< "$OPTION")

                DESCRIPTION=$(sed 's/^Description: //;s/\n/\\n/g' <<< "$OPTION")

                OPTIONS_ARRAY=$(
                    jq -nc \
                        --arg PATCH_NAME "$PATCH_NAME" \
                        --arg KEY "$KEY" \
                        --arg TITLE "$TITLE" \
                        --arg DESCRIPTION "$DESCRIPTION" \
                        --arg REQUIRED "$REQUIRED" \
                        --arg DEFAULT "$DEFAULT" \
                        --arg TYPE "$TYPE" \
                        --arg STRING "$STRING" \
                        --arg NUMBER "$NUMBER" \
                        --arg BOOLEAN "$BOOLEAN" \
                        --arg STRINGARRAY "$STRINGARRAY" \
                        --argjson OPTIONS_ARRAY "$OPTIONS_ARRAY" '
                        (
                            $TYPE |
                            if test("List") then
                                $STRINGARRAY
                            elif test("Boolean") then
                                $BOOLEAN
                            elif test("Long|Int|Float") then
                                $NUMBER
                            else
                                $STRING
                            end
                        ) as $TYPE |
                        (
                            $DEFAULT |
                            if . != "" then
                                (
                                    if $TYPE == $STRING then
                                        tostring
                                    elif $TYPE == $NUMBER then
                                        tonumber
                                    elif $TYPE == $BOOLEAN then
                                        toboolean
                                    elif $TYPE == $STRINGARRAY then
                                        (gsub("(?<a>([^,\\[\\] ]+))" ; "\"" + .a + "\"") | fromjson)
                                    end
                                )
                            else
                                null
                            end
                        ) as $DEFAULT |
                        $OPTIONS_ARRAY + [{
                            "patchName": $PATCH_NAME,
                            "key": $KEY,
                            "title": $TITLE,
                            "description": $DESCRIPTION,
                            "required": ($REQUIRED | toboolean),
                            "type": $TYPE,
                            "default": $DEFAULT,
                            "values": $ARGS.positional
                        }]
                    ' --args "${VALUES[@]}"
                )
                unset TITLE KEY DESCRIPTION REQUIRED DEFAULT TYPE VALUES
            done
            unset OPTIONS
        fi

        AVAILABLE_PATCHES=$(
            jq -nc --arg PATCH_NAME "$PATCH_NAME" --arg USE "$USE" --argjson OPTIONS_ARRAY "$OPTIONS_ARRAY" --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '
                $ARGS.positional as $COMPATIBLE_PACKAGES |
                $AVAILABLE_PATCHES |
                reduce ($COMPATIBLE_PACKAGES[] // null) as $PKG_NAME (
                    .;
                    map(
                        if .pkgName == $PKG_NAME then
                            .patches |= (
                                if ($USE | toboolean) then
                                    .recommended += [$PATCH_NAME]
                                else
                                    .optional += [$PATCH_NAME]
                                end
                            ) |
                            .options += $OPTIONS_ARRAY
                        else
                            .
                        end
                    )
                )
            ' --args "${PACKAGES[@]}"
        )
        unset PATCH PATCH_NAME PACKAGES OPTIONS_ARRAY

        ((CTR++))
        echo "$(((CTR * 100) / TOTAL))"
    done

    unset TOTAL CTR PATCHES

    echo "$AVAILABLE_PATCHES" > "assets/$SOURCE/Patches-$PATCHES_VERSION.json"
}
