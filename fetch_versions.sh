#!/bin/bash

UserAgent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36"

appName="$1"
apkmirrorAppName="$2"
patchesSource="$3"
currentVersion="$4"
storagePath="$5"

page1=$(curl --fail-early --connect-timeout 2 --max-time 5 -sL -A "$UserAgent" "https://www.apkmirror.com/uploads/?appcategory=$apkmirrorAppName" 2>&1)

[ "$page1" == "" ] && echo error && exit 1

readarray -t versions < <(./pup -p 'div.widget_appmanager_recentpostswidget h5 a.fontBlack text{}' <<<"$page1")

supportedVers=$(jq -r --arg apkmirrorAppName "$apkmirrorAppName" '[.[] | select(.apkmirrorAppName == $apkmirrorAppName).versions[] | sub(" *[-, ] *"; "-"; "g")]' "$storagePath/$patchesSource-patches.json")

jq -r -n --arg appName "$appName-"\
    --arg currentVersion "$currentVersion"\
    --argjson supportedVers "$supportedVers"\
    '($currentVersion | sub(" *[-, ] *"; "-"; "g")) as $installedVer |
    [
        [
            $ARGS.positional[] |
            sub(" *[-, ] *"; "-"; "g") |
            sub(":"; "") |
            sub($appName; "")
        ] |
        . |= . + $supportedVers |
        unique |
        reverse |
        index($installedVer) as $index |
        if $index == null then
            .[]
        else
            .[0:($index + 1)][]
        end | . as $version |
        if (($supportedVers | index($version)) != null) then
            $version, "[SUPPORTED]"
        elif ($version | test("beta|Beta|BETA")) then
            $version | sub("(?<=[0-9])-[a-zA-Z]*$"; ""), "[BETA]"
        elif ($version | test("alpha|Alpha|ALPHA")) then
            $version | sub("(?<=[0-9])-[a-zA-Z]$"; ""), "[ALPHA]"
        else
            $version, "[STABLE]"
        end
    ] |
    if (. | index($installedVer)) != null then
        .[-1] |= "[INSTALLED]"
    else
        .
    end |
     if ((. | index("[SUPPORTED]")) != null) then
        . |= ["Auto Select", "[RECOMMENDED]"] + .
    else
        .
    end | 
    .[]' --args "${versions[@]}"
