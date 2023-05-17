#!/bin/bash

UserAgent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36"

arch=$(getprop ro.product.cpu.abi)
apkmirrorAppName="$1"
patchesSource="$2"
path="$3"
pup="$path/binaries/pup_$arch"
currentVersion="$4"
storagePath="$5"

page1=$(curl --fail-early --connect-timeout 2 --max-time 5 -sL -A "$UserAgent" "https://www.apkmirror.com/uploads/?appcategory=$apkmirrorAppName" 2>&1)

[ "$page1" == "" ] && echo error && exit 1

readarray -t versions < <("$pup" -p 'div.widget_appmanager_recentpostswidget h5 a.fontBlack text{}' <<<"$page1")

supportedVers=$(jq -r --arg apkmirrorAppName "$apkmirrorAppName" '.[] | select(.apkmirrorAppName == $apkmirrorAppName).versions' "$storagePath/$patchesSource-patches.json")

finalList=$(jq -r -n --arg currentVersion "$currentVersion" --argjson supportedVers "$supportedVers" '$ARGS.positional | sort | reverse as $versionsList |
    [ $versionsList[] | (. | match("(?<=\\s)\\w*[0-9].*\\w*[0-9]\\w*")).string] |
    if $currentVersion != "" then
        if (. | index($currentVersion)) != null then
            .
        else
            (. += [$currentVersion])
        end | .
    else . end | unique |
    reverse as $array |
    $array[:($array | index($currentVersion))][] |
    . as $item |
    ($array | index($item)) as $index |
    ($versionsList[$index]) as $version |
    if (($supportedVers | index($item)) != null) then
        ($item, "[SUPPORTED]")
    elif ($version | test("beta|Beta|BETA")) then
        ($item, "[BETA]")
    elif ($version | test("alpha|Alpha|ALPHA")) then
        ($item, "[ALPHA]")
    else
        ($item, "[STABLE]")
    end
    ' --args "${versions[@]}")

if [ "${supportedVers[*]}" != "[]" ] && [ "$currentVersion" != "" ] && grep -q "SUPPORTED" <<< "${finalList[*]}"; then
    echo "Auto Select"
    echo "[RECOMMENDED]"
fi

[ "${finalList[*]}" != "" ] && echo "${finalList[@]}"
[ "$currentVersion" != "" ] && echo -e "$currentVersion\n[INSTALLED]"