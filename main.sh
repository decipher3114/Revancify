#!/usr/bin/bash
terminate()
{
    pkill -9 java > /dev/null 2>&1
    clear
    exit ${1:-1}
}
trap terminate SIGTERM SIGINT SIGABRT


setup()
{
    storagePath=/storage/emulated/0
    arch=$(getprop ro.product.cpu.abi)
    mkdir -p "$storagePath/Revancify"
    path=$(find "$HOME" -type d -name "Revancify")
    header=(dialog --backtitle "Revancify | [Arch: $arch, SU: $variant]" --no-shadow)

    if ! ls settings.json > /dev/null 2>&1
    then
        echo '{"forceUpdateCheckStatus": false}' | jq '.' > settings.json
    fi

    if [ "$(jq -r '.theme' settings.json)" == "null" ]
    then
        tmp=$(mktemp) && jq '.theme |= "Dark"' settings.json > "$tmp" && mv "$tmp" settings.json
    fi
    theme=$(jq -r '.theme' settings.json)
    export DIALOGRC=.dialogrc$theme

    if [ "$(jq -r '.source' settings.json)" == "null" ]
    then
        readarray -t allSources < <(jq -r --arg source "$source" 'to_entries | .[] | .key,"["+.value.projectName+"]","on"' "$path"/sources.json)
        selectedSource=$("${header[@]}" --begin 2 0 --title '| Source Selection Menu |' --keep-window --no-cancel --ok-label "Done" --radiolist "Use arrow keys to navigate; Press Spacebar to select option" -1 -1 15 "${allSources[@]}" 2>&1> /dev/tty)
        tmp=$(mktemp) && jq --arg selectedSource "$selectedSource" '.source |= $selectedSource' settings.json > "$tmp" && mv "$tmp" settings.json
    fi

    source=$(jq -r '.source' settings.json)

    source <(jq -r --arg source "$source" '.[$source].sources | to_entries[] | .key+"Source="+.value.org' "$path"/sources.json)
    sourceName=$(jq -r --arg source "$source" '.[$source].projectName' "$path"/sources.json)

    if ls "$patchesSource"-patches.json > /dev/null 2>&1
    then
        bash "$path/fetch_patches.sh" "$source" > /dev/null 2>&1
    fi
}

internet()
{
    if ! ping -c 1 google.com > /dev/null 2>&1
    then
        "${header[@]}" --msgbox "Oops! No Internet Connection available.\n\nConnect to Internet and try again later." 12 40
        mainmenu
    fi
}

resourcesVars()
{
    internet

    fetchResources

    if [ "$(wc -l < ".${source}latest")" -lt "11" ]
    then
        "${header[@]}" --msgbox "Oops! Unable to connect to Github.\n\nRetry or change your Network." 12 40
        mainmenu
        return 0
    fi


    source ./".${source}latest"

    ls "$cliSource"-cli-*.jar > /dev/null 2>&1 && cliAvailable=$(basename "$cliSource"-cli-*.jar .jar | cut -d '-' -f 3) || cliAvailable="Not found"
    ls "$patchesSource"-patches-*.jar > /dev/null 2>&1 && patchesAvailable=$(basename "$patchesSource"-patches-*.jar .jar | cut -d '-' -f 3) || patchesAvailable="Not found"
    ls "$patchesSource"-patches-*.json > /dev/null 2>&1 && jsonAvailable=$(basename "$patchesSource"-patches-*.json .json | cut -d '-' -f 3) || jsonAvailable="Not found"
    ls "$integrationsSource"-integrations-*.apk > /dev/null 2>&1 && integrationsAvailable=$(basename "$integrationsSource"-integrations-*.apk .apk | cut -d '-' -f 3) || integrationsAvailable="Not found"

    cliAvailableSize=$( ls "$cliSource"-cli-*.jar > /dev/null 2>&1 && du -b "$cliSource"-cli-*.jar | cut -d $'\t' -f 1 || echo 0 )
    patchesAvailableSize=$( ls "$patchesSource"-patches-*.jar > /dev/null 2>&1 && du -b "$patchesSource"-patches-*.jar | cut -d $'\t' -f 1 || echo 0 )
    integrationsAvailableSize=$( ls "$integrationsSource"-integrations-*.apk > /dev/null 2>&1 && du -b "$integrationsSource"-integrations-*.apk | cut -d $'\t' -f 1 || echo 0 )
}


getResources()
{
    resourcesVars
    if [ "$patchesLatest" = "$patchesAvailable" ] && [ "$patchesLatest" = "$jsonAvailable" ] && [ "$cliLatest" = "$cliAvailable" ] && [ "$integrationsLatest" = "$integrationsAvailable" ] && [ "$cliSize" = "$cliAvailableSize" ] && [ "$patchesSize" = "$patchesAvailableSize" ] && [ "$integrationsSize" = "$integrationsAvailableSize" ]
    then
        if [ "$(bash "$path/fetch_patches.sh" "$source" online)" == "error" ]
        then
            "${header[@]}" --msgbox "Resources are already downloaded but patches are not successfully synced.\nRevancify may crash." 12 40
            mainmenu
            return 0
        fi
        "${header[@]}" --msgbox "Resources are already downloaded !!\n\nPatches are successfully synced." 12 40
        mainmenu
        return 0
    fi
    [ "$patchesLatest" != "$patchesAvailable" ] && rm "$patchesSource"-patches-*.jar > /dev/null 2>&1 && rm "$patchesSource"-patches-*.json > /dev/null 2>&1 && patchesAvailableSize=0
    [ "$cliLatest" != "$cliAvailable" ] && rm "$cliSource"-cli-*.jar > /dev/null 2>&1 && cliAvailableSize=0
    [ "$integrationsLatest" != "$integrationsAvailable" ] && rm "$integrationsSource"-integrations-*.apk > /dev/null 2>&1 && integrationsAvailableSize=0
    [ "$cliSize" != "$cliAvailableSize" ] &&\
    wget -q -c "$cliUrl" -O "$cliSource"-cli-"$cliLatest".jar --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "Source  : $sourceName\nResource: CLI\nVersion : $cliLatest\nSize    : $(numfmt --to=iec --format="%0.1f" "$cliSize")\n\nDownloading..." -1 -1 $(( $(( "$cliAvailableSize" * 100 )) / "$cliSize" )) && tput civis

    [ "$cliSize" != "$( ls "$cliSource"-cli-*.jar > /dev/null 2>&1 && du -b "$cliSource"-cli-*.jar | cut -d $'\t' -f 1 || echo 0 )" ] && "${header[@]}" --msgbox "Oops! Unable to download completely.\n\nRetry or change your Network." 12 40 && mainmenu && return 0

    [ "$patchesSize" != "$patchesAvailableSize" ] &&\
    wget -q -c "$patchesUrl" -O "$patchesSource"-patches-"$patchesLatest".jar --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "Source  : $sourceName\nResource: Patches\nVersion : $patchesLatest\nSize    : $(numfmt --to=iec --format="%0.1f" "$patchesSize")\n\nDownloading..." -1 -1 $(( $(( "$patchesAvailableSize" * 100 / "$patchesSize" )) )) && tput civis

    wget -q -c "$jsonUrl" -O "$patchesSource"-patches-"$patchesLatest".json --user-agent="$userAgent"

    [ "$patchesSize" != "$( ls "$patchesSource"-patches-*.jar > /dev/null 2>&1 && du -b "$patchesSource"-patches-*.jar | cut -d $'\t' -f 1 || echo 0 )" ] &&  "${header[@]}" --msgbox "Oops! Unable to download completely.\n\nRetry or change your Network." 12 40 && mainmenu && return 0

    [ "$integrationsSize" != "$integrationsAvailableSize" ] &&\
    wget -q -c "$integrationsUrl" -O "$integrationsSource"-integrations-"$integrationsLatest".apk --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "Source  : $sourceName\nResource: Integrations\nVersion : $integrationsLatest\nSize    : $(numfmt --to=iec --format="%0.1f" "$integrationsSize")\n\nDownloading..." -1 -1 $(( $((  "$integrationsAvailableSize" * 100 / "$integrationsSize" )) )) && tput civis

    [ "$integrationsSize" != "$( ls "$integrationsSource"-integrations-*.apk > /dev/null 2>&1 && du -b "$integrationsSource"-integrations-*.apk | cut -d $'\t' -f 1 || echo 0 )" ] && "${header[@]}" --msgbox "Oops! File not downloaded.\n\nRetry or change your Network." 12 40 && mainmenu && return 0

    if [ "$(bash "$path/fetch_patches.sh" "$source" online)" == "error" ]
    then
        "${header[@]}" --msgbox "Resources are successfully downloaded but patches are not successfully synced.\nRevancify may crash." 12 40
        mainmenu
        return 0
    fi
    mainmenu
    return 0
}

fetchResources()
{
    "${header[@]}" --infobox "Please Wait !!\nFetching resources data from github API..." 12 40
    readarray -t resources < <(jq -r --arg source "$source" '.[$source].sources | keys_unsorted[]' "$path"/sources.json)
    readarray -t links < <(jq -r --arg source "$source" '.[$source].sources[] | .org+"/"+.repo' "$path"/sources.json)
    : > ".${source}latest"
    i=0 && for resource in "${resources[@]}"
    do
        curl -s --fail-early --connect-timeout 2 --max-time 5  "https://api.github.com/repos/${links[$i]}/releases/latest" | jq -r --arg resource "$resource" '$resource+"Latest="+.tag_name, (.assets[] | if .content_type == "application/json" then "jsonUrl="+.browser_download_url, "jsonSize="+(.size|tostring) else $resource+"Url="+.browser_download_url, $resource+"Size="+(.size|tostring) end)' >> ".${source}latest"
        i=$(( "$i" + 1))
    done
}

changeSource()
{
    internet
    readarray -t allSources < <(jq -r --arg source "$source" 'to_entries | .[] | if .key == $source then .key,"["+.value.projectName+"]","on" else .key,"["+.value.projectName+"]","off" end' "$path"/sources.json)
    selectedSource=$("${header[@]}" --begin 2 0 --title '| Source Selection Menu |' --keep-window --no-cancel --ok-label "Done" --radiolist "Use arrow keys to navigate; Press Spacebar to select option" -1 -1 15 "${allSources[@]}" 2>&1> /dev/tty)
    if [ "$source" != "$selectedSource" ]
    then
        tmp=$(mktemp) && jq --arg selectedSource "$selectedSource" '.source |= $selectedSource' settings.json > "$tmp" && mv "$tmp" settings.json
        source="$selectedSource"
        source <(jq -r --arg source "$source" '.[$source].sources | to_entries[] | .key+"Source="+.value.org' "$path"/sources.json)
        sourceName=$(jq -r --arg source "$source" '.[$source].projectName' "$path"/sources.json)
        checkResources
    fi
    mainmenu
}

checkJson()
{
    if ! ls "$patchesSource"-patches-*.json > /dev/null 2>&1
    then
        "${header[@]}" --msgbox "No Json file found !!\nPlease download resources." 12 40
        getResources
        return 0
    fi
    if ! ls "$patchesSource"-patches.json > /dev/null 2>&1
    then
        internet
        if [ "$(bash "$path/fetch_patches.sh" "$source" online)" == "error" ]
        then
            "${header[@]}" --msgbox "Patches are not successfully synced.\nRevancify may crash." 12 40
            mainmenu
            return 0
        fi
    fi
    patchesJson=$(jq '.' "$patchesSource"-patches-*.json)
    includedPatches=$(jq '.' "$patchesSource-patches.json" 2>/dev/null || jq -n '[]')
}

selectApp()
{
    if [ "$1" == "extra" ]
    then
        customOpt=(1 "From Apk File" "Choose apk from storage.")
        incrementVal=1
    elif [ "$1" == "normal" ]
    then
        unset customOpt
        incrementVal=0
    fi
    checkJson
    previousAppName="$appName"
    appsArray=$(jq -n --arg incrementVal "$incrementVal" --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '$includedPatches | to_entries | map(select(.value.appName != null)) | to_entries | map({"index": (.key + 1+ ($incrementVal | tonumber)), "appName": (.value.value.appName), "pkgName" :(.value.value.pkgName), "developerName" :(.value.value.developerName), "apkmirrorAppName" :(.value.value.apkmirrorAppName)})')
    readarray -t availableApps < <(jq -n -r --argjson appsArray "$appsArray" '$appsArray[] | .index, .appName, .pkgName')
    appIndex=$("${header[@]}" --begin 2 0 --title '| App Selection Menu |' --item-help --keep-window --ok-label "Select" --cancel-label "Back" --menu "Use arrow keys to navigate\nSource: $sourceName" $(($(tput lines) - 3)) -1 15 "${customOpt[@]}" "${availableApps[@]}" 2>&1> /dev/tty)
    exitstatus=$?
    if [ $exitstatus -eq 0 ]
    then
        if [ "$1" == "extra" ] && [ "$appIndex" -eq 1 ]
        then
            appType=custom
        else
            readarray -t appSelectedResult < <(jq -n -r --arg appIndex "$appIndex" --argjson appsArray "$appsArray" '$appsArray[] | select(.index == ($appIndex | tonumber)) | .appName, .pkgName, .developerName, .apkmirrorAppName')
            appName="${appSelectedResult[0]}"
            pkgName="${appSelectedResult[1]}"
            developerName="${appSelectedResult[2]}"
            apkmirrorAppName="${appSelectedResult[3]}"
            appType=normal
        fi
    elif [ $exitstatus -ne 0 ]
    then
        mainmenu
    fi
    if [ "$previousAppName" != "$appName" ]
    then
        unset appVerList
    fi
}

selectPatches()
{
    checkJson
    toogleName=$(jq -r -n --arg pkgName "$pkgName" --argjson patchesJson "$patchesJson" --argjson includedPatches "$includedPatches" 'if [$patchesJson[] | .name as $patchName | .compatiblePackages | if (map(.name) | index($pkgName) != null) or length == 0 then $patchName else empty end] == ($includedPatches[] | select(.pkgName == $pkgName).includedPatches) then "Exclude All" else "Include All" end')
    readarray -t patchesInfo < <(jq -n -r --arg pkgName "$pkgName"\
        --argjson patchesJson "$patchesJson"\
        --argjson includedPatches "$includedPatches"\
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
    choices=($("${header[@]}" --begin 2 0 --title '| Patch Selection Menu |' --item-help --no-items --keep-window --ok-label "Save" --cancel-label "$toogleName" --help-button --help-label "Recommended" --checklist "Use arrow keys to navigate; Press Spacebar to toogle patch\nSource: $sourceName; AppName: $appName" $(($(tput lines) - 3)) -1 15 "${patchesInfo[@]}" 2>&1 >/dev/tty))
    selectPatchStatus=$?
    patchSaver
    if [ "$appType" == "normal" ]
    then
        selectApp normal
        selectPatches
    fi
}

patchSaver()
{
    if [ $selectPatchStatus -eq 0 ]
    then
        jq -n --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" '[$includedPatches[] | select(.pkgName == $pkgName).includedPatches = $ARGS.positional]' --args "${choices[@]}" > "$patchesSource-patches.json"
        return 0
    elif [ $selectPatchStatus -eq 1 ]
    then
        if [ "$toogleName" == "Include All" ]
        then
            jq -n --arg pkgName "$pkgName" --argjson patchesJson "$patchesJson" --argjson includedPatches "$includedPatches" '[$includedPatches[] | select(.pkgName == $pkgName).includedPatches = [$patchesJson[] | .name as $patchName | .compatiblePackages | if (((map(.name) | index($pkgName)) != null) or (length == 0)) then  $patchName else empty end]]' > "$patchesSource-patches.json"
            selectPatches
        elif [ "$toogleName" == "Exclude All" ]
        then
            jq -n --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" '[$includedPatches[] | select(.pkgName == $pkgName).includedPatches = []]' > "$patchesSource-patches.json"
            selectPatches
        fi
    elif [ $selectPatchStatus -eq 2 ]
    then
        jq -n --arg pkgName "$pkgName" --argjson patchesJson "$patchesJson" --argjson includedPatches "$includedPatches" '[$includedPatches[] | select(.pkgName == $pkgName).includedPatches = [$patchesJson[] | .name as $patchName | .excluded as $excluded | .compatiblePackages | if ((((map(.name) | index($pkgName)) != null) or (length == 0)) and ($excluded == false)) then $patchName else empty end]]' > "$patchesSource-patches.json"
        selectPatches
    fi
}

editPatchOptions()
{
    checkResources
    "${header[@]}" --infobox "Please Wait !!\nGenerating options file for $sourceName patches..." 12 40
    java -jar "$cliSource"-cli-*.jar -b "$patchesSource"-patches-*.jar -m "$integrationsSource"-integrations-*.apk -c -a noinput.apk -o nooutput.apk --options "$storagePath/Revancify/$source-options.toml" > /dev/null 2>&1
    "${header[@]}" --begin 2 0 --title '| Open Options File |' --no-items --defaultno --keep-window --yes-label "Text Editor" --no-label "Termux Dialog" --help-button --help-label "Cancel" --yesno "How do you want to open editor the options file?" -1 -1
    optionsExitStatus=$?
    if [ "$optionsExitStatus" -eq 0 ]
    then
        "${header[@]}" --infobox "Please Wait !!\nOpening File..." 12 40
        termux-open "$storagePath/Revancify/$source-options.toml" --content-type text
        "${header[@]}" --msgbox "Command to open the editor for options file was successfully executed.\nIf the editor is not opened, then you may need to install any text editor app in your device or You can edit the file in Termux Dialog." 14 40
    elif [ "$optionsExitStatus" -eq 1 ]
    then
        tput cnorm
        tmp=$(mktemp) && "${header[@]}" --begin 2 0 --ok-label "Save" --cancel-label "Exit" --keep-window --title '| Options File Editor |' --editbox "$storagePath/Revancify/$source-options.toml" -1 -1 2> "$tmp" && mv "$tmp" "$storagePath/Revancify/$source-options.toml"
        tput civis
    fi
    mainmenu
}

rootInstall()
{
    if [ "$installedStatus" == "false" ]
    then
        "${header[@]}" --infobox "Installing stock $appName app..." 12 40
        su -c pm install --user 0 -i com.android.vending -r -d "$appName-$appVer".apk > /dev/null 2>&1
    fi
    "${header[@]}" --infobox "Mounting $appName Revanced on stock app..." 12 40
    su -mm -c "/system/bin/sh $path/mount_apk.sh $appName $pkgName $appVer" > /dev/null 2>&1
    if ! su -c "grep -q $pkgName /proc/mounts"
    then
        "${header[@]}" --infobox "Mount Failed !!\nLogs saved to Revancify folder. Share the Mountlog to developer." 12 40
        sleep 1
        mainmenu
    fi
    cat << EOF > "mount_revanced_$pkgName.sh"
#!/system/bin/sh
while [ "\$(getprop sys.boot_completed | tr -d '\r')" != "1" ]; do sleep 3; done

base_path="/data/local/tmp/revancify/$pkgName.apk"
stock_path="\$(pm path $pkgName | sed -n '/base/s/package://p')"
chcon u:object_r:apk_data_file:s0 "\$base_path"
[ ! -z "\$stock_path" ] && mount -o bind "\$base_path" "\$stock_path"
am force-stop $pkgName
EOF
    cat << EOF > "umount_revanced_$pkgName.sh"
#!/system/bin/sh
stock_path="\$(pm path $pkgName | sed -n '/base/s/package://p')"
[ ! -z "\$stock_path" ] && umount -l "\$stock_path"
grep $pkgName /proc/mounts | | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l
EOF
    su -c "mv mount_revanced_$pkgName.sh /data/adb/service.d && chmod 0744 /data/adb/service.d/mount_revanced_$pkgName.sh && mv umount_revanced_$pkgName.sh /data/adb/post-fs-data.d && chmod 0744 /data/adb/post-fs-data.d/umount_revanced_$pkgName.sh"
    sleep 1
    if "${header[@]}" --begin 2 0 --title '| Apk Mounted |' --no-items --keep-window --yesno "App Mounted Successfully !!\nDo you want to launch app??" -1 -1
    then
        su -c "settings list secure | sed -n -e 's/\/.*//' -e 's/default_input_method=//p' | xargs pidof | xargs kill -9 && pm resolve-activity --brief $pkgName | tail -n 1 | xargs am start -n && pidof com.termux | xargs kill -9" > /dev/null 2>&1
    else
        mainmenu
    fi
}

rootUninstall()
{
    selectApp normal
    if ! su -c "grep -q $pkgName /proc/mounts"
    then
        "${header[@]}" --msgbox "$appName Revanced is not installed(mounted) in your device." 12 40
        extrasMenu
    fi
    "${header[@]}" --infobox "Uninstalling $appName Revanced by Unmounting..." 12 40
    pkgName=$pkgName su -mm -c 'am force-stop $pkgName && grep $pkgName /proc/mounts | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l && stockApp=$(pm path $pkgName | sed -n "/base/s/package://p") && am force-stop $pkgName && rm /data/adb/service.d/mount_revanced_$pkgName.sh && rm /data/adb/post-fs-data.d/umount_revanced_$pkgName.sh && rm -rf /data/local/tmp/revancify/$pkgName.apk' > /dev/null 2>&1
    sleep 0.5s
    if ! su -c "grep -q $pkgName /proc/mounts"
    then
        "${header[@]}" --infobox "Uninstall Successful !!" 12 40
        sleep 1
        extrasMenu
    else
        "${header[@]}" --infobox "Uninstall failed !! Something went wrong." 12 40
        sleep 1
        extrasMenu
    fi
}

nonRootInstall()
{
    "${header[@]}" --infobox "Copying $appName-Revanced $selectedVer to Internal Storage..." 12 40
    sleep 0.5
    cp "$appName-Revanced"* "$storagePath/Revancify/" > /dev/null 2>&1
    termux-open "$storagePath/Revancify/$appName-Revanced-$appVer.apk"
    mainmenu
}

checkResources()
{
    if ls ".${source}latest" > /dev/null 2>&1
    then
        source ./".${source}latest"
    else
        resourcesVars
        getResources
    fi

    if [ "$cliSize" = "$( ls "$cliSource"-cli-*.jar > /dev/null 2>&1 && du -b "$cliSource"-cli-*.jar | cut -d $'\t' -f 1 || echo 0 )" ] && [ "$patchesSize" = "$( ls "$patchesSource"-patches-*.jar > /dev/null 2>&1 && du -b "$patchesSource"-patches-*.jar | cut -d $'\t' -f 1 || echo 0 )" ] && [ "$integrationsSize" = "$( ls "$integrationsSource"-integrations-*.apk > /dev/null 2>&1 && du -b "$integrationsSource"-integrations-*.apk | cut -d $'\t' -f 1 || echo 0 )" ] && ls "$patchesSource"-patches.json > /dev/null 2>&1
    then
        return 0
    else
        getResources
    fi
}

flag="$1"
checkSU()
{
    if su -c exit > /dev/null 2>&1
    then
        if [ "$flag" = '-n' ]
        then
            variant=nonRoot
        else
            variant=root
            su -c "mkdir -p /data/local/tmp/revancify"
        fi
    else
        variant=nonRoot
    fi
}

getAppVer()
{
    checkResources
    if [ "$variant" = "root" ]
    then
        if ! su -c "pm path $pkgName" > /dev/null 2>&1
        then
            installedStatus=false
            if ! "${header[@]}" --begin 2 0 --title '| Apk Not Installed |' --no-items --keep-window --yesno "$appName is not installed on your rooted device. You can choose the version and Revancify will install it before mounting it.\nDo you want to proceed?" -1 -1
            then
                mainmenu
            fi
            if [ -z "$appVerList" ]
            then
                internet
                "${header[@]}" --infobox "Please Wait !!\nScraping versions list for $appName from apkmirror.com..." 12 40
                readarray -t appVerList < <(bash "$path/fetch_versions.sh" "$apkmirrorAppName" "$source" "$path")
            fi
            versionSelector
        else
            selectedVer=$(su -c dumpsys package "$pkgName" | grep versionName | cut -d '=' -f 2 | sed -n '1p')
            appVer="$(sed 's/\./-/g;s/ /-/g' <<< "$selectedVer")"
        fi
    elif [ "$variant" = "nonRoot" ]
    then
        if [ "${#appVerList[@]}" -eq 0 ]
        then
            internet
            "${header[@]}" --infobox "Please Wait !!\nScraping versions list for $appName from apkmirror.com..." 12 40
            readarray -t appVerList < <(bash "$path/fetch_versions.sh" "$apkmirrorAppName" "$source" "$path")
        fi
        versionSelector
    fi
    fetchApk
}

versionSelector()
{
    if [ "${appVerList[0]}" = "error" ]
    then
        "${header[@]}" --msgbox "Unable to fetch link !!\nThere is some problem with your internet connection. Disable VPN or Change your network." 12 40
        mainmenu
    fi
    selectedVer=$("${header[@]}" --begin 2 0 --title '| Version Selection Menu |' --keep-window --ok-label "Select" --cancel-label "Back" --menu "Use arrow keys to navigate\nSource: $sourceName; AppName: $appName" -1 -1 15 "${appVerList[@]}" 2>&1> /dev/tty)
    exitstatus=$?
    if [ "$selectedVer" == "Auto Select" ]
    then
        selectedVer=$(jq -n -r --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '$includedPatches[] | select(.pkgName == $pkgName) | .versions[-1]')
    fi
    appVer="$(sed 's/\./-/g;s/ /-/g' <<< "$selectedVer")"
    if [ $exitstatus -ne 0 ]
    then
        selectApp extra
        getAppVer
        return 0
    fi
}

checkPatched()
{
    if ls "$appName-Revanced-$appVer"* > /dev/null 2>&1
    then
        "${header[@]}" --begin 2 0 --title '| Patched apk found |' --no-items --defaultno --help-button --help-label 'Back' --keep-window --yesno "Current directory already contains $appName Revanced version $selectedVer.\n\n\nDo you want to patch $appName again?" -1 -1
        apkFoundPrompt=$?
        if [ "$apkFoundPrompt" -eq 0 ]
        then
            rm "$appName-Revanced-$appVer"*
        elif [ "$apkFoundPrompt" -eq 1 ]
        then
            ${variant}Install
        elif [ "$apkFoundPrompt" -eq 2 ]
        then
            mainmenu
            return 0
        fi
    else
        rm "$appName-Revanced-"* > /dev/null 2>&1
    fi
}

selectFile()
{
    currentPath=${currentPath:-$storagePath}
    dirList=()
    files=()
    if [ "$currentPath" != "$storagePath" ]
    then
        dirUp=(1 ".." "GO BACK TO PREVIOUS DIRECTORY")
        num=1
    else
        unset dirUp
        num=0
    fi
    while read -r itemName
    do
        if [ -d "$currentPath/$itemName" ]
        then
            files+=("$itemName")
            [ ${#itemName} -gt $(( "$(tput cols)" - 24 )) ] && itemNameDisplay=${itemName:0:$(( "$(tput cols)" - 34 ))}...${itemName: -10} || itemNameDisplay="$itemName"
            dirList+=("$((++num))" "$itemNameDisplay/" "DIR: $itemName/")
        elif [ "${itemName##*.}" == "apk" ]
        then
            files+=("$itemName")
            [ ${#itemName} -gt $(( "$(tput cols)" - 24 )) ] && itemNameDisplay=${itemName:0:$(( "$(tput cols)" - 34 ))}...${itemName: -10} || itemNameDisplay=$itemName
            dirList+=("$((++num))" "$itemNameDisplay" "APK: $itemName")
        fi
    done < <(ls -1 --group-directories-first "$currentPath")
    pathIndex=$("${header[@]}" --begin 2 0 --title '| Apk File Selection Menu |' --item-help --ok-label "Select" --menu "Use arrow keys to navigate\nCurrent Path: $currentPath/" $(($(tput lines) - 3)) -1 20 "${dirUp[@]}" "${dirList[@]}" 2>&1> /dev/tty)
    exitstatus=$?
    if [ $exitstatus -eq 1 ]
    then
        mainmenu
        return 0
    fi
    if [ "$currentPath" != "$storagePath" ] && [ "$pathIndex" -eq 1 ]
    then
        newPath=".."
    elif [ "$currentPath" != "$storagePath" ] && [ "$pathIndex" -ne 1 ]
    then
        newPath=${files[$pathIndex - 2]}
    else
        newPath=${files[$pathIndex - 1]}
    fi
    if [ "$newPath" == ".." ]
    then
        newPath=${currentPath%/*}
    else
        newPath=$currentPath/$newPath
    fi
    if [ -d "$newPath" ]
    then
        currentPath=$newPath
        selectFile
    elif [ -f "$newPath" ]
    then
        if [ "${newPath##*.}" != "apk" ]
        then
            "${header[@]}" --msgbox "$(basename "$newPath") is not an apk file. Please select again !!" 12 40
            selectFile
        fi
    fi
}

fetchCustomApk()
{
    selectFile
    "${header[@]}" --infobox "Please Wait !!\nExtracting data from \"$(basename "$newPath")\"" 12 40
    if ! aaptData=$("$path/binaries/aapt2_$arch" dump badging "$newPath")
    then
        "${header[@]}" --msgbox "The apkfile you selected is not an valid app. Download the apk again and retry." 12 40
        mainmenu
    fi
    pkgName=$(grep "package:" <<< "$aaptData" | sed -e 's/package: name='\''//' -e 's/'\'' versionCode.*//')
    if [ "$(jq -n --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" '$includedPatches[] | select(.pkgName == $pkgName) | .patches')" == "" ]
    then
        "${header[@]}" --msgbox "The app you selected is not supported for patching by $sourceName patches !!" 12 40
        mainmenu
    fi
    fileAppName=$(grep "application-label:" <<< "$aaptData" | sed -e 's/application-label://' -e 's/'\''//g')
    appName="$(sed 's/\./-/g;s/ /-/g' <<< "$fileAppName")"
    selectedVer=$(grep "package:" <<< "$aaptData" | sed -e 's/.*versionName='\''//' -e 's/'\'' platformBuildVersionName.*//')
    appVer="$(sed 's/\./-/g;s/ /-/g' <<< "$selectedVer")"
    if [ "$variant" = "root" ]
    then
        if ! su -c "pm path $pkgName" > /dev/null 2>&1
        then
            if "${header[@]}" --begin 2 0 --title '| Apk Not Installed |' --no-items --defaultno --keep-window --yes-label "Non-Root" --no-label "Play Store" --yesno "$appName is not installed on your rooted device.\nYou have to install it from Play Store or you can proceed with Non-Root installation?\n\nWhich method do you want to proceed with?" -1 -1
            then
                variant="nonRoot"
                return 0
            else
                termux-open-url "https://play.google.com/store/apps/details?id=$pkgName"
                mainmenu
            fi
        fi
    fi
    cp "$newPath" "$appName-$appVer.apk"
    if [ "$(jq -n -r --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '$includedPatches[] | select(.pkgName == $pkgName) | .versions | length')" -eq 0 ]
    then
        if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --keep-window --yesno "The following data is extracted from the apk file you provided.\nApp Name    : $fileAppName\nPackage Name: $pkgName\nVersion     : $selectedVer\nDo you want to proceed with this app?" -1 -1
        then
            mainmenu
            return 0
        fi
    else
        if [ "$(jq -n -r --arg selectedVer "$selectedVer" --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" '$includedPatches[] | select(.pkgName == $pkgName) | .versions | index($selectedVer)')" != "null" ]
        then
            if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --keep-window --yesno "The following data is extracted from the apk file you provided.\nApp Name    : $fileAppName\nPackage Name: $pkgName\nVersion     : $selectedVer\nDo you want to proceed with this app?" -1 -1
            then
                mainmenu
                return 0
            fi
        else
            if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --keep-window --yesno "The following data is extracted from the apk file you provided.\nApp Name    : $fileAppName\nPackage Name: $pkgName\nVersion     : $selectedVer\n\nThe version $selectedVer is not supported. Supported versions are: \n$(jq -n -r --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" '$includedPatches[] | select($pkgName).versions | length as $array_length | to_entries[] | if .key != ($array_length - 1) then .value + "," else .value end')\n\nDo you still want to proceed with version $selectedVer for $appName?" -1 -1
            then
                mainmenu
                return 0
            fi
        fi
    fi
    checkPatched
}

fetchApk()
{
    if [ "$(jq -n -r --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '$includedPatches[] | select(.pkgName == $pkgName) | .versions | length')" -eq 0 ]
    then
        if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --keep-window --yesno "Do you want to proceed with version $selectedVer for $appName?" -1 -1
        then
            mainmenu
            return 0
        fi
    else
        if [ "$(jq -n -r --arg selectedVer "$selectedVer" --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" '$includedPatches[] | select(.pkgName == $pkgName) | .versions | index($selectedVer)')" != "null" ]
        then
            if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --keep-window --yesno "Do you want to proceed with version $selectedVer for $appName?" -1 -1
            then
                mainmenu
                return 0
            fi
        else
            if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --keep-window --yesno "The version $selectedVer is not supported. Supported versions are: \n$(jq -n -r --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" '$includedPatches[] | select($pkgName).versions | length as $array_length | to_entries[] | if .key != ($array_length - 1) then .value + "," else .value end')\n\nDo you still want to proceed with version $selectedVer for $appName?" -1 -1
            then
                mainmenu
                return 0
            fi
        fi
    fi
    checkPatched
    if ls "$appName"-"$appVer"* > /dev/null 2>&1
    then
        if [ "$([ -f ".${appName}size" ] && cat ".${appName}size" || echo "0" )" != "$([ -f "$appName"-"$appVer".apk ] && du -b "$appName"-"$appVer".apk | cut -d $'\t' -f 1 || echo 0)" ]
        then
            downloadApp
        fi
    else
        rm "$appName"*.apk > /dev/null 2>&1
        downloadApp
    fi
}

downloadApp()
{
    internet
    appUrl=$( ( bash "$path/fetch_link.sh" "$developerName" "$apkmirrorAppName" "$appVer" "$path" 2>&3 | "${header[@]}" --begin 2 0 --gauge "App    : $appName\nVersion: $selectedVer\n\nScraping Download Link..." -1 -1 0 >&2 ) 3>&1 )
    tput civis
    curl -sLI "$appUrl" -A "$userAgent" | sed -n '/Content-Length/s/[^0-9]*//p' | tr -d '\r' > ".${appName}size"
    if [ "$appUrl" = "error" ]
    then
        "${header[@]}" --msgbox "Unable to fetch link !!\nThere is some problem with your internet connection. Disable VPN or Change your network." 12 40
        mainmenu
        return 0
    elif [ "$appUrl" = "noapk" ]
    then
        if [ "$variant" == "nonRoot" ]
        then
            "${header[@]}" --msgbox "No apk found on apkmirror.com for version $selectedVer !!\nTry selecting other version." 12 40
            getAppVer
        else
            "${header[@]}" --msgbox "No apk found on apkmirror.com for version $selectedVer !!\nPlease upgrade or degrade the version to patch it.\n\nSuggestion: Download apk manually and use that file to patch." 15 40
            mainmenu
        fi
        return 0
    elif [ "$appUrl" = "noversion" ]
    then
        "${header[@]}" --msgbox "This version is not uploaded on apkmirror.com!!\nPlease upgrade or degrade the version to patch it.\n\nSuggestion: Download apk manually and use that file to patch." 15 40
        mainmenu
        return 0
    fi
    wget -q -c "$appUrl" -O "$appName"-"$appVer".apk --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "App    : $appName\nVersion: $selectedVer\nSize   : $(numfmt --to=iec --format="%0.1f" < ".${appName}size" )\n\nDownloading..." -1 -1
    tput civis
    sleep 0.5s
    if [ "$(cat ".${appName}size")" != "$(du -b "$appName"-"$appVer".apk | cut -d $'\t' -f 1)" ]
    then
        "${header[@]}" --msgbox "Oh No !!\nUnable to complete download. Please Check your internet connection and Retry." 12 40
        mainmenu
    fi
}

downloadMicrog()
{

    if "${header[@]}" --begin 2 0 --title '| MicroG Prompt |' --no-items --defaultno --keep-window --yesno "Vanced MicroG is used to run MicroG services without root.\nYouTube and YouTube Music won't work without it.\nIf you already have MicroG, You don't need to download it.\n\n\n\n\n\nDo you want to download Vanced MicroG app?" -1 -1
    then
        internet
        readarray -t microgheaders < <(curl -s "https://api.github.com/repos/inotia00/VancedMicroG/releases/latest" | jq -r '(.assets[] | .browser_download_url, .size), .tag_name')
        wget -q -c "${microgheaders[0]}" -O "VancedMicroG-${microgheaders[2]}.apk" --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "App     : Vanced MicroG\nVersion : ${microgheaders[2]}\nSize    : $(echo "${microgheaders[1]}" | numfmt --to=iec --format="%0.1f")\n\nDownloading..." -1 -1 && tput civis
        ls VancedMicroG* > /dev/null 2>&1 && mv VancedMicroG* "$storagePath/Revancify/" && termux-open "$storagePath/Revancify/VancedMicroG-${microgheaders[2]}.apk"
    fi
    extrasMenu
}

patchApp()
{
    checkJson
    patchesArg=$(jq -n -r --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '$includedPatches[] | select(.pkgName == $pkgName).includedPatches | if ((. | length) != 0) then (.[] | "-i " + .) else empty end')
    java -jar "$cliSource"-cli-*.jar -b "$patchesSource"-patches-*.jar -m "$integrationsSource"-integrations-*.apk -c -a "$appName-$appVer.apk" -o "$appName-Revanced-$appVer.apk" $patchesArg --keystore "$path"/revanced.keystore --custom-aapt2-binary "$path/binaries/aapt2_$arch" --options "$storagePath/Revancify/$source-options.toml" --experimental --exclusive 2>&1 | tee "$storagePath/Revancify/patchlog.txt" | "${header[@]}" --begin 2 0 --ok-label "Continue" --cursor-off-label --programbox "Patching $appName-$appVer.apk" -1 -1
    echo -e "\n\n\nVariant: $variant\nArch: $arch\nApp: $appName-$appVer.apk\nCLI: $(ls "$cliSource"-cli-*.jar)\nPatches: $(ls "$patchesSource"-patches-*.jar)\nIntegrations: $(ls "$integrationsSource"-integrations-*.apk)\nPatches argument: ${patchesArg[*]}" >> "$storagePath/Revancify/patchlog.txt"
    tput civis
    sleep 1
    if ! grep -q "Finished" "$storagePath/Revancify/patchlog.txt"
    then
        "${header[@]}" --msgbox "Oops, Patching failed !!\nLog file saved to Revancify folder. Share the Patchlog to developer." 12 40
        mainmenu
    fi
}

checkMicrogPatch()
{
    microgPatch=$(jq -r -n --arg pkgName "$pkgName" --argjson includedPatches "$includedPatches" --argjson patchesJson "$patchesJson" '$patchesJson | (map(.name)[] | match(".*microg.*").string) as $microgPatch | .[] | select(.name == $microgPatch) | .compatiblePackages | if ((map(.name) | index($pkgName)) != null) then $microgPatch else empty end')
    if [ "$microgPatch" == "" ]
    then
        return 0
    fi 
    microgStatus=$(jq -n -r --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" --arg microgPatch $microgPatch '$includedPatches[] | select(.pkgName == $pkgName) | .includedPatches | index($microgPatch)')
    if [ "$microgStatus" != "null" ] && [ "$variant" = "root" ]
    then
        if "${header[@]}" --begin 2 0 --title '| MicroG warning |' --no-items --defaultno --keep-window --yes-label "Continue" --no-label "Exclude" --yesno "You have a rooted device and you have included microg-support patch. This may result in $appName app crash.\n\n\nDo you want to exclude it or continue?" -1 -1
        then
            return 0
        else
            jq -n -r --arg microgPatch "$microgPatch" --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '[$includedPatches[] | (select(.pkgName == $pkgName) | .includedPatches) |= del(.[(. | index($microgPatch))])]' > "$patchesSource-patches.json"
            return 0
        fi
    elif [ "$microgStatus" == "null" ] && [ "$variant" = "nonRoot" ]
    then
        if "${header[@]}" --begin 2 0 --title '| MicroG warning |' --no-items --defaultno --keep-window --yes-label "Continue" --no-label "Include" --yesno "You have a non-rooted device and you have not included microg-support patch. This may result in $appName app crash.\n\n\nDo you want to include it or continue?" -1 -1
        then
            return 0
        else
            jq -n -r --arg microgPatch "$microgPatch" --argjson includedPatches "$includedPatches" --arg pkgName "$pkgName" '[$includedPatches[] | (select(.pkgName == $pkgName) | .includedPatches) |= . + [$microgPatch]]' > "$patchesSource-patches.json"
            return 0
        fi
    fi
}

switchTheme()
{
    allThemes=(Default off Dark off Light off)
    for i in "${!allThemes[@]}"
    do
        if [ "${allThemes[$i]}" == "$(jq -r '.theme' settings.json)" ]
        then
            allThemes["$(( "$i" + 1 ))"]="on"
        fi
    done
    selectedTheme=$("${header[@]}" --begin 2 0 --title '| Theme Selection Menu |' --no-items --keep-window --no-cancel --ok-label "Done" --radiolist "Use arrow keys to navigate; Press Spacebar to select option" -1 -1 15 "${allThemes[@]}" 2>&1> /dev/tty)
    tmp=$(mktemp) && jq --arg selectedTheme "$selectedTheme" '.theme |= $selectedTheme' settings.json > "$tmp" && mv "$tmp" settings.json
    export DIALOGRC=.dialogrc$selectedTheme
    extrasMenu
}

extrasMenu()
{
    [ "$variant" = "root" ] && misc=(6 "Uninstall Revanced app") || misc=(6 "Download Vanced Microg")
    extrasPrompt=$("${header[@]}" --begin 2 0 --title '| Extras Menu |' --keep-window --ok-label "Select" --cancel-label "Back" --menu "Use arrow keys to navigate\nSource: $sourceName" -1 -1 15 1 "Delete Resources" 2 "Delete Apps" 3 "Delete Options.toml" 4 "Resources Update on startup" 5 "Switch Theme" "${misc[@]}" 2>&1> /dev/tty)
    extrasExitStatus=$?
    if [ "$extrasExitStatus" -ne 0 ]
    then
        mainmenu
    fi
    if [ "$extrasPrompt" -eq 1 ]
    then
        if "${header[@]}" --begin 2 0 --title '| Delete Resources |' --no-items --defaultno --keep-window --yesno "Please confirm to delete the resources.\nIt will delete the $sourceName CLI, patches and integrations." -1 -1
        then
            rm "$cliSource"-cli-*.jar > /dev/null 2>&1
            rm "$patchesSource"-patches-*.jar > /dev/null 2>&1
            rm "$patchesSource"-patches-*.json > /dev/null 2>&1
            rm "$integrationsSource"-integrations-*.apk > /dev/null 2>&1
            "${header[@]}" --msgbox "All $sourceName Resources successfully deleted !!" 12 40
        fi
    elif [ "$extrasPrompt" -eq 2 ]
    then
        if "${header[@]}" --begin 2 0 --title '| Delete Resources |' --no-items --defaultno --keep-window --yesno "Please confirm to delete all the downloaded and patched apps." -1 -1
        then
            ls -1 *.apk | grep -v integrations | xargs rm > /dev/null 2>&1
            "${header[@]}" --msgbox "All Apps are successfully deleted !!" 12 40
        fi
    elif [ "$extrasPrompt" -eq 3 ]
    then
        if "${header[@]}" --begin 2 0 --title '| Delete Resources |' --no-items --defaultno --keep-window --yesno "Please confirm to delete the options file for $sourceName patches." -1 -1
        then
            rm "$storagePath/Revancify/$source-options.toml" > /dev/null 2>&1
            "${header[@]}" --msgbox "Options file successfully deleted for current source !!" 12 40
        fi
    elif [ "$extrasPrompt" -eq 4 ]
    then
        if "${header[@]}" --begin 2 0 --title '| Force Update Check |' --no-items --defaultno --yes-label "true" --no-label "false" --keep-window --yesno "Set the value for revancify to force check update for resources at startup?\nCurrent Value: $(jq -r '.forceUpdateCheckStatus' settings.json)" -1 -1
        then
            tmp=$(mktemp) && jq '.forceUpdateCheckStatus |= true' settings.json > "$tmp" && mv "$tmp" settings.json
        else
            tmp=$(mktemp) && jq '.forceUpdateCheckStatus |= false' settings.json > "$tmp" && mv "$tmp" settings.json
        fi
    elif [ "$extrasPrompt" -eq 5 ]
    then
        switchTheme
    elif [ "$extrasPrompt" -eq 6 ]
    then
        if [ "$variant" = "root" ]
        then
            rootUninstall
        elif [ "$variant" = "nonRoot" ]
        then
            downloadMicrog
        fi
    fi
    extrasMenu
}

buildCustomApk()
{
    checkResources
    checkJson
    fetchCustomApk
    selectPatches
    checkMicrogPatch
    patchApp
    ${variant}Install
}

buildApk()
{
    checkResources
    getAppVer
    checkMicrogPatch
    patchApp
    ${variant}Install
}

checkSU
setup
userAgent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36"
mainmenu()
{
    mainmenu=$("${header[@]}" --begin 2 0 --title '| Main Menu |' --keep-window --ok-label "Select" --cancel-label "Exit" --menu "Use arrow keys to navigate\nSource: $sourceName" -1 -1 15 1 "Patch App" 2 "Select Patches" 3 "Change Source" 4 "Update Resources" 5 "Edit Patch Options" 6 "Extras Menu" 2>&1> /dev/tty)
    exitstatus=$?
    if [ $exitstatus -ne 0 ]
    then
        terminate 0
    fi
    if [ "$mainmenu" -eq 1 ]
    then
        selectApp extra
        if [ "$appType" == "normal" ]
        then
            buildApk
        else
            buildCustomApk
        fi
    elif [ "$mainmenu" -eq 2 ]
    then
        selectApp normal
        selectPatches
    elif [ "$mainmenu" -eq 3 ]
    then
        changeSource
    elif [ "$mainmenu" -eq 4 ]
    then
        getResources
    elif [ "$mainmenu" -eq 5 ]
    then
        editPatchOptions
    elif [ "$mainmenu" -eq 6 ]
    then
        extrasMenu
    fi
}

if [ "$(jq -r '.forceUpdateCheckStatus' settings.json)" == "true" ]
then
    resourcesVars
    getResources
fi

mainmenu