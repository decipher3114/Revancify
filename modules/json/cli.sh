#!/usr/bin/bash

parseJsonFromCLI() {
    local PACKAGES PATCHES TOTAL CTR OPTIONS_ARRAY

    AVAILABLE_PATCHES='[]'

    readarray -d '' -t PACKAGES < <(java -jar "$CLI_FILE_NAME" list-versions "$PATCHES_FILE_NAME" -u | sed 's/INFO: //' | awk -v RS='' -v ORS='\0' '1')

    readarray -d '' -t PATCHES < <(java -jar "$CLI_FILE_NAME" list-patches "$PATCHES_FILE_NAME" -iopd | sed 's/INFO: //' | awk -v RS='' -v ORS='\0' '1')

    TOTAL=$(( ${#PACKAGES[@]} + ${#PATCHES[@]}))

    CTR=0

    for PACKAGE in "${PACKAGES[@]}"; do

        PKG_NAME=$(grep '^P' <<< "$PACKAGE" | sed 's/.*: //')

        readarray -t PKG_VERSIONS < <(grep $'\t' <<< "$PACKAGE" | sed 's/\t//')

        AVAILABLE_PATCHES=$(jq -nc --arg PKG_NAME "$PKG_NAME" --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '
            $AVAILABLE_PATCHES + [{
                "pkgName": $PKG_NAME,
                "versions": (
                    $ARGS.positional |
                    if .[0] == "Any" then
                        []
                    else
                        [ .[] | match("^[^ ]+").string ]
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

        (( CTR++ ))
        echo "$(( ( CTR * 100 ) / TOTAL ))"
    done
    unset PACKAGES

    AVAILABLE_PATCHES=$(jq -nc --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '
        $AVAILABLE_PATCHES + [{
            "pkgName": null,
            "versions": [],
            "patches": {
                "recommended": [],
                "optional": []
            },
            "options": []
        }]'
    )

    for PATCH in "${PATCHES[@]}"; do

        PATCH_NAME=$(grep '^N' <<< "$PATCH" | sed 's/.*: //')
        USE=$(grep '^E' <<< "$PATCH" | sed 's/.*: //')
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

                KEY=$(grep '^K' <<< "$OPTION" | sed 's/.*: //;s/ //g')
                TITLE=$(grep -E '^Title:|^:' <<< "$OPTION" | sed 's/.*: //;')
                DESCRIPTION=$(grep '^Des' <<< "$OPTION" | sed 's/.*: //')
                REQUIRED=$(grep '^R' <<< "$OPTION" | sed 's/.*: //')
                DEFAULT=$(grep '^Def' <<< "$OPTION" | sed 's/.*: //')
                TYPE=$(grep '^Ty' <<< "$OPTION" | sed 's/.*: //;s/ //')

                if grep -q "^Po" <<< "$OPTION"; then
                    readarray -t VALUES < <(grep $'^\t' <<< "$OPTION" | sed 's/\t//')
                fi

                OPTIONS_ARRAY=$(jq -nc --arg PATCH_NAME "$PATCH_NAME" --arg KEY "$KEY" --arg TITLE "$TITLE" --arg DESCRIPTION "$DESCRIPTION" --arg REQUIRED "$REQUIRED" --arg DEFAULT "$DEFAULT" --arg TYPE "$TYPE" --argjson OPTIONS_ARRAY "$OPTIONS_ARRAY" '
                    (
                        $TYPE |
                        if test("List") then
                            "StringArray"
                        elif test("Boolean") then
                            "Boolean"
                        elif test("Long|Int|Float") then
                            "Number"
                        else
                            "String"
                        end
                    ) as $TYPE |
                    (
                        $DEFAULT |
                        if . != "" then
                            (
                                if $TYPE == "String" then
                                    tostring
                                elif $TYPE == "Number" then
                                    tonumber
                                elif $TYPE == "Boolean" then
                                    test("true")
                                elif $TYPE == "StringArray" then
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
                        "required": $REQUIRED,
                        "default": $DEFAULT,
                        "type": $TYPE,
                        "values": $ARGS.positional
                    }]' --args "${VALUES[@]}"
                )
                unset TITLE KEY DESCRIPTION REQUIRED DEFAULT TYPE VALUES
            done
            unset OPTIONS
        fi

        AVAILABLE_PATCHES=$(jq -nc --arg PATCH_NAME "$PATCH_NAME" --arg USE "$USE" --argjson OPTIONS_ARRAY "$OPTIONS_ARRAY" --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '
            $ARGS.positional as $COMPATIBLE_PACKAGES |
                $AVAILABLE_PATCHES |
                reduce ($COMPATIBLE_PACKAGES[] // null) as $PKG_NAME (
                    .;
                    map(
                        if .pkgName == $PKG_NAME then
                            .patches |= (
                                if ($USE | test("true")) then
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

        (( CTR++ ))
        echo "$(( ( CTR * 100 ) / TOTAL ))"
    done

    unset TOTAL CTR PATCHES

    echo "$AVAILABLE_PATCHES" > "$SOURCE-patches-$PATCHES_VERSION.json"
}
