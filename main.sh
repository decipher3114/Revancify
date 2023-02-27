#!/usr/bin/bash
terminate()
{
    pkill -9 java > /dev/null 2>&1
    pkill -9 python > /dev/null 2>&1
    clear
    exit ${1:-1}
}
trap terminate SIGTERM SIGINT SIGABRT


setup()
{
    arch=$(getprop ro.product.cpu.abi)
    mkdir -p /storage/emulated/0/Revancify
    path=$(find "$HOME" -type d -name "Revancify")
    header=(dialog --backtitle "Revancify | [Arch: $arch, SU: $variant]" --no-shadow)

    if ! (ls ".source" > /dev/null 2>&1) || [ "$(cat .source)" == "" ]
    then
        allSources=("revanced" "[Revanced]" on "inotia00" "[Revanced Extended]" off)
        selectedSource=$("${header[@]}" --begin 2 0 --title '| Source Selection Menu |' --keep-window --no-cancel --ok-label "Done" --radiolist "Use arrow keys to navigate; Press Spacebar to select option" -1 -1 15 "${allSources[@]}" 2>&1> /dev/tty)
        echo "$selectedSource" > .source
    fi

    if ! ls ".theme" > /dev/null 2>&1
    then
        echo "Dark" > ".theme"
    fi

    source=$(cat ".source")
    theme=$(cat .theme)
    export DIALOGRC=.dialogrc$theme

    source <(jq -r --arg source "$source" '.[$source].sources | to_entries[] | .key+"Source="+.value.org' "$path"/sources.json)
    sourceName=$(jq -r --arg source "$source" '.[$source].projectName' "$path"/sources.json)

    if ls "$patchesSource-patches.json" > /dev/null 2>&1
    then
        python3 "$path"/python-utils/sync-patches.py "$source" > /dev/null 2>&1
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
        if [ "$(python3 "$path"/python-utils/sync-patches.py "$source" online)" == "error" ]
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

    if [ "$(python3 "$path"/python-utils/sync-patches.py "$source" online)" == "error" ]
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
        echo "$selectedSource" > ".source"
        source=$(cat ".source")
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
        if [ "$(python3 "$path"/python-utils/sync-patches.py "$source" online)" == "error" ]
        then
            "${header[@]}" --msgbox "Patches are not successfully synced.\nRevancify may crash." 12 40
            mainmenu
            return 0
        fi
    fi
}

selectApp()
{
    if [ "$1" == "extra" ]
    then
        customOpt=(1 "From Apk File" "Choose apk from storage.")
        incrementVal=2
    elif [ "$1" == "normal" ]
    then
        unset customOpt
        incrementVal=1
    fi
    checkJson
    previousAppName="$appName"
    readarray -t availableApps < <(jq -r --argjson incrementVal "$incrementVal" 'to_entries | map(select(.value.appName != null)) | to_entries | map(.key + $incrementVal, .value.value.appName, .value.key)[]' "$patchesSource-patches.json")
    appIndex=$("${header[@]}" --begin 2 0 --title '| App Selection Menu |' --item-help --keep-window --ok-label "Select" --cancel-label "Back" --menu "Use arrow keys to navigate\nSource: $sourceName" $(($(tput lines) - 3)) -1 15 "${customOpt[@]}" "${availableApps[@]}" 2>&1> /dev/tty)
    exitstatus=$?
    if [ $exitstatus -eq 0 ]
    then
        if [ "$1" == "extra" ] && [ "$appIndex" -eq 1 ]
        then
            appType=custom
        else
            if [ "$1" == "extra" ]
            then
                appName="${availableApps[$(($(( $(( "$appIndex" - 1 )) * 3 )) - 2 ))]}"
                pkgName="${availableApps[$(($(( $(( "$appIndex" - 1 )) * 3 )) - 1 ))]}"
            elif [ "$1" == "normal" ]
            then
                appName="${availableApps[$(($(( "$appIndex" * 3 )) - 2 ))]}"
                pkgName="${availableApps[$(($(( "$appIndex" * 3 )) - 1 ))]}"
            fi
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
    toogleName="Exclude All"
    for i in $(jq -r --arg pkgName "$pkgName" '.[$pkgName].patches[].status' "$patchesSource-patches.json")
    do
        if [ "$i" == "off" ]
        then
            toogleName="Include All"
            break
        fi
    done
    readarray -t patchesInfo < <(jq -r --arg pkgName "$pkgName" '.[$pkgName].patches[] | "\(.name)\n\(.status)\n\(.description)"' "$patchesSource-patches.json")
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
        tmp=$(mktemp)
        jq --arg pkgName "$pkgName" '.[$pkgName].patches[].status = "off" | (.[$pkgName].patches[] | select(IN(.name; $ARGS.positional[])) | .status ) |= "on"' --args "${choices[@]}" < "$patchesSource-patches.json" > "$tmp" && mv "$tmp" "$patchesSource-patches.json"
        return 0
    elif [ $selectPatchStatus -eq 1 ]
    then
        if [ "$toogleName" == "Include All" ]
        then
            tmp=$(mktemp)
            jq --arg pkgName "$pkgName" '.[$pkgName].patches[].status = "on"' "$patchesSource-patches.json" > "$tmp" && mv "$tmp" "$patchesSource-patches.json"
            selectPatches
        elif [ "$toogleName" == "Exclude All" ]
        then
            tmp=$(mktemp)
            jq --arg pkgName "$pkgName" '.[$pkgName].patches[].status = "off"' "$patchesSource-patches.json" > "$tmp" && mv "$tmp" "$patchesSource-patches.json"
            selectPatches
        fi
    elif [ $selectPatchStatus -eq 2 ]
    then
        tmp=$(mktemp)
        jq --arg pkgName "$pkgName" '.[$pkgName].patches[].status = "off" | (.[$pkgName].patches[] | select(.excluded == false) | .status ) |= "on"' < "$patchesSource-patches.json" > "$tmp" && mv "$tmp" "$patchesSource-patches.json"
        selectPatches
    fi
}

patchoptions()
{
    checkResources
    "${header[@]}" --infobox "Please Wait !!\nGenerating options file for $source patches..." 12 40
    java -jar "$cliSource"-cli-*.jar -b "$patchesSource"-patches-*.jar -m "$integrationsSource"-integrations-*.apk -c -a noinput.apk -o nooutput.apk --options "$source.toml" > /dev/null 2>&1
    tput cnorm
    tmp=$(mktemp)
    "${header[@]}" --begin 2 0 --ok-label "Save" --cancel-label "Exit" --keep-window --title '| Options File Editor |' --editbox "$source.toml" -1 -1 2> "$tmp" && mv "$tmp" "$source.toml"
    tput civis
    mainmenu
}

switchTheme()
{
    allThemes=(Default off Dark off Light off)
    for i in "${!allThemes[@]}"
    do
        if [ "${allThemes[$i]}" == "$(cat .theme)" ]
        then
            allThemes["$(( "$i" + 1 ))"]="on"
        fi
    done
    selectedTheme=$("${header[@]}" --begin 2 0 --title '| Theme Selection Menu |' --no-items --keep-window --no-cancel --ok-label "Done" --radiolist "Use arrow keys to navigate; Press Spacebar to select option" -1 -1 15 "${allThemes[@]}" 2>&1> /dev/tty)
    echo "$selectedTheme" > .theme
    export DIALOGRC=.dialogrc$selectedTheme
    mainmenu
}

rootInstall()
{
    "${header[@]}" --infobox "Installing $appName by Mounting..." 12 40
    pkgName=$pkgName appName=$appName appVer=$appVer su -mm -c 'grep $pkgName /proc/mounts | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -vl && cp ./"$appName"-Revanced-"$appVer".apk /data/local/tmp/revanced.delete && mv /data/local/tmp/revanced.delete /data/adb/revanced/"$pkgName".apk && stockApp=$(pm path $pkgName | sed -n "/base/s/package://p") && revancedApp=/data/adb/revanced/"$pkgName".apk && chmod -v 644 "$revancedApp" && chown -v system:system "$revancedApp" && chcon -v u:object_r:apk_data_file:s0 "$revancedApp" && mount -vo bind "$revancedApp" "$stockApp" && am force-stop $pkgName' > /storage/emulated/0/Revancify/mountlog.txt 2>&1
    if ! su -c "grep -q $pkgName /proc/mounts"
    then
        "${header[@]}" --infobox "Installation Failed !!\nLogs saved to Revancify folder. Share the Mountlog to developer." 12 40
        sleep 1
        mainmenu
    fi
    echo -e "#!/system/bin/sh\nwhile [ \"\$(getprop sys.boot_completed | tr -d '\\\r')\" != \"1\" ]; do sleep 1; done\n\nif [ \$(dumpsys package $pkgName | grep versionName | cut -d '=' -f 2 | sed -n '1p') =  \"$selectedVer\" ]\nthen\n\tbase_path=\"/data/adb/revanced/$pkgName.apk\"\n\tstock_path=\$( pm path $pkgName | sed -n '/base/s/package://p' )\n\n\tchcon u:object_r:apk_data_file:s0 \$base_path\n\tmount -o bind \$base_path \$stock_path\nfi" > "mount_revanced_$pkgName.sh"
    su -c "mv mount_revanced_$pkgName.sh /data/adb/service.d && chmod +x /data/adb/service.d/mount_revanced_$pkgName.sh"
    sleep 1
    su -c "settings list secure | sed -n -e 's/\/.*//' -e 's/default_input_method=//p' | xargs pidof | xargs kill -9 && pm resolve-activity --brief $pkgName | tail -n 1 | xargs am start -n && pidof com.termux | xargs kill -9" > /dev/null 2>&1
}

rootUninstall()
{
    selectApp normal
    if ! su -c "grep -q $pkgName /proc/mounts"
    then
        "${header[@]}" --msgbox "$appName Revanced is not installed(mounted) in your device." 12 40
        mainmenu
    fi
    "${header[@]}" --infobox "Uninstalling $appName Revanced by Unmounting..." 12 40
    pkgName=$pkgName su -mm -c 'grep $pkgName /proc/mounts | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l &&\
    stockApp=$(pm path $pkgName | sed -n "/base/s/package://p") && am force-stop $pkgName && rm /data/adb/service.d/mount_revanced_$pkgName.sh && rm -rf /data/adb/revanced/$pkgName.apk' > /dev/null 2>&1
    sleep 0.5s
    if ! su -c "grep -q $pkgName /proc/mounts"
    then
        "${header[@]}" --infobox "Uninstall Successful !!" 12 40
        sleep 1
        mainmenu
    else
        "${header[@]}" --infobox "Uninstall failed !! Something went wrong." 12 40
        sleep 1
        mainmenu
    fi
}

nonRootInstall()
{
    "${header[@]}" --infobox "Copying $appName-Revanced $selectedVer to Internal Storage..." 12 40
    sleep 0.5
    cp "$appName-Revanced"* /storage/emulated/0/Revancify/ > /dev/null 2>&1
    termux-open "/storage/emulated/0/Revancify/$appName-Revanced-$appVer.apk"
    mainmenu
}

checkResources()
{
    if ls ".${source}latest" > /dev/null 2>&1
    then
        source ./".${source}latest"
    else
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
arg="$2"
checkSU()
{
    if su -c exit > /dev/null 2>&1
    then
        if [ "$flag" = '-n' ]
        then
            variant=nonRoot
        else
            variant=root
            su -c "mkdir -p /data/adb/revanced"
        fi
    else
        variant=nonRoot
    fi
}

getAppVer()
{
    checkResources
    linkVar=$(jq -r --arg pkgName "$pkgName" '.[$pkgName].link' "$patchesSource-patches.json")
    developer=$(cut -d '/' -f 3 <<< "$linkVar")
    remoteAppName=$(cut -d '/' -f 4 <<< "$linkVar")
    if [ "$variant" = "root" ]
    then
        if ! su -c "pm path $pkgName" > /dev/null 2>&1
        then
            if "${header[@]}" --begin 2 0 --title '| Apk Not Installed |' --no-items --defaultno --keep-window --yes-label "Non-Root" --no-label "Play Store" --yesno "$appName is not installed on your rooted device.\nYou have to install it from Play Store or you can proceed with Non-Root installation?\n\nWhich method do you want to proceed with?" -1 -1
            then
                variant="nonRoot"
                getAppVer
                return 0
            else
                termux-open "https://play.google.com/store/apps/details?id=$pkgName"
                mainmenu
            fi
        fi
        selectedVer=$(su -c dumpsys package "$pkgName" | grep versionName | cut -d '=' -f 2 | sed -n '1p')
        appVer="$(sed 's/\./-/g;s/ /-/g' <<< "$selectedVer")"
    elif [ "$variant" = "nonRoot" ]
    then
        if [ -z "$appVerList" ]
        then
            internet
            "${header[@]}" --infobox "Please Wait !!\nScraping versions list for $appName from apkmirror.com..." 12 40
            readarray -t appVerList < <(python3 "$path"/python-utils/fetch-versions.py "$remoteAppName" "$pkgName" "$source")
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
    currentPath=${currentPath:-/storage/emulated/0}
    dirList=()
    files=()
    if [ "$currentPath" != "/storage/emulated/0" ]
    then
        dirUp=(1 ".." "GO BACK TO PREVIOUS DIRECTORY")
        num=1
    else
        unset dirUp
        num=0
    fi
    while read -r item
    do
        if [ -d "$currentPath/$item" ]
        then
            files+=("$item")
            [ ${#item} -gt $(( "$(tput cols)" - 24 )) ] && item=${item:0:$(( "$(tput cols)" - 34 ))}...${item: -10}
            num=$(( "$num" + 1 ))
            dirList+=("$num")
            dirList+=("$item")
            dirList+=("DIRECTORY")
        elif [ "${item##*.}" == "apk" ]
        then
            files+=("$item")
            [ ${#item} -gt $(( "$(tput cols)" - 24 )) ] && item=${item:0:$(( "$(tput cols)" - 34 ))}...${item: -10}
            num=$(( "$num" + 1 ))
            dirList+=("$num")
            dirList+=("$item")
            dirList+=("APK FILE")
        fi
    done < <(ls -1 --group-directories-first "$currentPath")
    pathIndex=$("${header[@]}" --begin 2 0 --title '| Apk File Selection Menu |' --item-help --ok-label "Select" --menu "Use arrow keys to navigate\nCurrent Path: $currentPath" $(($(tput lines) - 3)) -1 20 "${dirUp[@]}" "${dirList[@]}" 2>&1> /dev/tty)
    exitstatus=$?
    if [ $exitstatus -eq 1 ]
    then
        mainmenu
        return 0
    fi
    if [ "$currentPath" != "/storage/emulated/0" ] && [ "$pathIndex" -eq 1 ]
    then
        newPath=".."
    elif [ "$currentPath" != "/storage/emulated/0" ] && [ "$pathIndex" -ne 1 ]
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
    if [ "$(jq --arg pkgName "$pkgName" '.[$pkgName].patches' "$patchesSource-patches.json")" == "null" ]
    then
        "${header[@]}" --msgbox "The app you selected is not supported for patching by $sourceName patches !!" 12 40
        mainmenu
    fi
    appName=$(grep "application-label:" <<< "$aaptData" | sed -e 's/application-label://' -e 's/'\''//g')
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
                termux-open "https://play.google.com/store/apps/details?id=$pkgName"
                mainmenu
            fi
        fi
    fi
    cp "$newPath" "$appName-$appVer.apk"
    if [ "$(jq -r --arg selectedVer "$selectedVer" --arg pkgName "$pkgName" '.[$pkgName].versions | if length == 0 then "null" else empty end' "$patchesSource-patches.json")" == "null" ]
    then
        if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --keep-window --yesno "The following data is extracted from the apk file you provided.\nApp Name    : $appName\nPackage Name: $pkgName\nVersion     : $selectedVer\nDo you want to proceed with this app?" -1 -1
        then
            mainmenu
            return 0
        fi
    else
        if [ "$(jq -r --arg selectedVer "$selectedVer" --arg pkgName "$pkgName" '.[$pkgName].versions | if index($selectedVer) != null then 0 else 1 end' "$patchesSource-patches.json")" -eq 0 ]
        then
            if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --keep-window --yesno "The following data is extracted from the apk file you provided.\nApp Name    : $appName\nPackage Name: $pkgName\nVersion     : $selectedVer\nDo you want to proceed with this app?" -1 -1
            then
                mainmenu
                return 0
            fi
        else
            if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --keep-window --yesno "The following data is extracted from the apk file you provided.\nApp Name    : $appName\nPackage Name: $pkgName\nVersion     : $selectedVer\n\nThe version $selectedVer is not supported. Supported versions are: \n$(jq -r --arg selectedVer "$selectedVer" --arg pkgName "$pkgName" '.[$pkgName].versions | length as $array_length | to_entries[] | if .key != ($array_length - 1) then .value + "," else .value end' "$patchesSource-patches.json")\n\nDo you still want to proceed with version $selectedVer for $appName?" -1 -1
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
    if [ "$(jq -r --arg selectedVer "$selectedVer" --arg pkgName "$pkgName" '.[$pkgName].versions | if length == 0 then "null" else empty end' "$patchesSource-patches.json")" == "null" ]
    then
        if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --keep-window --yesno "Do you want to proceed with version $selectedVer for $appName?" -1 -1
        then
            mainmenu
            return 0
        fi
    else
        if [ "$(jq -r --arg selectedVer "$selectedVer" --arg pkgName "$pkgName" '.[$pkgName].versions | if index($selectedVer) != null then 0 else 1 end' "$patchesSource-patches.json")" -eq 0 ]
        then
            if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --keep-window --yesno "Do you want to proceed with version $selectedVer for $appName?" -1 -1
            then
                mainmenu
                return 0
            fi
        else
            if ! "${header[@]}" --begin 2 0 --title '| Proceed |' --no-items --keep-window --yesno "The version $selectedVer is not supported. Supported versions are: \n$(jq -r --arg selectedVer "$selectedVer" --arg pkgName "$pkgName" '.[$pkgName].versions | length as $array_length | to_entries[] | if .key != ($array_length - 1) then .value + "," else .value end' "$patchesSource-patches.json")\n\nDo you still want to proceed with version $selectedVer for $appName?" -1 -1
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
    appUrl=$( ( python3 "$path"/python-utils/fetch-link.py "$developer" "$remoteAppName" "$appVer" "$arch" 2>&3 | "${header[@]}" --begin 2 0 --gauge "App    : $appName\nVersion: $selectedVer\n\nScraping Download Link..." -1 -1 0 >&2 ) 3>&1 )
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
            "${header[@]}" --msgbox "No apk found on apkmirror.com for version $selectedVer !!\nTry selecting other version" 12 40
            getAppVer
        else
            "${header[@]}" --msgbox "No apk found on apkmirror.com for version $selectedVer !!\nPlease upgrade or degrade the version to patch it.\n\nSuggestion: Install the app as non root. You can run 'revancify -n' to run as non root." 15 40
            mainmenu
        fi
        return 0
    elif [ "$appUrl" = "noversion" ]
    then
        "${header[@]}" --msgbox "This version is not uploaded on apkmirror.com!!\nPlease upgrade or degrade the version to patch it.\n\nSuggestion: Install the app as non root. You can run 'revancify -n' to run as non root." 15 40
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
        ls VancedMicroG* > /dev/null 2>&1 && mv VancedMicroG* "/storage/emulated/0/Revancify/" && termux-open "/storage/emulated/0/Revancify/VancedMicroG-${microgheaders[2]}.apk"
    fi
    mainmenu
}

patchApp()
{
    checkJson
    readarray -t patchesArg < <(jq -r --arg pkgName "$pkgName" '.[$pkgName].patches[] | if .status == "on" then ( if .excluded == true then "-i " + .name else empty end ) else "-e " + .name end' "$patchesSource-patches.json")
    java -jar "$cliSource"-cli-*.jar -b "$patchesSource"-patches-*.jar -m "$integrationsSource"-integrations-*.apk -c -a "$appName-$appVer.apk" -o "$appName-Revanced-$appVer.apk" ${patchesArg[@]} --keystore "$path"/revanced.keystore --custom-aapt2-binary "$path/binaries/aapt2_$arch" --options "$source.toml" --experimental 2>&1 | tee /storage/emulated/0/Revancify/patchlog.txt | "${header[@]}" --begin 2 0 --ok-label "Continue" --cursor-off-label --programbox "Patching $appName-$appVer.apk" -1 -1
    echo -e "\n\n\nVariant: $variant\nArch: $arch\nApp: $appName-$appVer.apk\nCLI: $(ls "$cliSource"-cli-*.jar)\nPatches: $(ls "$patchesSource"-patches-*.jar)\nIntegrations: $(ls "$integrationsSource"-integrations-*.apk)\nPatches argument: ${patchesArg[*]}" >> /storage/emulated/0/Revancify/patchlog.txt
    tput civis
    sleep 1
    if ! grep -q "Finished" /storage/emulated/0/Revancify/patchlog.txt
    then
        "${header[@]}" --msgbox "Oops, Patching failed !!\nLog file saved to Revancify folder. Share the Patchlog to developer." 12 40
        mainmenu
    fi
}

checkMicrogPatch()
{
    microgStatus=$(jq -r --arg pkgName "$pkgName" '.[$pkgName].patches[] | select(.name |  test(".*microg.*")).status' "$patchesSource-patches.json")
    if [ "$microgStatus" = "on" ] && [ "$variant" = "root" ]
    then
        if "${header[@]}" --begin 2 0 --title '| MicroG warning |' --no-items --defaultno --keep-window --yes-label "Continue" --no-label "Exclude" --yesno "You have a rooted device and you have included microg-support patch. This may result in $appName app crash.\n\n\nDo you want to exclude it or continue?" -1 -1
        then
            return 0
        else
            tmp=$(mktemp)
            jq -r --arg pkgName "$pkgName" '(.[$pkgName].patches[] | select(.name | test(".*microg.*")) | .status) |= "off"' "$patchesSource-patches.json" > "$tmp" && mv "$tmp" "$patchesSource-patches.json"
            return 0
        fi
    elif [ "$microgStatus" = "off" ] && [ "$variant" = "nonRoot" ]
    then
        if "${header[@]}" --begin 2 0 --title '| MicroG warning |' --no-items --defaultno --keep-window --yes-label "Continue" --no-label "Include" --yesno "You have a non-rooted device and you have not included microg-support patch. This may result in $appName app crash.\n\n\nDo you want to include it or continue?" -1 -1
        then
            return 0
        else
            tmp=$(mktemp)
            jq -r --arg pkgName "$pkgName" '(.[$pkgName].patches[] | select(.name | test(".*microg.*")) | .status) |= "on"' "$patchesSource-patches.json" > "$tmp" && mv "$tmp" "$patchesSource-patches.json"
            return 0
        fi
    fi
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
    [ "$variant" = "root" ] && misc=(6 "Uninstall Revanced app") || misc=(6 "Download Vanced Microg")
    mainmenu=$("${header[@]}" --begin 2 0 --title '| Main Menu |' --keep-window --ok-label "Select" --cancel-label "Exit" --menu "Use arrow keys to navigate\nSource: $sourceName" -1 -1 15 1 "Patch App" 2 "Select Patches" 3 "Change Source" 4 "Update Resources" 5 "Edit Patch Options" "${misc[@]}" 7 "Switch Theme" 2>&1> /dev/tty)
    exitstatus=$?
    if [ $exitstatus -eq 0 ]
    then
        if [ "$mainmenu" -eq "1" ]
        then
            selectApp extra
            if [ "$appType" == "normal" ]
            then
                buildApk
            else
                buildCustomApk
            fi
        elif [ "$mainmenu" -eq "2" ]
        then
            selectApp normal
            selectPatches
        elif [ "$mainmenu" -eq "3" ]
        then
            changeSource
        elif [ "$mainmenu" -eq "4" ]
        then
            getResources
        elif [ "$mainmenu" -eq "5" ]
        then
            patchoptions
        elif [ "$mainmenu" -eq "6" ]
        then
            if [ "$variant" = "root" ]
            then
                rootUninstall
            elif [ "$variant" = "nonRoot" ]
            then
                downloadMicrog
            fi
        elif [ "$mainmenu" -eq "7" ]
        then
            switchTheme
        fi
    elif [ $exitstatus -ne 0 ]
    then
        terminate 0
    fi
}

if [ "$flag" = '-f' ]
then
    resourcesVars
    getResources
elif [ "$flag" = '-d' ]
then
    if [ "$arg" == "resources" ]
    then
        rm "$cliSource"-cli-*.jar > /dev/null 2>&1
        rm "$patchesSource"-patches-*.jar > /dev/null 2>&1
        rm "$patchesSource"-patches-*.json > /dev/null 2>&1
        rm "$integrationsSource"-integrations-*.apk > /dev/null 2>&1
    elif [ "$arg" == "apps" ]
    then
        ls -1 *.apk | grep -v integrations | xargs rm > /dev/null 2>&1
    elif [ "$arg" == "toml" ]
    then
        rm "$source.toml" > /dev/null 2>&1
    fi
fi
mainmenu