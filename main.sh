#!/usr/bin/bash

terminate() {
    killall -9 java >/dev/null 2>&1
    killall -9 dialog >/dev/null 2>&1
    killall -9 wget >/dev/null 2>&1
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
    repoDir=$(find "$HOME" -type d -name "Revancify")
    header=(dialog --backtitle "Revancify | [Arch: $arch, SU: $rootStatus]" --no-shadow)
    envFile=config.cfg
    [ ! -f "apps/.appSize" ] && : > "apps/.appSize"

    forceUpdateCheckStatus="" riplibsRVX="" lightTheme="" patchMenuBeforePatching="" launchAppAfterMount="" allowVersionDowngrade=""
    setEnv forceUpdateCheckStatus false init "$envFile"
    setEnv riplibsRVX true init "$envFile"
    setEnv lightTheme false init "$envFile"
    setEnv patchMenuBeforePatching false init "$envFile"
    setEnv launchAppAfterMount true init "$envFile"
    setEnv allowVersionDowngrade false init "$envFile"
    # shellcheck source=/dev/null
    source "$envFile"
    if [ -z "$source" ]; then
        readarray -t allSources < <(jq -r --arg source "$source" 'to_entries | .[] | .key,"["+.value.projectName+"]","on"' "$repoDir"/sources.json)
        source=$("${header[@]}" --begin 2 0 --title '| Source Selection Menu |' --no-cancel --ok-label "Done" --radiolist "Use arrow keys to navigate; Press Spacebar to select option" -1 -1 15 "${allSources[@]}" 2>&1 >/dev/tty)
        setEnv source "$source" update "$envFile"
    fi
    [ "$rootStatus" = "root" ] && menuEntry="Uninstall Patched app" || menuEntry="Download Microg"

    [ "$lightTheme" == "true" ] && theme=light || theme=Dark
    export DIALOGRC="$repoDir/configs/.dialogrc$theme"


    cliSource="" patchesSource="" integrationsSource="" patchesLatest="" cliLatest="" integrationsLatest="" patchesSize="" cliSize="" integrationsSize="" patchesUrl="" jsonUrl="" cliUrl="" integrationsUrl=""

    # shellcheck source=/dev/null
    source <(jq -r --arg source "$source" '.[$source].sources | to_entries[] | .key+"Source="+.value.org' "$repoDir"/sources.json)
    sourceName=$(jq -r --arg source "$source" '.[$source].projectName' "$repoDir"/sources.json)
    [ -d "$cliSource" ] && mkdir -p "$cliSource"
    [ -d "$patchesSource" ] && mkdir -p "$patchesSource"
    [ -d "$integrationsSource" ] && mkdir -p "$integrationsSource"

    checkResources || terminate 1
    checkJson

    if [ -f "$storagePath/$source-patches.json" ]; then
        bash "$repoDir/fetch_patches.sh" "$source" offline "$storagePath" >/dev/null 2>&1
        patchesJson=$(jq '.' "$patchesSource"-patches-*.json)
        includedPatches=$(jq '.' "$storagePath/$source-patches.json" 2>/dev/null || jq -n '[]')
        appsArray=$(jq -n --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '$includedPatches | to_entries | map(select(.value.appName != null)) | to_entries | map({"index": (.key + 1), "appName": (.value.value.appName), "pkgName" :(.value.value.pkgName), "developerName" :(.value.value.developerName), "apkmirrorAppName" :(.value.value.apkmirrorAppName)})')
    fi
}

internet() {
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        "${header[@]}" --msgbox "Oops! No Internet Connection available.\n\nConnect to Internet and try again later." 12 45
        return 1
    fi
}

resourcesVars() {
    internet || return 1

    "${header[@]}" --infobox "Please Wait !!\nFetching resources data from github API..." 12 45
    readarray -t resources < <(jq -r --arg source "$source" '.[$source].sources | keys_unsorted[]' "$repoDir"/sources.json)
    readarray -t links < <(jq -r --arg source "$source" '.[$source].sources[] | .org+"/"+.repo' "$repoDir"/sources.json)
    : >".${source}-data"
    i=0 && for resource in "${resources[@]}"; do
        curl -s --fail-early --connect-timeout 2 --max-time 5 "https://api.github.com/repos/${links[$i]}/releases/latest" | jq -r --arg resource "$resource" '$resource+"Latest="+.tag_name, (.assets[] | if .content_type == "application/json" then "jsonUrl="+.browser_download_url, "jsonSize="+(.size|tostring) else $resource+"Url="+.browser_download_url, $resource+"Size="+(.size|tostring) end)' >>".${source}-data"
        i=$(("$i" + 1))
    done

    if [ "$(wc -l <".${source}-data")" -lt "11" ]; then
        "${header[@]}" --msgbox "Oops! Unable to connect to Github.\n\nRetry or change your Network." 12 45
        return 1
    fi
    # shellcheck source=/dev/null
    source ./".${source}-data"

    ls "$cliSource"-cli-*.jar >/dev/null 2>&1 && cliAvailable=$(basename "$cliSource"-cli-*.jar .jar | cut -d '-' -f 3) || cliAvailable="Not found"
    ls "$patchesSource"-patches-*.jar >/dev/null 2>&1 && patchesAvailable=$(basename "$patchesSource"-patches-*.jar .jar | cut -d '-' -f 3) || patchesAvailable="Not found"
    ls "$patchesSource"-patches-*.json >/dev/null 2>&1 && jsonAvailable=$(basename "$patchesSource"-patches-*.json .json | cut -d '-' -f 3) || jsonAvailable="Not found"
    ls "$integrationsSource"-integrations-*.apk >/dev/null 2>&1 && integrationsAvailable=$(basename "$integrationsSource"-integrations-*.apk .apk | cut -d '-' -f 3) || integrationsAvailable="Not found"

    cliAvailableSize=$(ls "$cliSource"-cli-*.jar >/dev/null 2>&1 && du -b "$cliSource"-cli-*.jar | cut -d $'\t' -f 1 || echo 0)
    patchesAvailableSize=$(ls "$patchesSource"-patches-*.jar >/dev/null 2>&1 && du -b "$patchesSource"-patches-*.jar | cut -d $'\t' -f 1 || echo 0)
    integrationsAvailableSize=$(ls "$integrationsSource"-integrations-*.apk >/dev/null 2>&1 && du -b "$integrationsSource"-integrations-*.apk | cut -d $'\t' -f 1 || echo 0)
}

getResources() {
    resourcesVars || return 1
    if [ "$patchesLatest" = "$patchesAvailable" ] && [ "$patchesLatest" = "$jsonAvailable" ] && [ "$cliLatest" = "$cliAvailable" ] && [ "$integrationsLatest" = "$integrationsAvailable" ] && [ "$cliSize" = "$cliAvailableSize" ] && [ "$patchesSize" = "$patchesAvailableSize" ] && [ "$integrationsSize" = "$integrationsAvailableSize" ]; then
        if [ "$(bash "$repoDir/fetch_patches.sh" "$source" online "$storagePath")" == "error" ]; then
            "${header[@]}" --msgbox "Resources are successfully downloaded but Apkmirror API is not accessible. So, patches are not successfully synced.\nRevancify may crash.\n\nChange your network." 12 45
            return 1
        fi
        "${header[@]}" --msgbox "Resources are already downloaded !!\n\nPatches are successfully synced." 12 45
        return 1
    fi
    [ "$patchesLatest" != "$patchesAvailable" ] && rm "$patchesSource"-patches-*.jar >/dev/null 2>&1 && rm "$patchesSource"-patches-*.json >/dev/null 2>&1 && patchesAvailableSize=0
    [ "$cliLatest" != "$cliAvailable" ] && rm "$cliSource"-cli-*.jar >/dev/null 2>&1 && cliAvailableSize=0
    [ "$integrationsLatest" != "$integrationsAvailable" ] && rm "$integrationsSource"-integrations-*.apk >/dev/null 2>&1 && integrationsAvailableSize=0
    [ "$cliSize" != "$cliAvailableSize" ] &&
        wget -q -c "$cliUrl" -O "$cliSource"-cli-"$cliLatest".jar --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "Source  : $sourceName\nResource: CLI\nVersion : $cliLatest\nSize    : $(numfmt --to=iec --format="%0.1f" "$cliSize")\n\nDownloading..." -1 -1 $(($(("$cliAvailableSize" * 100)) / "$cliSize")) && tput civis

    [ "$cliSize" != "$(ls "$cliSource"-cli-*.jar >/dev/null 2>&1 && du -b "$cliSource"-cli-*.jar | cut -d $'\t' -f 1 || echo 0)" ] && "${header[@]}" --msgbox "Oops! Unable to download completely.\n\nRetry or change your Network." 12 45 && return 1

    [ "$patchesSize" != "$patchesAvailableSize" ] &&
        wget -q -c "$patchesUrl" -O "$patchesSource"-patches-"$patchesLatest".jar --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "Source  : $sourceName\nResource: Patches\nVersion : $patchesLatest\nSize    : $(numfmt --to=iec --format="%0.1f" "$patchesSize")\n\nDownloading..." -1 -1 $(($(("$patchesAvailableSize" * 100 / "$patchesSize")))) && tput civis && patchesUpdated=true

    wget -q -c "$jsonUrl" -O "$patchesSource"-patches-"$patchesLatest".json --user-agent="$userAgent"

    [ "$patchesSize" != "$(ls "$patchesSource"-patches-*.jar >/dev/null 2>&1 && du -b "$patchesSource"-patches-*.jar | cut -d $'\t' -f 1 || echo 0)" ] && "${header[@]}" --msgbox "Oops! Unable to download completely.\n\nRetry or change your Network." 12 45 && return 1

    [ "$integrationsSize" != "$integrationsAvailableSize" ] &&
        wget -q -c "$integrationsUrl" -O "$integrationsSource"-integrations-"$integrationsLatest".apk --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "Source  : $sourceName\nResource: Integrations\nVersion : $integrationsLatest\nSize    : $(numfmt --to=iec --format="%0.1f" "$integrationsSize")\n\nDownloading..." -1 -1 $(($(("$integrationsAvailableSize" * 100 / "$integrationsSize")))) && tput civis

    [ "$integrationsSize" != "$(ls "$integrationsSource"-integrations-*.apk >/dev/null 2>&1 && du -b "$integrationsSource"-integrations-*.apk | cut -d $'\t' -f 1 || echo 0)" ] && "${header[@]}" --msgbox "Oops! File not downloaded.\n\nRetry or change your Network." 12 45 && return 1

    if [ "$patchesUpdated" == "true" ]; then
        "${header[@]}" --infobox "Updating patches and options file..." 12 45
        java -jar "$cliSource"-cli-*.jar -b "$patchesSource"-patches-*.jar -m "$integrationsSource"-integrations-*.apk -c -a noinput.apk -o nooutput.apk --options "$storagePath/$source-options.json" >/dev/null 2>&1
    fi

    if [ "$(bash "$repoDir/fetch_patches.sh" "$source" online "$storagePath")" == "error" ]; then
        "${header[@]}" --msgbox "Resources are successfully downloaded but Apkmirror API is not accessible. So, patches are not successfully synced.\nRevancify may crash.\n\nChange your network." 12 45
        return 1
    fi

    patchesJson=$(jq '.' "$patchesSource"-patches-*.json)
    includedPatches=$(jq '.' "$storagePath/$source-patches.json" 2>/dev/null || jq -n '[]')
    appsArray=$(jq -n --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '$includedPatches | to_entries | map(select(.value.appName != null)) | to_entries | map({"index": (.key + 1), "appName": (.value.value.appName), "pkgName" :(.value.value.pkgName), "developerName" :(.value.value.developerName), "apkmirrorAppName" :(.value.value.apkmirrorAppName)})')
}

changeSource() {
    internet || return 1
    readarray -t allSources < <(jq -r --arg source "$source" 'to_entries | .[] | if .key == $source then .key,"["+.value.projectName+"]","on" else .key,"["+.value.projectName+"]","off" end' "$repoDir"/sources.json)
    selectedSource=$("${header[@]}" --begin 2 0 --title '| Source Selection Menu |' --no-cancel --ok-label "Done" --radiolist "Use arrow keys to navigate; Press Spacebar to select option" -1 -1 15 "${allSources[@]}" 2>&1 >/dev/tty)
    if [ "$source" != "$selectedSource" ]; then
        source="$selectedSource"
        # shellcheck source=/dev/null
        source <(jq -r --arg source "$source" '.[$source].sources | to_entries[] | .key+"Source="+.value.org' "$repoDir"/sources.json)
        sourceName=$(jq -r --arg source "$source" '.[$source].projectName' "$repoDir"/sources.json)
        patchesJson=$(jq '.' "$patchesSource"-patches-*.json)
        includedPatches=$(jq '.' "$storagePath/$source-patches.json" 2>/dev/null || jq -n '[]')
        appsArray=$(jq -n --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '$includedPatches | to_entries | map(select(.value.appName != null)) | to_entries | map({"index": (.key + 1), "appName": (.value.value.appName), "pkgName" :(.value.value.pkgName), "developerName" :(.value.value.developerName), "apkmirrorAppName" :(.value.value.apkmirrorAppName)})')
        setEnv source "$selectedSource" update "$envFile"
        checkResources || return 1
    fi
}

selectApp() {
    if [ "$1" == "extra" ]; then
        customOpt=(1 "Use Apk File" "Choose apk from storage.")
        incrementVal=1
    elif [ "$1" == "normal" ]; then
        unset customOpt
        incrementVal=0
    fi
    previousAppName="$appName"
    readarray -t availableApps < <(jq -n -r --arg incrementVal "$incrementVal" --argjson appsArray "$appsArray" '$appsArray[] | .index + ($incrementVal | tonumber), .appName, .pkgName')
    appIndex=$("${header[@]}" --begin 2 0 --title '| App Selection Menu |' --item-help --ok-label "Select" --cancel-label "Back" --menu "Use arrow keys to navigate\nSource: $sourceName" $(($(tput lines) - 3)) -1 15 "${customOpt[@]}" "${availableApps[@]}" 2>&1 >/dev/tty) || return 1
    if [ "$1" == "extra" ] && [ "$appIndex" -eq 1 ]; then
        appType=local
        unset appName appVer
    else
        readarray -t appSelectedResult < <(jq -n -r --arg incrementVal "$incrementVal" --arg appIndex "$appIndex" --argjson appsArray "$appsArray" '$appsArray[] | select(.index == (($appIndex | tonumber) - ($incrementVal | tonumber))) | .appName, .pkgName, .developerName, .apkmirrorAppName')
        appName="${appSelectedResult[0]}"
        pkgName="${appSelectedResult[1]}"
        developerName="${appSelectedResult[2]}"
        apkmirrorAppName="${appSelectedResult[3]}"
        appType=downloaded
    fi
    if [ "$previousAppName" != "$appName" ]; then
        unset appVerList
    fi
}

selectPatches() {
    checkJson || return 1
    while true; do
        toogleName=$(jq -r -n --arg pkgName "$pkgName" --argjson patchesJson "$patchesJson" --argjson includedPatches "$includedPatches" 'if [$patchesJson[] | .name as $patchName | .compatiblePackages | if (map(.name) | index($pkgName) != null) or length == 0 then $patchName else empty end] == ($includedPatches[] | select(.pkgName == $pkgName).includedPatches) then "Exclude All" else "Include All" end')
        readarray -t patchesInfo < <(
            jq -n -r --arg pkgName "$pkgName" \
                --argjson patchesJson "$patchesJson" \
                --argjson includedPatches "$includedPatches" \
                '$patchesJson[] | .name as $patchName | .description as $desc | .compatiblePackages | 
            if (((map(.name) | index($pkgName)) != null) or (length == 0)) then
                (if ((($includedPatches | length) != 0) and (($includedPatches[] | select(.pkgName == $pkgName).includedPatches | index($patchName)) != null)) then
                    $patchName, "on", $desc
                else
                    $patchName, "off", $desc
                end)
            else 
                empty
            end'
        )
        choices=($("${header[@]}" --begin 2 0 --title '| Patch Selection Menu |' --item-help --no-items --ok-label "$1" --cancel-label "$toogleName" --help-button --help-label "Recommended" --checklist "Use arrow keys to navigate; Press Spacebar to toogle patch\nSource: $sourceName; AppName: $appName" $(($(tput lines) - 3)) -1 15 "${patchesInfo[@]}" 2>&1 >/dev/tty))
        selectPatchStatus=$?
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
            includedPatches=$(jq -n --arg pkgName "$pkgName" --argjson patchesJson "$patchesJson" --argjson includedPatches "$includedPatches" '[$includedPatches[] | select(.pkgName == $pkgName).includedPatches = [$patchesJson[] | .name as $patchName | .compatiblePackages | if (((map(.name) | index($pkgName)) != null) or (length == 0)) then  $patchName else empty end]]')
        elif [ "$toogleName" == "Exclude All" ]; then
            includedPatches=$(jq -n --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" '[$includedPatches[] | select(.pkgName == $pkgName).includedPatches = []]')
        fi
        ;;
    2 )
        includedPatches=$(jq -n --arg pkgName "$pkgName" --argjson patchesJson "$patchesJson" --argjson includedPatches "$includedPatches" '[$includedPatches[] | select(.pkgName == $pkgName).includedPatches = [$patchesJson[] | .name as $patchName | .excluded as $excluded | .compatiblePackages | if ((((map(.name) | index($pkgName)) != null) or (length == 0)) and ($excluded == false)) then $patchName else empty end]]')
        ;;
    esac
}

editPatchOptions() {
    checkResources || return 1
    if [ ! -f "$storagePath/$source-options.json" ]; then
        "${header[@]}" --infobox "Please Wait !!\nGenerating options file..." 12 45
        java -jar "$cliSource"-cli-*.jar -b "$patchesSource"-patches-*.jar -m "$integrationsSource"-integrations-*.apk -c -a noinput.apk -o nooutput.apk --options "$storagePath/$source-options.json" >/dev/null 2>&1
    fi
    currentPatch="none"
    optionsJson=$(jq '.' "$storagePath/$source-options.json")
    readarray -t patchNames < <(jq -n -r --argjson optionsJson "$optionsJson" '$optionsJson[].patchName')
    while true; do
        if [ "$currentPatch" == "none" ]; then
            if ! currentPatch=$("${header[@]}" --begin 2 0 --title '| Patch Options Menu |' --no-items --ok-label "Select" --cancel-label "Back" --menu "Select Patch to edit options" -1 -1 15 "${patchNames[@]}" 2>&1 >/dev/tty); then
                jq -n --argjson optionsJson "$optionsJson" '$optionsJson' > "$storagePath/$source-options.json"
                break
            fi
        else
            tput cnorm
            readarray -t patchOptionEntries < <(jq -n -r --arg currentPatch "$currentPatch" --argjson optionsJson "$optionsJson" '$optionsJson[] | select(.patchName == $currentPatch) | .options | to_entries[] | .key as $key | (.value | (.key | length) as $wordLength | ((($key+1) | tostring) + ". " + .key + ":"), ($key*2)+1, 0, .value, ($key*2)+1, ($wordLength + 6), 100, 100, 0)')
            readarray -t newValues < <("${header[@]}" --begin 2 0 --title '| Patch Options Form |' --ok-label "Save" --cancel-label "Back" --mixedform "Edit patch options for \"$currentPatch\" patch" -1 -1 20 "${patchOptionEntries[@]}" 2>&1 >/dev/tty)
            if [ "${newValues[*]}" != "" ]; then
                optionsJson=$(jq -n -r --arg currentPatch "$currentPatch" --argjson optionsJson "$optionsJson" '$optionsJson | map((select(.patchName == $currentPatch) | .options) |= [(to_entries[] | .key as $key | .value.value = (if $ARGS.positional[$key] == "" then null elif $ARGS.positional[$key] == "null" then null elif $ARGS.positional[$key] == "true" then true elif $ARGS.positional[$key] == "false" then false else $ARGS.positional[$key] end)) | .value])' --args "${newValues[@]}")
            fi
            currentPatch="none"
            tput civis
        fi
    done
}

rootInstall() {
    "${header[@]}" --infobox "Please Wait !!\nInstalling Patched $appName..." 12 45
    if ! su -mm -c "/system/bin/sh $repoDir/root_util.sh mount $pkgName $appName $appVer $sourceName" > /dev/null 2>&1; then
        "${header[@]}" --msgbox "Installation Failed !!\nLogs saved to \"Internal-Storage/Revancify/install_log.txt\". Share the Install logs to developer." 12 45
        return 1
    else
        "${header[@]}" --msgbox "$appName installed Successfully !!" 12 45
    fi
    if [ "$launchAppAfterMount" == "true" ]; then
        su -c "settings list secure | sed -n -e 's/\/.*//' -e 's/default_input_method=//p' | xargs pidof | xargs kill -9 && pm resolve-activity --brief $pkgName | tail -n 1 | xargs am start -n && pidof com.termux | xargs kill -9" >/dev/null 2>&1
    fi
}

rootUninstall() {
    selectApp normal || return 1
    su -mm -c "/system/bin/sh $repoDir/root_util.sh unmount $pkgName" >/dev/null 2>&1
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

nonRootInstall() {
    "${header[@]}" --infobox "Copying $appName $sourceName $selectedVer to Internal Storage..." 12 45
    sleep 0.5
    cp -r "apps/$appName-$appVer/base-$sourceName.apk" "$storagePath/$appName-$appVer/base-$sourceName.apk" >/dev/null 2>&1
    termux-open "$storagePath/$appName-$appVer/base-$sourceName.apk"
    return 1
}

checkJson() {
    if ! ls "$patchesSource"-patches-*.json >/dev/null 2>&1; then
        getResources || return 1
        return 0
    fi
    if [ ! -f "$storagePath/$source-patches.json" ]; then
        internet || return 1
        "${header[@]}" --infobox "Please Wait !!" 12 45
        if [ "$(bash "$repoDir/fetch_patches.sh" "$source" online "$storagePath")" == "error" ]; then
            "${header[@]}" --msgbox "Oops !! Apkmirror API is not accessible. Patches are not successfully synced.\nRevancify may crash.\n\nChange your network." 12 45
            return 1
        fi
        includedPatches=$(jq '.' "$storagePath/$source-patches.json" 2>/dev/null || jq -n '[]')
        appsArray=$(jq -n --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '$includedPatches | to_entries | map(select(.value.appName != null)) | to_entries | map({"index": (.key + 1), "appName": (.value.value.appName), "pkgName" :(.value.value.pkgName), "developerName" :(.value.value.developerName), "apkmirrorAppName" :(.value.value.apkmirrorAppName)})')
    fi
}

checkResources() {
    if [ -f ".${source}-data" ]; then
        # shellcheck source=/dev/null
        source ./".${source}-data"
    else
        resourcesVars
        getResources || return 1
    fi
    if [ "$cliSize" = "$(ls "$cliSource"-cli-*.jar >/dev/null 2>&1 && du -b "$cliSource"-cli-*.jar | cut -d $'\t' -f 1 || echo 0)" ] && [ "$patchesSize" = "$(ls "$patchesSource"-patches-*.jar >/dev/null 2>&1 && du -b "$patchesSource"-patches-*.jar | cut -d $'\t' -f 1 || echo 0)" ] && [ "$integrationsSize" = "$(ls "$integrationsSource"-integrations-*.apk >/dev/null 2>&1 && du -b "$integrationsSource"-integrations-*.apk | cut -d $'\t' -f 1 || echo 0)" ] && ls "$storagePath/$source-patches.json" >/dev/null 2>&1; then
        :
    else
        getResources || return 1
    fi
}

getAppVer() {
    if [ "$rootStatus" = "root" ] && su -c "pm list packages | grep -q $pkgName" && [ "$allowVersionDowngrade" == "false" ]; then
        selectedVer=$(su -c dumpsys package "$pkgName" | sed -n '/versionName/s/.*=//p' | sed -n '1p')
        appVer="${selectedVer// /.}"
    fi
    if [ "${#appVerList[@]}" -lt 2 ]; then
        internet || return 1
        "${header[@]}" --infobox "Please Wait !!\nScraping versions list for $appName from apkmirror.com..." 12 45
        readarray -t appVerList < <(bash "$repoDir/fetch_versions.sh" "$apkmirrorAppName" "$source" "$repoDir" "$selectedVer" "$storagePath")
    fi
    versionSelector || return 1
}

versionSelector() {
    if [ "${appVerList[0]}" = "error" ]; then
        "${header[@]}" --msgbox "Unable to fetch link !!\nThere is some problem with your internet connection. Disable VPN or Change your network." 12 45
        return 1
    fi
    selectedVer=$("${header[@]}" --begin 2 0 --title '| Version Selection Menu |' --default-item "$selectedVer" --ok-label "Select" --cancel-label "Back" --menu "Use arrow keys to navigate\nSource: $sourceName; AppName: $appName" -1 -1 15 "${appVerList[@]}" 2>&1 >/dev/tty) || return 1
    if [ "$selectedVer" == "Auto Select" ]; then
        selectedVer=$(jq -n -r --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '$includedPatches[] | select(.pkgName == $pkgName) | .versions[-1]')
    fi
    appVer="${selectedVer// /.}"
}

checkPatched() {
    if [ -f "apps/$appName-$appVer/base-$sourceName.apk" ]; then
        "${header[@]}" --begin 2 0 --title '| Patched apk found |' --no-items --defaultno --yes-label 'Patch' --no-label 'Install' --help-button --help-label 'Back' --yesno "Current directory already contains Patched $appName version $selectedVer.\n\n\nDo you want to patch $appName again?" -1 -1
        apkFoundPrompt=$?
        case "$apkFoundPrompt" in
        0 )
            rm "apps/$appName-$appVer/base-$sourceName.apk"
            ;;
        1 )
            "${rootStatus}Install" && return 1
            ;;
        2 )
            return 1
            ;;
        esac
    else
        rm "apps/$appName-$appVer/base-$sourceName.apk" >/dev/null 2>&1
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
                [ ${#itemName} -gt $(("$(tput cols)" - 24)) ] && itemNameDisplay=${itemName:0:$(("$(tput cols)" - 34))}...${itemName: -10} || itemNameDisplay="$itemName"
                dirList+=("$((++num))" "$itemNameDisplay/" "DIR: $itemName/")
            elif [ "${itemName##*.}" == "apk" ]; then
                files+=("$itemName")
                [ ${#itemName} -gt $(("$(tput cols)" - 24)) ] && itemNameDisplay=${itemName:0:$(("$(tput cols)" - 34))}...${itemName: -10} || itemNameDisplay=$itemName
                dirList+=("$((++num))" "$itemNameDisplay" "APK: $itemName")
            fi
        done < <(ls -1 --group-directories-first "$currentPath")
        pathIndex=$("${header[@]}" --begin 2 0 --title '| Apk File Selection Menu |' --item-help --ok-label "Select" --menu "Use arrow keys to navigate\nCurrent Path: $currentPath/" $(($(tput lines) - 3)) -1 20 "${dirUp[@]}" "${dirList[@]}" 2>&1 >/dev/tty)
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
    if ! aaptData=$("$repoDir/binaries/aapt2_$arch" dump badging "$newPath"); then
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
    appVer="${selectedVer// /.}"
    if [ "$rootStatus" = "root" ] && su -c "pm list packages | grep -q $pkgName" && [ "$allowVersionDowngrade" == "false" ]; then
        installedVer=$(su -c dumpsys package "$pkgName" | sed -n '/versionName/s/.*=//p' | sed -n '1p')
        if [ "$installedVer" != "$selectedVer" ]; then
            compareArray=("$selectedVer" "$installedVer")
            IFS=$'\n' sorted=($(sort <<<"${compareArray[*]}")); unset IFS
            if [ "${sorted[0]}" != "$installedVer" ];then
                "${header[@]}" --msgbox "The selected version $selectedVer is lower then version $installedVer installed on your device.\nPlease Select a higher version !!" 12 45
                return 1
            fi
        fi
    fi
    [ -d "apps/$appName-$appVer" ] || mkdir -p "apps/$appName-$appVer"
    if [ "$rootStatus" == "nonRoot" ] && [ -d "apps/$appName-$appVer" ];then
        mkdir -p "$storagePath/$appName-$appVer"
    fi
    cp "$newPath" "apps/$appName-$appVer/base.apk"
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
    if [ "$(jq -n -r --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '$includedPatches[] | select(.pkgName == $pkgName) | .versions | length')" -eq 0 ]; then
        if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --yesno "Do you want to proceed with version $selectedVer for $appName?" -1 -1; then
            return 1
        fi
    else
        if [ "$(jq -n -r --arg selectedVer "$selectedVer" --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" '$includedPatches[] | select(.pkgName == $pkgName) | .versions | index($selectedVer)')" != "null" ]; then
            if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --yesno "Do you want to proceed with version $selectedVer for $appName?" -1 -1; then
                return 1
            fi
        else
            if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --yesno "The version $selectedVer is not supported. Supported versions are: \n$(jq -n -r --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" '$includedPatches[] | select(.pkgName == $pkgName).versions | length as $array_length | to_entries[] | if .key != ($array_length - 1) then .value + "," else .value end')\n\nDo you still want to proceed with version $selectedVer for $appName?" -1 -1; then
                return 1
            fi
        fi
    fi
    checkPatched || return 1
    if [ -f "apps/$appName-$appVer/base.apk" ]; then
        # shellcheck source=/dev/null
        if [ "$(source "apps/.appSize"; eval echo \$"${appName//-/_}"Size)" != "$([ -f "apps/$appName-$appVer/base.apk" ] && du -b "apps/$appName-$appVer/base.apk" | cut -d $'\t' -f 1 || echo 0)" ]; then
            downloadApp
        fi
    else
        rm -rf "apps/$appName"* >/dev/null 2>&1
        downloadApp
    fi
}

downloadApp() {
    internet || return 1
    appUrl=$( (bash "$repoDir/fetch_link.sh" "$developerName" "$apkmirrorAppName" "$appVer" "$repoDir" 2>&3 | "${header[@]}" --begin 2 0 --gauge "App    : $appName\nVersion: $selectedVer\n\nScraping Download Link..." -1 -1 0 >&2) 3>&1)
    tput civis
    appSize="$(curl -sLI "$appUrl" -A "$userAgent" | sed -n '/Content-Length/s/[^0-9]*//p' | tr -d '\r')"
    setEnv "${appName//-/_}Size" "$appSize" update "apps/.appSize"
    case $appUrl in
    "error" )
        "${header[@]}" --msgbox "Unable to fetch link !!\nThere is some problem with your internet connection. Disable VPN or Change your network." 12 45
        return 1
        ;;
    "noapk" )
        if [ "$rootStatus" == "nonRoot" ]; then
            "${header[@]}" --msgbox "No apk found on apkmirror.com for version $selectedVer !!\nTry selecting other version." 12 45
            getAppVer
        else
            "${header[@]}" --msgbox "No apk found on apkmirror.com for version $selectedVer !!\nPlease upgrade or degrade the version to patch it.\n\nSuggestion: Download apk manually and use that file to patch." 15 40
            return 1
        fi
        ;;
    "noversion" )
        "${header[@]}" --msgbox "This version is not uploaded on apkmirror.com!!\nPlease upgrade or degrade the version to patch it.\n\nSuggestion: Download apk manually and use that file to patch." 15 40
        return 1
        ;;
    esac
    [ -d "apps/$appName-$appVer" ] || mkdir -p "apps/$appName-$appVer"
    if [ "$rootStatus" == "nonRoot" ] && [ -d "apps/$appName-$appVer" ];then
        mkdir -p "$storagePath/$appName-$appVer"
    fi
    wget -q -c "$appUrl" -O "apps/$appName-$appVer/base.apk" --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "App    : $appName\nVersion: $selectedVer\nSize   : $(numfmt --to=iec --format="%0.1f" "$appSize")\n\nDownloading..." -1 -1
    tput civis
    sleep 0.5s
    if [ "$appSize" != "$(du -b "apps/$appName-$appVer/base.apk" | cut -d $'\t' -f 1)" ]; then
        "${header[@]}" --msgbox "Oh No !!\nUnable to complete download. Please Check your internet connection and Retry." 12 45
        return 1
    fi
}

downloadMicrog() {
    microgName=mMicroG microgRepo=inotia00
    if "${header[@]}" --begin 2 0 --title '| MicroG Prompt |' --no-items --defaultno --yesno "$microgName is used to run MicroG services without root.\nYouTube and YouTube Music won't work without it.\nIf you already have $microgName, You don't need to download it.\n\n\n\n\n\nDo you want to download $microgName app?" -1 -1; then
        internet || return 1
        readarray -t microgheaders < <(curl -s "https://api.github.com/repos/$microgRepo/$microgName/releases/latest" | jq -r --arg regex ".*$arch.*" '(.assets[] | if .name | test($regex) then .browser_download_url, .size else empty end), .tag_name')
        wget -q -c "${microgheaders[0]}" -O "$microgName-${microgheaders[2]}.apk" --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "App     : $microgName \nVersion : ${microgheaders[2]}\nSize    : $(numfmt --to=iec --format="%0.1f" "${microgheaders[1]}")\n\nDownloading..." -1 -1 && tput civis
        ls $microgName* >/dev/null 2>&1 && mv $microgName* "$storagePath/" && termux-open "$storagePath/$microgName-${microgheaders[2]}.apk"
    fi
}

patchApp() {
    if [ "$source" == "inotia00" ] && [ "$riplibsRVX" == "true" ]; then
        riplibArgs="--rip-lib=x86_64 --rip-lib=x86 --rip-lib=armeabi-v7a --rip-lib=arm64-v8a "
        riplibArgs="${riplibArgs//--rip-lib=$arch /}"
    fi
    if [ -f "$storagePath/custom.keystore" ] > /dev/null 2>&1
    then
        keystore="$storagePath/custom.keystore"
    else
        keystore="$repoDir"/revancify.keystore
    fi
    includedPatches=$(jq '.' "$storagePath/$source-patches.json" 2>/dev/null || jq -n '[]')
    patchesArg=$(jq -n -r --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '$includedPatches[] | select(.pkgName == $pkgName).includedPatches | if ((. | length) != 0) then (.[] | "-i " + .) else empty end')
    java -jar "$cliSource"-cli-*.jar -b "$patchesSource"-patches-*.jar -m "$integrationsSource"-integrations-*.apk -c -a "apps/$appName-$appVer/base.apk" -o "apps/$appName-$appVer/base-$sourceName.apk" $patchesArg $riplibArgs --keystore "$keystore" --custom-aapt2-binary "$repoDir/binaries/aapt2_$arch" --options "$storagePath/$source-options.json" --experimental --exclusive 2>&1 | tee "$storagePath/patch_log.txt" | "${header[@]}" --begin 2 0 --ok-label "Continue" --cursor-off-label --programbox "Patching $appName $selectedVer.apk" -1 -1
    echo -e "\n\n\nVariant: $rootStatus\nArch: $arch\nApp: $appName v$appVer\nCLI: $(ls "$cliSource"-cli-*.jar)\nPatches: $(ls "$patchesSource"-patches-*.jar)\nIntegrations: $(ls "$integrationsSource"-integrations-*.apk)\nPatches argument: ${patchesArg[*]}" >>"$storagePath/patch_log.txt"
    tput civis
    sleep 1
    if [ ! -f "apps/$appName-$appVer/base-$sourceName.apk" ]; then
        "${header[@]}" --msgbox "Oops, Patching failed !!\nLogs saved to \"Internal Storage > Revancify \> patch_log.txt\". Share the Patchlog to developer." 12 45
        return 1
    fi
}

checkMicrogPatch() {
    if [[ "$pkgName" != *"youtube"* ]]; then
        return 0
    fi
    microgPatch=$(jq -r -n --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" --argjson patchesJson "$patchesJson" '$patchesJson | (map(.name)[] | match(".*microg.*").string) as $microgPatch | .[] | select(.name == $microgPatch) | .compatiblePackages | if ((map(.name) | index($pkgName)) != null) then $microgPatch else empty end')
    if [ "$microgPatch" == "" ]; then
        return 0
    fi
    microgStatus=$(jq -n -r --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" --arg microgPatch "$microgPatch" '$includedPatches[] | select(.pkgName == $pkgName) | .includedPatches | index($microgPatch)')
    if [ "$microgStatus" != "null" ] && [ "$rootStatus" = "root" ]; then
        if "${header[@]}" --begin 2 0 --title '| MicroG warning |' --no-items --defaultno --yes-label "Continue" --no-label "Exclude" --yesno "You have a rooted device and you have included microg-support patch. This may result in $appName app crash.\n\n\nDo you want to exclude it or continue?" -1 -1; then
            return 0
        else
            jq -n -r --arg microgPatch "$microgPatch" --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '[$includedPatches[] | (select(.pkgName == $pkgName) | .includedPatches) |= del(.[(. | index($microgPatch))])]' >"$storagePath/$source-patches.json"
            return 0
        fi
    elif [ "$microgStatus" == "null" ] && [ "$rootStatus" = "nonRoot" ]; then
        if "${header[@]}" --begin 2 0 --title '| MicroG warning |' --no-items --defaultno --yes-label "Continue" --no-label "Include" --yesno "You have a non-rooted device and you have not included microg-support patch. This may result in $appName app crash.\n\n\nDo you want to include it or continue?" -1 -1; then
            return 0
        else
            jq -n -r --arg microgPatch "$microgPatch" --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '[$includedPatches[] | (select(.pkgName == $pkgName) | .includedPatches) |= . + [$microgPatch]]' >"$storagePath/$source-patches.json"
            return 0
        fi
    fi
}

deleteComponents() {
    while true; do
        delComponentPrompt=$("${header[@]}" --begin 2 0 --title '| Delete Components Menu |' --ok-label "Select" --cancel-label "Back" --menu "Use arrow keys to navigate\nSource: $sourceName" -1 -1 15 1 "Resources" 2 "Apps" 3 "Patch Options" 2>&1 >/dev/tty) || break
        case "$delComponentPrompt" in
        1 )
            if "${header[@]}" --begin 2 0 --title '| Delete Resources |' --no-items --defaultno --yesno "Please confirm to delete the resources.\nIt will delete the $sourceName CLI, patches and integrations." -1 -1; then
                rm "$cliSource"-cli-*.jar >/dev/null 2>&1
                rm "$patchesSource"-patches-*.jar >/dev/null 2>&1
                rm "$patchesSource"-patches-*.json >/dev/null 2>&1
                rm "$integrationsSource"-integrations-*.apk >/dev/null 2>&1
                "${header[@]}" --msgbox "All $sourceName Resources successfully deleted !!" 12 45
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
                rm "$storagePath/$source-options.json" >/dev/null 2>&1
                "${header[@]}" --msgbox "Options file successfully deleted for current source !!" 12 45
            fi
            ;;
        esac
    done
}

preferences() {
    prefsArray=("lightTheme" "$lightTheme" "Use Light theme for Revancify" "riplibsRVX" "$riplibsRVX" "[RVX] Removes extra libs from app" "forceUpdateCheckStatus" "$forceUpdateCheckStatus" "Check for resources update at startup" "patchMenuBeforePatching" "$patchMenuBeforePatching" "Shows Patches Menu before Patching starts" "launchAppAfterMount" "$launchAppAfterMount" "[Root] Launches app automatically after mount" allowVersionDowngrade "$allowVersionDowngrade" "[Root] Allows downgrading version if any such module is present")
    readarray -t prefsArray < <(for pref in "${prefsArray[@]}"; do sed 's/false/off/;s/true/on/' <<< "$pref"; done)
    read -ra newPrefs < <("${header[@]}" --begin 2 0 --title '| Preferences Menu |' --item-help --no-items --no-cancel --ok-label "Save" --checklist "Use arrow keys to navigate; Press Spacebar to toogle patch" $(($(tput lines) - 3)) -1 15 "${prefsArray[@]}" 2>&1 >/dev/tty)
    sed -i 's/true/false/' "$envFile"
    for newPref in "${newPrefs[@]}"; do
        setEnv "$newPref" true update "$envFile"
    done
    # shellcheck source=/dev/null
    source "$envFile"
    [ "$lightTheme" == "true" ] && theme=Light || theme=Dark
    export DIALOGRC="$repoDir/configs/.dialogrc$theme"
}

buildApk() {
    if [ "$appType" == "downloaded" ]; then
        fetchApk || return 1
    else
        fetchCustomApk || return 1
        selectPatches Proceed
    fi
    if [ "$appType" == "downloaded" ] && [ "$patchMenuBeforePatching" == "true" ]; then
        selectPatches Proceed
    fi
    checkMicrogPatch
    patchApp
    "${rootStatus}Install"
}

userAgent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36"
mainMenu() {
    mainMenu=$("${header[@]}" --begin 2 0 --title '| Main Menu |' --default-item "$mainMenu" --ok-label "Select" --cancel-label "Exit" --menu "Use arrow keys to navigate\nSource: $sourceName" -1 -1 15 1 "Patch App" 2 "Select Patches" 3 "Change Source" 4 "Update Resources" 5 "Edit Patch Options" 6 "$menuEntry" 7 "Delete Components" 8 "Preferences" 2>&1 >/dev/tty) || terminate 0
    case "$mainMenu" in
    1 )
        while true; do
            selectApp extra || break
            buildApk
        done
        ;;
    2 )
        while true; do
            selectApp normal || break
            selectPatches Save || break
        done
        ;;
    3 )
        changeSource
        ;;
    4 )
        getResources
        ;;
    5 )
        editPatchOptions
        ;;
    6 )
        if [ "$rootStatus" = "root" ]; then
            rootUninstall
        elif [ "$rootStatus" = "nonRoot" ]; then
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

if su -c exit >/dev/null 2>&1; then
    [ "$1" = '-n' ] && rootStatus=nonRoot || rootStatus=root
else
    rootStatus=nonRoot
fi

initialize

if [ "$forceUpdateCheckStatus" == "true" ]; then
    resourcesVars
    getResources
fi
while true; do
    unset appVerList appVer appName pkgName
    mainMenu
done