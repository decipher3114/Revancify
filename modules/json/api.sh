#!/usr/bin/bash

parseJsonFromAPI() {
    local RESPONSE
    
    notify info "Please Wait!!\nParsing JSON file for $SOURCE patches from API."

    if ! RESPONSE=$("${CURL[@]}" "$JSON_URL" | jq -c '.' 2> /dev/null); then
        unset JSON_URL
        notify info "Unable to access API!!\nFalling back to CLI method..."
        sleep 1
        return 1
    fi

    AVAILABLE_PATCHES=$(jq -c '
        reduce .[] as {
            name: $PATCH,
            use: $USE,
            compatiblePackages: $COMPATIBLE_PKGS,
            options: $OPTIONS
        } (
            [];
            (
                $OPTIONS |
                if length != 0 then
                    map(
                        . |= {"patchName": $PATCH} + . |
                        .description |= split("\n")[0] |
                        .type |= (
                            if test("List") then
                                "StringArray"
                            elif test("Boolean") then
                                "Boolean"
                            elif test("Long|Int|Float") then
                                "Number"
                            else
                                "String"
                            end
                        ) |
                        .values |= (
                            if . != null then
                                [to_entries[] | (.value | tostring) + " (" + .key + ")"]
                            else
                                []
                            end
                        )
                    )
                else
                    .
                end
            ) as $OPTIONS |
            [
                $COMPATIBLE_PKGS |
                if . == null then
                    {"name": null, "versions":[]}
                else
                    to_entries[] |
                    {"name": .key, "versions": (.value // [])}
                end
            ] as $COMPATIBLE_PKGS |
            reduce $COMPATIBLE_PKGS[] as {name: $PKG_NAME, versions: $VERSIONS} (
                .;
                if any(.[]; .pkgName == $PKG_NAME) then
                    .
                else
                    . |= .[0:-1] + [
                        {
                            "pkgName": $PKG_NAME,
                            "versions": [],
                            "patches": {
                                "recommended": [],
                                "optional": []
                            },
                            "options": []
                        }
                    ] + .[-1:]
                end |
                map(
                    if .pkgName == $PKG_NAME then
                        .versions |= (. += $VERSIONS | unique | sort) |
                        .patches |= (
                            if $USE then
                                .recommended += [$PATCH]
                            else
                                .optional += [$PATCH]
                            end
                        ) |
                        .options += $OPTIONS
                    else
                        .
                    end
                )
            )
        )' <<< "$RESPONSE" > "$SOURCE-patches-$PATCHES_VERSION.json" 2> /dev/null
    )
}
