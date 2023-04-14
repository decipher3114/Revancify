#!/bin/bash

UserAgent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36"

arch=$(getprop ro.product.cpu.abi)
apkmirrorAppName="$1"
patchesSource="$2"
path="$3"
pup="$path/binaries/pup_$arch"

page1=$(curl --fail-early --connect-timeout 2 --max-time 5 -sL -A "$UserAgent" "https://www.apkmirror.com/uploads/?appcategory=$apkmirrorAppName" 2>&1)

[ "$page1" == "" ] && echo error && exit 1

readarray -t versions < <("$pup" -p 'div.widget_appmanager_recentpostswidget h5 a.fontBlack text{}' <<<"$page1")

supportedVers=$(jq -r --arg apkmirrorAppName "$apkmirrorAppName" '.[] | select(.apkmirrorAppName == $apkmirrorAppName).versions' "$patchesSource-patches.json")

if [ "${supportedVers[*]}" != "[]" ]; then
    echo "Auto Select"
    echo "[RECOMMENDED]"
fi
jq -r -n --argjson supportedVers "$supportedVers" '$ARGS.positional[] |
    (. | match("(?<=\\s)\\w*[0-9].*\\w*[0-9]\\w*")).string as $version |
    if (($supportedVers | index($version)) != null) then
        ($version, "[SUPPORTED]")
    elif (. | test("beta|Beta|BETA")) then
        ($version, "[BETA]")
    elif (. | test("alpha|Alpha|ALPHA")) then
        ($version, "[ALPHA]")
    else
        ($version, "[STABLE]") 
    end' --args "${versions[@]}"