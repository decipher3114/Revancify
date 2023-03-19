#!/bin/bash

source="$1"

patchesJson=$(cat "$source"-patches-*.json | jq '.')

includedPatches=$(jq '.' "$source-patches.json" 2>/dev/null || jq -n '[]')

allPackages=$(echo "$patchesJson" | jq '[.[].compatiblePackages[].name]')

pkgs=$(jq -n --argjson allPackages "$allPackages" '[$allPackages | to_entries[] | .value as $pkg | map($allPackages | to_entries[] | select(.value == $pkg).key)[0] as $index | if $index == .key then $pkg else empty end]')

generatedJson=$(jq --null-input --argjson pkgs "$pkgs" --argjson includedPatches "$includedPatches" --argjson patchesJson "$patchesJson" '
[
    $pkgs[] | . as $pkgName | 
    {
        "pkgName": .,
        "appName": (
            if (($includedPatches | length) != 0) then
                ($includedPatches[] | select(.pkgName == $pkgName) |
                    if (.appName != null) then
                        .appName
                    else
                        null
                    end)
            else 
                null
            end
        ),
        "apkmirrorAppName": (
            if (($includedPatches | length) != 0) then
                ($includedPatches[] | select(.pkgName == $pkgName) |
                    if (.apkmirrorAppName != null) then
                        .apkmirrorAppName
                    else 
                        null
                    end)
            else
                null
            end
        ),
        "developerName": (
            if (($includedPatches | length) != 0) then
                ($includedPatches[] | select(.pkgName == $pkgName) |
                    if (.developerName != null) then
                        .developerName
                    else
                        null
                    end)
            else
                null
            end
        ),
        "versions": (
            [$patchesJson[] | .compatiblePackages |
                if ((map(.name) | index($pkgName)) != null) then
                    .[(map(.name) | index($pkgName))].versions[]
                else
                    empty
                end] |
                unique
        ),
        "includedPatches": (
            if (($includedPatches | length) != 0) then
                [
                    (($includedPatches[] | select(.pkgName == $pkgName)) |
                        if ((.includedPatches | length) == null) then
                            ($patchesJson[] | .name as $patchName | .excluded as $excluded | .compatiblePackages | if ((((map(.name) | index($pkgName)) != null) or (length == 0)) and ($excluded == false)) then $patchName else empty end)
                        elif ((.includedPatches | length) == 0) then
                            ($patchesJson[] | .name as $patchName | .excluded as $excluded | .compatiblePackages | if ((((map(.name) | index($pkgName)) != null) or (length == 0)) and ($excluded == false)) then $patchName else empty end)
                        else
                            .includedPatches[]
                        end)
                ]
            else
                [($patchesJson[] | .name as $patchName | .excluded as $excluded | .compatiblePackages | if ((((map(.name) | index($pkgName)) != null) or (length == 0)) and ($excluded == false)) then $patchName else empty end)]
            end
        )
    }
]')

if [ "$2" == "online" ]; then
    response=$(curl --fail-early --connect-timeout 2 --max-time 5 -s 'https://www.apkmirror.com/wp-json/apkm/v1/app_exists/' \
        -H 'Accept: application/json' \
        -H 'Content-Type: application/json' \
        -H 'Authorization: Basic YXBpLXRvb2xib3gtZm9yLWdvb2dsZS1wbGF5OkNiVVcgQVVMZyBNRVJXIHU4M3IgS0s0SCBEbmJL' \
        -H 'User-Agent: Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.5414.86 Mobile Safari/537.36' \
        -d "$(jq -n --argjson pkgs "$pkgs" '{"pnames": $pkgs}')")

    if ! responseJson=$(
        jq -n --argjson response "$response" '[$response.data[] |
            if .exists then
                ({
                    "key": (.pname),
                    "value": {
                        "appName": (.app.name | sub("\\s\\(.*\\)"; ""; "x") | sub("&amp;"; "") | sub("[^0-9a-zA-Z]+"; "-"; "sg")),
                        "apkmirrorAppName": (.app.link | sub("-wear-os"; "") | match("(?<=\\/)(((?!\\/).)*)(?=\\/$)").string),
                        "developerName": (.app.link | match("(?<=apk\\/).*?(?=\\/)").string)
                    }
                })
            else
                empty
            end] | from_entries' 2>/dev/null
    ); then
        echo error
        exit 1
    fi
    generatedJson=$(
        jq -n --argjson generatedJson "$generatedJson" --argjson responseJson "$responseJson" '[
                $generatedJson[] | .pkgName as $pkgName | (.appName = ($responseJson[$pkgName].appName)) | (.apkmirrorAppName = ($responseJson[$pkgName].apkmirrorAppName)) | (.developerName = ($responseJson[$pkgName].developerName))]'
    )
fi

echo "$generatedJson" | jq '.' >"$source-patches.json"
