#!/usr/bin/bash

terminate() {
    killall -9 java &> /dev/null
    killall -9 dialog &> /dev/null
    killall -9 wget &> /dev/null
    clear
    exit "${1:-1}"
}
trap terminate SIGTERM SIGINT SIGABRT

setEnv() {
    if [ ! -f "$4" ]; then
        : > "$4"
    fi
    if ! grep -q "${1}=" "$4"; then
        echo "$1=$2" >> "$4"
    elif [ "$3" == "update" ]; then
        sed -i "s/$1=.*/$1=$2/" "$4"
    fi
}

initialize() {
    internalStorage="/storage/emulated/0"
    storagePath="$internalStorage/Revancify"
    [ ! -d "$storagePath" ] && mkdir -p "$storagePath"
    [ ! -d apps ] && mkdir -p apps
    arch=$(getprop ro.product.cpu.abi)
    repoDir="$HOME/Revancify"
    header=(dialog --backtitle "Revancify | [Arch: $arch, Root: $root]" --no-shadow)
    envFile=config.cfg
    [ ! -f "apps/.appSize" ] && : > "apps/.appSize"
    userAgent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"

    AutocheckToolsUpdate="" Riplibs="" LightTheme="" ShowConfirmPatchesMenu="" LaunchAppAfterMount="" AllowVersionDowngrade="" FetchPreReleasedTools=""
    setEnv AutocheckToolsUpdate false init "$envFile"
    setEnv Riplibs true init "$envFile"
    setEnv PreferSplitApk true init "$envFile"
    setEnv LightTheme false init "$envFile"
    setEnv ShowConfirmPatchesMenu false init "$envFile"
    setEnv LaunchAppAfterMount true init "$envFile"
    setEnv AllowVersionDowngrade false init "$envFile"
    setEnv FetchPreReleasedTools false init "$envFile"
    source "$envFile"
    if [ -z "$source" ]; then
        readarray -t allSources < <(jq -r --arg source "$source" 'to_entries | .[] | .key,"["+.value.projectName+"]","on"' "$repoDir"/sources.json)
        source=$("${header[@]}" --begin 2 0 --title '| Source Selection Menu |' --no-cancel --ok-label "Done" --radiolist "Use arrow keys to navigate; Press Spacebar to select option" -1 -1 0 "${allSources[@]}" 2>&1 >/dev/tty)
        setEnv source "$source" update "$envFile"
    fi
    [ "$root" == true ] && menuEntry="Uninstall Patched app" || menuEntry="Download Microg"

    [ "$LightTheme" == true ] && theme=Light || theme=Dark
    export DIALOGRC="$repoDir/configs/.dialogrc$theme"

    source <(jq -r --arg source "$source" '.[$source].sources | to_entries[] | .key+"Source="+.value.org' "$repoDir"/sources.json)
    sourceName=$(jq -r --arg source "$source" '.[$source].projectName' "$repoDir"/sources.json)

    if [ "$online" != false ]; then
        if [ "$AutocheckToolsUpdate" == true ]; then
            getTools || terminate 1
        else
            checkTools || terminate 1
        fi
    fi

    if [ -e "$storagePath/$source-patches.json" ]; then
        bash "$repoDir/fetch_patches.sh" "$patchesSource" offline "$storagePath" &> /dev/null
        refreshJson || return 1
    fi
}

internet() {
    if ! ping -c 1 google.com &> /dev/null; then
        "${header[@]}" --msgbox "Oops! No Internet Connection available.\n\nConnect to Internet and try again later." 12 45
        return 1
    fi
}

fetchToolsAPI() {
    internet || return 1

    "${header[@]}" --infobox "Please Wait !!\nFetching tools data from github API..." 12 45
    readarray -t tools < <(jq -r --arg source "$source" '.[$source].sources | keys_unsorted[]' "$repoDir"/sources.json)
    readarray -t links < <(jq -r --arg source "$source" '.[$source].sources[] | .org+"/"+.repo' "$repoDir"/sources.json)
    : >".${source}-data"
    [ "$FetchPreReleasedTools" == false ] && stableRelease="/latest" || stableRelease=""
    i=0 && for tool in "${tools[@]}"; do
        curl -s --fail-early --connect-timeout 2 --max-time 5 "https://api.github.com/repos/${links[$i]}/releases$stableRelease" | jq -r --arg tool "$tool" 'if type == "array" then .[0] else . end | $tool+"Latest="+.tag_name, (.assets[] | if .content_type == "application/json" then "jsonUrl="+.browser_download_url, "jsonSize="+(.size|tostring) elif .content_type == "application/pgp-keys" then empty else $tool+"Url="+.browser_download_url, $tool+"Size="+(.size|tostring) end)' >>".${source}-data"
        i=$(("$i" + 1))
    done

    if [ "$(wc -l <".${source}-data")" -lt "11" ]; then
        "${header[@]}" --msgbox "Oops! Unable to connect to Github.\n\nRetry or change your Network." 12 45
        return 1
    fi
    source ./".${source}-data"

    cliAvailableSize=$(ls "$cliSource"-cli-*.jar &> /dev/null && du -b "$cliSource"-cli-*.jar | cut -d $'\t' -f 1 || echo 0)
    patchesAvailableSize=$(ls "$patchesSource"-patches-*.jar &> /dev/null && du -b "$patchesSource"-patches-*.jar | cut -d $'\t' -f 1 || echo 0)
    integrationsAvailableSize=$(ls "$integrationsSource"-integrations-*.apk &> /dev/null && du -b "$integrationsSource"-integrations-*.apk | cut -d $'\t' -f 1 || echo 0)
}

getTools() {
    fetchToolsAPI || return 1
    if [ -e "$patchesSource-patches-$patchesLatest.jar" ] && [ -e "$patchesSource-patches-$patchesLatest.json" ] && [ -e "$cliSource-cli-$cliLatest.jar" ] && [ -e "$integrationsSource-integrations-$integrationsLatest.apk" ] && [ "$cliSize" == "$cliAvailableSize" ] && [ "$patchesSize" == "$patchesAvailableSize" ] && [ "$integrationsSize" == "$integrationsAvailableSize" ]; then
        if [ "$(bash "$repoDir/fetch_patches.sh" "$patchesSource" online "$storagePath")" == "error" ]; then
            "${header[@]}" --msgbox "Tools are successfully downloaded but Apkmirror API is not accessible. So, patches are not successfully synced.\nRevancify may crash.\n\nChange your network." 12 45
            return 1
        fi
        "${header[@]}" --msgbox "Tools are already downloaded !!\n\nPatches are successfully synced." 12 45
        return 0
    fi
    [ -e "$patchesSource-patches-$patchesLatest.jar" ] || { rm "$patchesSource"-patches-*.jar &> /dev/null && rm "$patchesSource"-patches-*.json &> /dev/null && patchesAvailableSize=0 ;}
    [ -e "$cliSource-cli-$cliLatest.jar" ] || { rm "$cliSource"-cli-*.jar &> /dev/null && cliAvailableSize=0 ;}
    [ -e "$integrationsSource-integrations-$integrationsLatest.apk" ] || { rm "$integrationsSource"-integrations-*.apk &> /dev/null && integrationsAvailableSize=0 ;}
    [ "$cliSize" != "$cliAvailableSize" ] &&
        wget -q -c "$cliUrl" -O "$cliSource"-cli-"$cliLatest".jar --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "Source  : $cliSource\nTool    : CLI\nVersion : $cliLatest\nSize    : $(numfmt --to=iec --format="%0.1f" "$cliSize")\n\nDownloading..." -1 -1 "$(($((cliAvailableSize * 100)) / cliSize))" && tput civis

    [ "$cliSize" != "$(ls "$cliSource"-cli-*.jar &> /dev/null && du -b "$cliSource"-cli-*.jar | cut -d $'\t' -f 1 || echo 0)" ] && "${header[@]}" --msgbox "Oops! Unable to download completely.\n\nRetry or change your Network." 12 45 && return 1

    [ "$patchesSize" != "$patchesAvailableSize" ] &&
        wget -q -c "$patchesUrl" -O "$patchesSource"-patches-"$patchesLatest".jar --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "Source  : $patchesSource\nTool    : Patches\nVersion : $patchesLatest\nSize    : $(numfmt --to=iec --format="%0.1f" "$patchesSize")\n\nDownloading..." -1 -1 "$(($((patchesAvailableSize * 100 / patchesSize))))" && tput civis && patchesUpdated=true

    wget -q -c "$jsonUrl" -O "$patchesSource"-patches-"$patchesLatest".json --user-agent="$userAgent"

    [ "$patchesSize" != "$(ls "$patchesSource"-patches-*.jar &> /dev/null && du -b "$patchesSource"-patches-*.jar | cut -d $'\t' -f 1 || echo 0)" ] && "${header[@]}" --msgbox "Oops! Unable to download completely.\n\nRetry or change your Network." 12 45 && return 1

    [ "$integrationsSize" != "$integrationsAvailableSize" ] &&
        wget -q -c "$integrationsUrl" -O "$integrationsSource"-integrations-"$integrationsLatest".apk --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "Source  : $integrationsSource\nTool    : Integrations\nVersion : $integrationsLatest\nSize    : $(numfmt --to=iec --format="%0.1f" "$integrationsSize")\n\nDownloading..." -1 -1 "$(($((integrationsAvailableSize * 100 / integrationsSize))))" && tput civis

    [ "$integrationsSize" != "$(ls "$integrationsSource"-integrations-*.apk &> /dev/null && du -b "$integrationsSource"-integrations-*.apk | cut -d $'\t' -f 1 || echo 0)" ] && "${header[@]}" --msgbox "Oops! File not downloaded.\n\nRetry or change your Network." 12 45 && return 1

    if [ "$patchesUpdated" == true ]; then
        "${header[@]}" --infobox "Updating patches and options file..." 12 45
        if [ "$(bash "$repoDir/fetch_patches.sh" "$patchesSource" online "$storagePath")" == "error" ]; then
            "${header[@]}" --msgbox "Tools are successfully downloaded but Apkmirror API is not accessible. So, patches are not successfully synced.\nRevancify may crash.\n\nChange your network." 12 45
            return 1
        fi
        java -jar "$cliSource"-cli-*.jar options -ou -p "$storagePath/$source-options.json" "$patchesSource"-patches-*.jar &> /dev/null
    fi

    refreshJson || return 1
}

changeSource() {
    internet || return 1
    readarray -t allSources < <(jq -r --arg source "$source" 'to_entries | .[] | if .key == $source then .key,"["+.value.projectName+"]","on" else .key,"["+.value.projectName+"]","off" end' "$repoDir"/sources.json)
    selectedSource=$("${header[@]}" --begin 2 0 --title '| Source Selection Menu |' --no-cancel --ok-label "Done" --radiolist "Use arrow keys to navigate; Press Spacebar to select option" -1 -1 0 "${allSources[@]}" 2>&1 >/dev/tty)
    if [ "$source" != "$selectedSource" ]; then
        source="$selectedSource"
        source <(jq -r --arg source "$source" '.[$source].sources | to_entries[] | .key+"Source="+.value.org' "$repoDir"/sources.json)
        setEnv source "$selectedSource" update "$envFile"
        sourceName=$(jq -r --arg source "$source" '.[$source].projectName' "$repoDir"/sources.json)
        checkTools || return 1
    fi
}

selectApk() {
    [ "$1" == "storage" ] && helpTag=(--help-button --help-label "From Storage") || helpTag=()
    previousAppName="$appName"
    readarray -t availableApps < <(jq -n -r --argjson appsArray "$appsArray" '$appsArray[] | .index, .appName, .pkgName')
    appIndex=$("${header[@]}" --begin 2 0 --title '| App Selection Menu |' --item-help --default-item "$appIndex" "${helpTag[@]}" --ok-label "Select" --cancel-label "Back" --menu "Use arrow keys to navigate\nSource: $sourceName" $(($(tput lines) - 3)) -1 15 "${availableApps[@]}" 2>&1 >/dev/tty)
    appSelectResult=$?
    case $appSelectResult in
    0)
        readarray -t appSelectedResult < <(jq -n -r --arg appIndex "$appIndex" --argjson appsArray "$appsArray" '$appsArray[] | select(.index == ($appIndex | tonumber)) | .appName, .pkgName, .developerName, .apkmirrorAppName')
        appName="${appSelectedResult[0]}"
        pkgName="${appSelectedResult[1]}"
        developerName="${appSelectedResult[2]}"
        apkmirrorAppName="${appSelectedResult[3]}"
        appType=downloaded
        ;;
    1)
        return 1
        ;;
    2)
        appType=local
        unset appName appVer
        ;;
    esac
    if [ "$previousAppName" != "$appName" ]; then
        unset appVerList
    fi
}

selectPatches() {
    while true; do
        readarray -t patchesInfo < <(
            jq -n -r --arg pkgName "$pkgName" \
                --slurpfile patchesFile "$patchesSource"-patches-*.json \
                --argjson includedPatches "$includedPatches" \
                '$patchesFile[][] |
                .name as $patchName |
                .description as $desc |
                .compatiblePackages |
                if . != null then
                    if (((map(.name) | index($pkgName)) != null) or (length == 0)) then
                        (
                            if ((($includedPatches | length) != 0) and (($includedPatches[] | select(.pkgName == $pkgName).includedPatches | index($patchName)) != null)) then
                                $patchName, "on", $desc
                            else
                                $patchName, "off", $desc
                            end
                        )
                    else 
                        empty
                    end
                else
                    if ((($includedPatches | length) != 0) and (($includedPatches[] | select(.pkgName == $pkgName).includedPatches | index($patchName)) != null)) then
                        $patchName, "on", $desc
                    else
                        $patchName, "off", $desc
                    end
                end'
        )
        grep -qoP "(?<=\s)off(?=\s)" <<< "${patchesInfo[@]}" && toogleName="Include All" || toogleName="Exclude All"
        choices=$("${header[@]}" --begin 2 0 --title '| Patch Selection Menu |' --item-help --no-items --separate-output --ok-label "$1" --cancel-label "$toogleName" --help-button --help-label "Recommended" --checklist "Use arrow keys to navigate; Press Spacebar to toogle patch\nSource: $sourceName; AppName: $appName" $(($(tput lines) - 3)) -1 15 "${patchesInfo[@]}" 2>&1 >/dev/tty)
        selectPatchStatus=$?
        readarray -t choices <<< "$choices"
        patchSaver || break
    done
}

patchSaver() {
    case "$selectPatchStatus" in
    0 )
        includedPatches=$(jq -n --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" '[$includedPatches[] | select(.pkgName == $pkgName).includedPatches = $ARGS.positional]' --args "${choices[@]}")
        echo "$includedPatches" >"$storagePath/$source-patches.json" && return 1
        ;;
    1 )
        if [ "$toogleName" == "Include All" ]; then
            includedPatches=$(jq -n --arg pkgName "$pkgName" --slurpfile patchesFile "$patchesSource"-patches-*.json --argjson includedPatches "$includedPatches" '
            [
                $includedPatches[] |
                select(.pkgName == $pkgName).includedPatches = [
                    $patchesFile[][] |
                    .name as $patchName |
                    .compatiblePackages |
                    if . != null then
                        if (((map(.name) | index($pkgName)) != null) or (length == 0)) then
                            $patchName
                        else
                            empty
                        end
                    else
                        $patchName
                    end
                ]
            ]'
            )
        elif [ "$toogleName" == "Exclude All" ]; then
            includedPatches=$(jq -n --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" '[$includedPatches[] | select(.pkgName == $pkgName).includedPatches = []]')
        fi
        ;;
    2 )
        includedPatches=$(jq -n --arg pkgName "$pkgName" --slurpfile patchesFile "$patchesSource"-patches-*.json --argjson includedPatches "$includedPatches" '
        [
            $includedPatches[] |
            select(.pkgName == $pkgName).includedPatches = [
                $patchesFile[][] |
                .name as $patchName |
                .use as $use |
                .excluded as $excluded |
                .compatiblePackages |
                if . != null then
                    if ((((map(.name) | index($pkgName)) != null) or (length == 0)) and (($use == true) or ($excluded == false))) then
                        $patchName
                    else
                        empty
                    end
                else
                    $patchName
                end
            ]
        ]')
        ;;
    esac
}

editPatchOptions() {
    if [ ! -f "$storagePath/$source-options.json" ]; then
        java -jar "$cliSource"-cli-*.jar options -ou -p "$storagePath/$source-options.json" "$patchesSource"-patches-*.jar &> /dev/null
    fi
    currentPatch="none"
    optionsJson=$(jq '.' "$storagePath/$source-options.json")
    readarray -t patchNames < <(jq -n -r --argjson optionsJson "$optionsJson" '$optionsJson[].patchName')
    while true; do
        if [ "$currentPatch" == "none" ]; then
            if ! currentPatch=$("${header[@]}" --begin 2 0 --title '| Patch Options Menu |' --no-items --ok-label "Select" --cancel-label "Back" --menu "Select Patch to edit options" -1 -1 0 "${patchNames[@]}" 2>&1 >/dev/tty); then
                jq -n --argjson optionsJson "$optionsJson" '$optionsJson' > "$storagePath/$source-options.json"
                break
            fi
        else
            while true; do
                tput cnorm
                readarray -t patchOptionEntries < <(jq -n -r --arg currentPatch "$currentPatch" --argjson optionsJson "$optionsJson" '$optionsJson[] | select(.patchName == $currentPatch) | .options | to_entries[] | .key as $key | (.value | (.key | length) as $wordLength | ((($key+1) | tostring) + ". " + .key + ":"), ($key*2)+1, 0, .value, ($key*2)+1, ($wordLength + 6), 500, 500)')
                newValues=$("${header[@]}" --begin 2 0 --title '| Patch Options Form |' --ok-label "Save" --cancel-label "Back" --help-button --help-label "Info" --form "Edit patch options for \"$currentPatch\" patch\nNote: Leave the field empty to return to default value" -1 -1 0 "${patchOptionEntries[@]}" 2>&1 >/dev/tty)
                infoStatus=$?
                if [ "$infoStatus" == 0 ]; then 
                    readarray -t newValues <<< "$newValues"
                    optionsJson=$(echo "$patchesJson" | jq -r --arg currentPatch "$currentPatch" --argjson optionsJson "$optionsJson" '. as $patchesJson | $optionsJson | map((select(.patchName == $currentPatch) | .options) |= [(to_entries[] | .key as $key | .value.value = (if $ARGS.positional[$key] == "" then (first($patchesJson[] | select(.name == $currentPatch)) | .options[$key] | .default) elif $ARGS.positional[$key] == "null" then null elif $ARGS.positional[$key] == "true" then true elif $ARGS.positional[$key] == "false" then false else $ARGS.positional[$key] end)) | .value])' --args "${newValues[@]}")
                elif [ "$infoStatus" == 2 ]; then
                    tput civis
                    "${header[@]}" --begin 2 0 --title '| Patch Options Form |' --msgbox "$(jq -n -r --arg currentPatch "$currentPatch" --argjson patchesJson "$patchesJson" 'first($patchesJson[] | select(.name == $currentPatch)) | .options[] | ("Title: " + .title + "\nDescription: " + .description + "\nValues: " , (.values | to_entries[] | "\"" + .key + "\": " + .value)), "\n"')" -1 -1
                    break
                fi
                currentPatch="none"
                tput civis
                break
            done
        fi
    done
}

initInstall() {
    if [ "$root" == true ];
    then
        "${header[@]}" --infobox "Please Wait !!\nInstalling Patched $appName..." 12 45
        if ! su -mm -c "/system/bin/sh $repoDir/root_util.sh mount $pkgName $appName $appVer $sourceName" > /dev/null 2>&1; then
            "${header[@]}" --msgbox "Installation Failed !!\nLogs saved to \"Internal-Storage/Revancify/install_log.txt\". Share the Install logs to developer." 12 45
            return 1
        else
            "${header[@]}" --msgbox "$appName installed Successfully !!" 12 45
        fi
        if [ "$LaunchAppAfterMount" == true ]; then
            su -c "settings list secure | sed -n -e 's/\/.*//' -e 's/default_input_method=//p' | xargs pidof | xargs kill -9 && pm resolve-activity --brief $pkgName | tail -n 1 | xargs am start -n && pidof com.termux | xargs kill -9" &> /dev/null
        fi
    else
        "${header[@]}" --infobox "Copying $appName $sourceName $selectedVer to Internal Storage..." 12 45
        canonicalAppVer=${appVer//:/}
        cp "apps/$appName-$appVer-$sourceName.apk" apps/temp.apk &> /dev/null
        mv "apps/temp.apk" "$storagePath/$appName-$canonicalAppVer-$sourceName.apk" &> /dev/null
        termux-open "$storagePath/$appName-$canonicalAppVer-$sourceName.apk"
        return 1
    fi
}

rootUninstall() {
    selectApk normal || return 1
    su -mm -c "/system/bin/sh $repoDir/root_util.sh unmount $pkgName" &> /dev/null
    unmountStatus=$?
    if [ "$unmountStatus" -eq "2" ]; then
        "${header[@]}" --msgbox "Patched $appName is not installed(mounted) in your device." 12 45
        return 1
    else
        "${header[@]}" --infobox "Uninstalling Patched $appName by Unmounting..." 12 45
        sleep 2
        [ "$unmountStatus" -ne "0" ] && "${header[@]}" --msgbox "Unmount failed !! Something went wrong." 12 45 && sleep 1 && return 1
    fi
    "${header[@]}" --msgbox "Unmount Successful !!" 12 45
    sleep 1
}

refreshJson() {
    if ! ls "$patchesSource"-patches-*.json &> /dev/null; then
        getTools || return 1
        return 0
    fi
    if [ ! -f "$storagePath/$source-patches.json" ]; then
        internet || return 1
        "${header[@]}" --infobox "Please Wait !!" 12 45
        if [ "$(bash "$repoDir/fetch_patches.sh" "$patchesSource" online "$storagePath")" == "error" ]; then
            "${header[@]}" --msgbox "Oops !! Apkmirror API is not accessible. Patches are not successfully synced.\nRevancify may crash.\n\nChange your network." 12 45
            return 1
        fi
    fi
    includedPatches=$(jq '.' "$storagePath/$source-patches.json" 2>/dev/null || jq -n '[]')
    patchesJson=$(jq '.' "$patchesSource"-patches-*.json)
    appsArray=$(jq -n --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '$includedPatches | map(select(.appName != null)) | to_entries | map({"index": (.key + 1), "appName": (.value.appName), "pkgName" :(.value.pkgName), "developerName" :(.value.developerName), "apkmirrorAppName" :(.value.apkmirrorAppName)})')
}

checkTools() {
    if [ -e ".${source}-data" ]; then
        source ./".${source}-data"
    else
        getTools || return 1
    fi
    if [ "$cliSize" == "$(ls "$cliSource"-cli-*.jar &> /dev/null && du -b "$cliSource"-cli-*.jar | cut -d $'\t' -f 1 || echo 0)" ] && [ "$patchesSize" == "$(ls "$patchesSource"-patches-*.jar &> /dev/null && du -b "$patchesSource"-patches-*.jar | cut -d $'\t' -f 1 || echo 0)" ] && [ "$integrationsSize" == "$(ls "$integrationsSource"-integrations-*.apk &> /dev/null && du -b "$integrationsSource"-integrations-*.apk | cut -d $'\t' -f 1 || echo 0)" ] && ls "$storagePath/$source-patches.json" &> /dev/null; then
        refreshJson || return 1
    else
        getTools || return 1
    fi
}

getAppVer() {
    if [ "$root" == true ] && su -c "pm list packages | grep -q $pkgName" && [ "$AllowVersionDowngrade" == false ]; then
        selectedVer=$(su -c dumpsys package "$pkgName" | sed -n '/versionName/s/.*=//p' | sed -n '1p')
        appVer="${selectedVer// /-}"
    fi
    if [ "${#appVerList[@]}" -lt 2 ]; then
        internet || return 1
        "${header[@]}" --infobox "Please Wait !!\nScraping versions list for $appName from apkmirror.com..." 12 45
        readarray -t appVerList < <(bash "$repoDir/fetch_versions.sh" "$appName" "$apkmirrorAppName" "$patchesSource" "$selectedVer" "$storagePath")
    fi
    versionSelector || return 1
}

versionSelector() {
    if [ "${appVerList[0]}" == "error" ]; then
        "${header[@]}" --msgbox "Unable to fetch link !!\nThere is some problem with your internet connection. Disable VPN or Change your network." 12 45
        return 1
    fi
    selectedVer=$("${header[@]}" --begin 2 0 --title '| Version Selection Menu |' --default-item "$selectedVer" --ok-label "Select" --cancel-label "Back" --menu "Use arrow keys to navigate\nSource: $sourceName; AppName: $appName" -1 -1 0 "${appVerList[@]}" 2>&1 >/dev/tty) || return 1
    if [ "$selectedVer" == "Auto Select" ]; then
        selectedVer=$(jq -n -r --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '$includedPatches[] | select(.pkgName == $pkgName) | .versions[-1]')
    fi
    appVer="${selectedVer// /-}"
}

checkPatched() {
    if [ -e "apps/$appName-$appVer-$sourceName.apk" ]; then
        "${header[@]}" --begin 2 0 --title '| Patched apk found |' --no-items --defaultno --yes-label 'Patch' --no-label 'Install' --help-button --help-label 'Back' --yesno "Current directory already contains Patched $appName version $selectedVer.\n\n\nDo you want to patch $appName again?" -1 -1
        apkFoundPrompt=$?
        case "$apkFoundPrompt" in
        0 )
            rm "apps/$appName-$appVer-$sourceName.apk"
            ;;
        1 )
            initInstall
            return 1
            ;;
        2 )
            return 1
            ;;
        esac
    else
        rm "apps/$appName-$appVer-$sourceName.apk" &> /dev/null
        return 0
    fi
}

selectFile() {
    newPath=""
    while [ ! -f "$newPath" ]; do
        currentPath=${currentPath:-$internalStorage}
        dirList=()
        files=()
        if [ "$currentPath" != "$internalStorage" ]; then
            dirUp=(1 ".." "GO BACK TO PREVIOUS DIRECTORY")
            num=1
        else
            unset dirUp
            num=0
        fi
        while read -r itemName; do
            if [ -d "$currentPath/$itemName" ]; then
                files+=("$itemName")
                [ "${#itemName}" -gt $(("$(tput cols)" - 24)) ] && itemNameDisplay=${itemName:0:$(("$(tput cols)" - 34))}...${itemName: -10} || itemNameDisplay="$itemName"
                dirList+=("$((++num))" "$itemNameDisplay/" "DIR: $itemName/")
            elif [ "${itemName##*.}" == "apk" ]; then
                files+=("$itemName")
                [ "${#itemName}" -gt $(("$(tput cols)" - 24)) ] && itemNameDisplay=${itemName:0:$(("$(tput cols)" - 34))}...${itemName: -10} || itemNameDisplay=$itemName
                dirList+=("$((++num))" "$itemNameDisplay" "APK: $itemName")
            fi
        done < <(ls -1 --group-directories-first "$currentPath")
        pathIndex=$("${header[@]}" --begin 2 0 --title '| Apk File Selection Menu |' --item-help --ok-label "Select" --menu "Use arrow keys to navigate\nCurrent Path: $currentPath/" $(($(tput lines) - 3)) -1 15 "${dirUp[@]}" "${dirList[@]}" 2>&1 >/dev/tty)
        exitstatus=$?
        [ "$exitstatus" -eq 1 ] && break
        if [ "$currentPath" != "$internalStorage" ] && [ "$pathIndex" -eq 1 ]; then
            newPath=".."
        elif [ "$currentPath" != "$internalStorage" ] && [ "$pathIndex" -ne 1 ]; then
            newPath=${files[$pathIndex - 2]}
        else
            newPath=${files[$pathIndex - 1]}
        fi
        if [ "$newPath" == ".." ]; then
            newPath=${currentPath%/*}
        else
            newPath=$currentPath/$newPath
        fi
        if [ -d "$newPath" ]; then
            currentPath=$newPath
        fi
    done
    [ "$exitstatus" -eq 1 ] && return 1
    return 0
}

fetchCustomApk() {
    selectedVer="" installedVer=""
    selectFile || return 1
    "${header[@]}" --infobox "Please Wait !!\nExtracting data from \"$(basename "$newPath")\"" 12 45
    if ! aaptData=$(./aapt2 dump badging "$newPath"); then
        "${header[@]}" --msgbox "The apkfile you selected is not an valid app. Download the apk again and retry." 12 45
        return 1
    fi
    pkgName=$(grep "package:" <<<"$aaptData" | sed -e 's/package: name='\''//' -e 's/'\'' versionCode.*//')
    if [ "$(jq -n --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" '$includedPatches[] | select(.pkgName == $pkgName) | .patches')" == "" ]; then
        "${header[@]}" --msgbox "The app you selected is not supported for patching by $sourceName patches !!" 12 45
        return 1
    fi
    fileAppName=$(grep "application-label:" <<<"$aaptData" | sed -e 's/application-label://' -e 's/'\''//g')
    appName="$(sed 's/\./-/g;s/ /-/g' <<<"$fileAppName")"
    selectedVer=$(grep "package:" <<<"$aaptData" | sed -e 's/.*versionName='\''//' -e 's/'\'' platformBuildVersionName.*//')
    appVer="${selectedVer// /-}"
    if [ "$root" == true ] && su -c "pm list packages | grep -q $pkgName" && [ "$AllowVersionDowngrade" == false ]; then
        installedVer=$(su -c dumpsys package "$pkgName" | sed -n '/versionName/s/.*=//p' | sed -n '1p')
        if [ "$installedVer" != "$selectedVer" ]; then
            sorted=$(jq -nr --arg installedVer "$installedVer" --arg selectedVer "$selectedVer" '[$installedVer, $selectedVer] | sort | .[0]')
            if [ "${sorted[0]}" != "$installedVer" ];then
                "${header[@]}" --msgbox "The selected version $selectedVer is lower then version $installedVer installed on your device.\nPlease Select a higher version !!" 12 45
                return 1
            fi
        fi
    fi
    cp "$newPath" "apps/$appName-$appVer.apk"
    if [ "$(jq -n -r --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '$includedPatches[] | select(.pkgName == $pkgName) | .versions | length')" -eq 0 ]; then
        if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --yesno "The following data is extracted from the apk file you provided.\nApp Name    : $fileAppName\nPackage Name: $pkgName\nVersion     : $selectedVer\nDo you want to proceed with this app?" -1 -1; then
            return 1
        fi
    else
        if [ "$(jq -n -r --arg selectedVer "$selectedVer" --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" '$includedPatches[] | select(.pkgName == $pkgName) | .versions | index($selectedVer)')" != "null" ]; then
            if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --yesno "The following data is extracted from the apk file you provided.\nApp Name    : $fileAppName\nPackage Name: $pkgName\nVersion     : $selectedVer\nDo you want to proceed with this app?" -1 -1; then
                return 1
            fi
        else
            if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --yesno "The following data is extracted from the apk file you provided.\nApp Name    : $fileAppName\nPackage Name: $pkgName\nVersion     : $selectedVer\n\nThe version $selectedVer is not supported. Supported versions are: \n$(jq -n -r --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" '$includedPatches[] | select(.pkgName == $pkgName).versions | length as $array_length | to_entries[] | if .key != ($array_length - 1) then .value + "," else .value end')\n\nDo you still want to proceed with version $selectedVer for $appName?" -1 -1; then
                return 1
            fi
        fi
    fi
    checkPatched || return 1
}

fetchApk() {
    selectedVer="" appVer=""
    getAppVer || return 1
    if [ "$(jq -n -r --argjson includedPatches "$includedPatches" --arg selectedVer "$selectedVer" --arg pkgName "$pkgName" '$includedPatches[] | select(.pkgName == $pkgName) | .versions | if ((. | length) == 0) then 0 elif ((. | index($selectedVer)) != null) then 0 else 1 end')" -eq 0 ]; then
        if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --yesno "Do you want to proceed with version $selectedVer for $appName?" -1 -1; then
            return 1
        fi
    else
        if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --yesno "The version $selectedVer is not supported. Supported versions are: \n$(jq -n -r --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" '$includedPatches[] | select(.pkgName == $pkgName).versions | length as $array_length | to_entries[] | if .key != ($array_length - 1) then .value + "," else .value end')\n\nDo you still want to proceed with version $selectedVer for $appName?" -1 -1; then
            return 1
        fi
    fi
    checkPatched || return 1
    if [ -e "apps/$appName-$appVer.apk" ]; then
        if [ "$(source "apps/.appSize"; eval echo \$"${appName//-/_}"Size)" == "$(du -b "apps/$appName-$appVer.apk" | cut -d $'\t' -f 1 || echo 0)" ]; then
            return 0
        fi
    else
        rm -rf "apps/$appName"* &> /dev/null
    fi
    downloadApk || return 1
}

downloadApk() {
    internet || return 1
    readarray -t urlResult < <( (bash "$repoDir/fetch_link.sh" "$developerName" "$apkmirrorAppName" "$appVer" "$PreferSplitApk" 2>&3 | "${header[@]}" --begin 2 0 --gauge "App    : $appName\nVersion: $selectedVer\n\nScraping Download Link..." -1 -1 0 >&2) 3>&1)
    tput civis
    case "${urlResult[0]}" in
    "error" )
        "${header[@]}" --msgbox "Unable to fetch link !!\nThere is some problem with your internet connection. Disable VPN or Change your network." 12 45
        return 1
        ;;
    "noapk" )
        if [ "$root" == false ]; then
            "${header[@]}" --msgbox "No apk found on apkmirror.com for version $selectedVer !!\nTry selecting other version." 12 45
            return 1
        else
            "${header[@]}" --msgbox "No apk found on apkmirror.com for version $selectedVer !!\nPlease upgrade or degrade the version to patch it.\n\nSuggestion: Download apk manually and use that file to patch." 12 45
            return 1
        fi
        ;;
    "noversion" )
        "${header[@]}" --msgbox "This version is not uploaded on apkmirror.com!!\nPlease upgrade or degrade the version to patch it.\n\nSuggestion: Download apk manually and use that file to patch." 12 45
        return 1
        ;;
    esac
    appUrl=${urlResult[0]}
    appSize=${urlResult[1]}
    appType=${urlResult[2]}
    [ "$appType" == "apk" ] && appExt=apk || appExt=apkm
    setEnv "${appName//-/_}Size" "$appSize" update "apps/.appSize"
    wget -q -c "$appUrl" -O "apps/$appName-$appVer.$appExt" --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "App    : $appName\nVersion: $selectedVer\nSize   : $(numfmt --to=iec --format="%0.1f" "$appSize")\nAppType: $appExt\n\nDownloading..." -1 -1 "$(($(( "$([ -e "apps/$appName-$appVer.$appExt" ] && du -b "apps/$appName-$appVer.$appExt" | cut -d $'\t' -f 1 || echo 0)" * 100)) / appSize))"
    tput civis
    sleep 0.5s
    if [ "$appSize" != "$(du -b "apps/$appName-$appVer.$appExt" | cut -d $'\t' -f 1)" ]; then
        "${header[@]}" --msgbox "Oh No !!\nUnable to complete download. Please Check your internet connection and Retry." 12 45
        return 1
    fi
    [ "$appType" == "bundle" ] && antiSplitApkm
    return 0
}

downloadMicrog() {
    microgName=GmsCore microgRepo=revanced
    if "${header[@]}" --begin 2 0 --title '| MicroG Prompt |' --no-items --defaultno --yesno "$microgName is used to run MicroG services without root.\nYouTube and YouTube Music won't work without it.\nIf you already have $microgName, You don't need to download it.\n\n\n\n\n\nDo you want to download $microgName app?" -1 -1; then
        internet || return 1
        readarray -t microgheaders < <(curl -s "https://api.github.com/repos/$microgRepo/$microgName/releases/latest" | jq -r '(.assets[0] | .browser_download_url, .size), .tag_name')
        wget -q -c "${microgheaders[0]}" -O "$microgName-${microgheaders[2]}.apk" --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "App     : $microgName \nVersion : ${microgheaders[2]}\nSize    : $(numfmt --to=iec --format="%0.1f" "${microgheaders[1]}")\n\nDownloading..." -1 -1 && tput civis
        ls $microgName* &> /dev/null && mv $microgName* "$storagePath/" && termux-open "$storagePath/$microgName-${microgheaders[2]}.apk"
    fi
}

antiSplitApkm() {
    "${header[@]}" --infobox "Please Wait !!\nReducing app size..." 12 45
    splits="apps/splits"
    mkdir "$splits"
    unzip -qqo "apps/$appName-$appVer.apkm" -d "$splits"
    rm "apps/$appName-$appVer.apkm"
    appDir="apps/$appName-$appVer"
    mkdir "$appDir"
    cp "$splits/base.apk" "$appDir"
    cp "$splits/split_config.${arch//-/_}.apk" "$appDir" &> /dev/null
    locale=$(getprop persist.sys.locale | sed 's/-.*//g')
    if [ ! -e "$splits/split_config.${locale}.apk" ]; then
        locale=$(getprop ro.product.locale | sed 's/-.*//g')
    fi
    cp "$splits/split_config.${locale}.apk" "$appDir" &> /dev/null
    cp "$splits"/split_config.*dpi.apk "$appDir" &> /dev/null
    rm -rf "$splits"
    java -jar ApkEditor.jar m -i "$appDir" -o "apps/$appName-$appVer.apk" &> /dev/null
    setEnv "${appName//-/_}Size" "$(du -b "apps/$appName-$appVer.apk" | cut -d $'\t' -f 1)" update "apps/.appSize"
}

patchApk() {
    if [ "$cliSource" == "inotia00" ] && [ "$Riplibs" == true ]; then
        riplibArgs=(--rip-lib=x86_64 --rip-lib=x86 --rip-lib=armeabi-v7a --rip-lib=arm64-v8a)
        read -ra riplibArgs < <(echo -n -e "${riplibArgs[*]/"--rip-lib=$arch"/}")
    else
        riplibArgs=()
    fi
    includedPatches=$(jq '.' "$storagePath/$source-patches.json" 2>/dev/null || jq -n '[]')
    readarray -t patchesArg < <(jq -n -r --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '$includedPatches[] | select(.pkgName == $pkgName).includedPatches | if ((. | length) != 0) then (.[] | "-i", .) else empty end')
    java -jar "$cliSource"-cli-*.jar patch -fpw -b "$patchesSource"-patches-*.jar -m "$integrationsSource"-integrations-*.apk -o "apps/$appName-$appVer-$sourceName.apk" "${riplibArgs[@]}" "${patchesArg[@]}" --keystore "$repoDir"/revancify.keystore --keystore-entry-alias "decipher" --signer "decipher" --keystore-entry-password "revancify" --keystore-password "revancify" --custom-aapt2-binary ./aapt2 --options "$storagePath/$source-options.json" --exclusive "apps/$appName-$appVer.apk" 2>&1 | tee "$storagePath/patch_log.txt" | "${header[@]}" --begin 2 0 --ok-label "Continue" --cursor-off-label --programbox "Patching $appName $selectedVer.apk" -1 -1
    echo -e "\n\n\nRooted: $root\nArch: $arch\nApp: $appName v$appVer\nCLI: $(ls "$cliSource"-cli-*.jar)\nPatches: $(ls "$patchesSource"-patches-*.jar)\nIntegrations: $(ls "$integrationsSource"-integrations-*.apk)\nPatches argument: ${patchesArg[*]}" >>"$storagePath/patch_log.txt"
    tput civis
    sleep 1
    if [ ! -f "apps/$appName-$appVer-$sourceName.apk" ]; then
        "${header[@]}" --msgbox "Oops, Patching failed !!\nLogs saved to \"Internal Storage/Revancify/patch_log.txt\". Share the Patchlog to developer." 12 45
        return 1
    fi
}

deleteComponents() {
    while true; do
        delComponentPrompt=$("${header[@]}" --begin 2 0 --title '| Delete Components Menu |' --ok-label "Select" --cancel-label "Back" --menu "Use arrow keys to navigate\nSource: $sourceName" -1 -1 0 1 "Tools" 2 "Apps" 3 "Patch Options" 2>&1 >/dev/tty) || break
        case "$delComponentPrompt" in
        1 )
            if "${header[@]}" --begin 2 0 --title '| Delete Tools |' --no-items --defaultno --yesno "Please confirm to delete the tools.\nIt will delete the $sourceName CLI, patches and integrations." -1 -1; then
                rm "$cliSource"-cli-*.jar &> /dev/null
                rm "$patchesSource"-patches-*.jar &> /dev/null
                rm "$patchesSource"-patches-*.json &> /dev/null
                rm "$integrationsSource"-integrations-*.apk &> /dev/null
                "${header[@]}" --msgbox "All $sourceName Tools successfully deleted !!" 12 45
            fi
            ;;
        2 )
            if "${header[@]}" --begin 2 0 --title '| Delete Apps |' --no-items --defaultno --yesno "Please confirm to delete all the downloaded and patched apps." -1 -1; then
                rm -rf "apps"/*
                "${header[@]}" --msgbox "All Apps are successfully deleted !!" 12 45
            fi
            ;;
        3 )
            if "${header[@]}" --begin 2 0 --title '| Delete Patch Options |' --no-items --defaultno --yesno "Please confirm to delete the patch options file for $sourceName patches." -1 -1; then
                rm "$storagePath/$source-options.json" &> /dev/null
                "${header[@]}" --msgbox "Options file successfully deleted for current source !!" 12 45
            fi
            ;;
        esac
    done
}

preferences() {
    [ "$cliSource" == "inotia00" ] && RiplibsPref=("Riplibs" "$Riplibs" "Removes extra libs from app") || RiplibsPref=()
    prefsArray=("LightTheme" "$LightTheme" "Use Light theme for Revancify" "${RiplibsPref[@]}" "PreferSplitApk" "$PreferSplitApk" "Reduces App Size using splits" "AutocheckToolsUpdate" "$AutocheckToolsUpdate" "Check for tools update at startup" "ShowConfirmPatchesMenu" "$ShowConfirmPatchesMenu" "Shows Patches Menu before Patching starts" "LaunchAppAfterMount" "$LaunchAppAfterMount" "[Root] Launches app automatically after mount" AllowVersionDowngrade "$AllowVersionDowngrade" "[Root] Allows downgrading version if any such module is present" "FetchPreReleasedTools" "$FetchPreReleasedTools" "Fetches the pre-release version of tools")
    readarray -t prefsArray < <(for pref in "${prefsArray[@]}"; do sed 's/false/off/;s/true/on/' <<< "$pref"; done)
    read -ra newPrefs < <("${header[@]}" --begin 2 0 --title '| Preferences Menu |' --item-help --no-items --no-cancel --ok-label "Save" --checklist "Use arrow keys to navigate; Press Spacebar to toogle patch" $(($(tput lines) - 3)) -1 15 "${prefsArray[@]}" 2>&1 >/dev/tty)
    sed -i 's/true/false/' "$envFile"
    for newPref in "${newPrefs[@]}"; do
        setEnv "$newPref" true update "$envFile"
    done
    source "$envFile"
    [ "$LightTheme" == true ] && theme=Light || theme=Dark
    export DIALOGRC="$repoDir/configs/.dialogrc$theme"
}

buildApk() {
    if [ "$appType" == "downloaded" ]; then
        fetchApk || return 1
    else
        fetchCustomApk || return 1
        selectPatches Proceed
    fi
    if [ "$appType" == "downloaded" ] && [ "$ShowConfirmPatchesMenu" == true ]; then
        selectPatches Proceed
    fi
    patchApk || return 1
    initInstall
}

mainMenu() {
    mainMenu=$("${header[@]}" --begin 2 0 --title '| Main Menu |' --default-item "$mainMenu" --ok-label "Select" --cancel-label "Exit" --menu "Use arrow keys to navigate\nSource: $sourceName" -1 -1 0 1 "Patch App" 2 "Select Patches" 3 "Change Source" 4 "Fetch Tools" 5 "Edit Patch Options" 6 "$menuEntry" 7 "Delete Components" 8 "Preferences" 2>&1 >/dev/tty) || terminate 0
    case "$mainMenu" in
    1 )
        while true; do
            selectApk storage || break
            buildApk
        done
        ;;
    2 )
        while true; do
            selectApk normal || break
            selectPatches Save || break
        done
        ;;
    3 )
        changeSource
        ;;
    4 )
        getTools
        ;;
    5 )
        editPatchOptions
        ;;
    6 )
        if [ "$root" == true ]; then
            rootUninstall
        else
            downloadMicrog
        fi
        ;;
    7 )
        deleteComponents
        ;;
    8 )
        preferences
        ;;
    esac
}

if su -c exit &> /dev/null; then
    [ "$1" == false ] && root=false || root=true
else
    root=false
fi

online="$2"

initialize

while true; do
    unset appVerList appVer appName pkgName
    mainMenu
done
