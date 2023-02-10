#!/usr/bin/bash

terminatescript()
{
    clear && echo "Script terminated" ; rm -rf -- *cache; tput cnorm ; cd ~ || : ; exit
}
trap terminatescript SIGINT

setup()
{
    arch=$(getprop ro.product.cpu.abi)
    mkdir -p /storage/emulated/0/Revancify

    if ! ls .source > /dev/null 2>&1
    then
        echo "revanced" > .source
    fi
    source=$(cat .source)

    readarray -t resources < <(jq -r --arg source "$source" '.[$source][]' sources.json)
    cliSource=$(cut -d '/' -f 1 <<< "${resources[0]}")
    patchSource=$(cut -d '/' -f 1 <<< "${resources[1]}")
    integrationsSource=$(cut -d '/' -f 1 <<< "${resources[2]}")

    if ls "$patchSource-patches.json" > /dev/null 2>&1
    then
        python3 python-utils/sync-patches.py "$source" > /dev/null 2>&1
    fi
    patchselectionheight=$(($(tput lines) - 3))
}

internet()
{
    if ! ping -c 1 google.com > /dev/null 2>&1
    then
        "${header[@]}" --msgbox "Oops! No Internet Connection available.\n\nConnect to Internet and try again later" 12 40
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


    readarray -t sourceLatest < ".${source}latest"

    cliLatest="${sourceLatest[0]}"
    cliUrl="${sourceLatest[1]}"
    cliSize="$(numfmt --to=iec --format="%0.1f" "${sourceLatest[2]}")"
    patchesLatest="${sourceLatest[3]}"
    jsonUrl="${sourceLatest[4]}"
    patchesUrl="${sourceLatest[6]}"
    patchesSize="$(numfmt --to=iec --format="%0.1f" "${sourceLatest[7]}")"
    integrationsLatest="${sourceLatest[8]}"
    integrationsUrl="${sourceLatest[9]}"
    integrationsSize="$(numfmt --to=iec --format="%0.1f" "${sourceLatest[10]}")"

    ls "$cliSource"-cli-*.jar > /dev/null 2>&1 && cli_available=$(basename "$cliSource"-cli-*.jar .jar | cut -d '-' -f 3) || cli_available="Not found"
    ls "$patchSource"-patches-*.jar > /dev/null 2>&1 && patches_available=$(basename "$patchSource"-patches-*.jar .jar | cut -d '-' -f 3) || patches_available="Not found"
    ls "$patchSource"-patches-*.json > /dev/null 2>&1 && json_available=$(basename "$patchSource"-patches-*.json .json | cut -d '-' -f 3) || json_available="Not found"
    ls "$integrationsSource"-integrations-*.apk > /dev/null 2>&1 && integrations_available=$(basename "$integrationsSource"-integrations-*.apk .apk | cut -d '-' -f 3) || integrations_available="Not found"

    cliAvailableSize=$( ls "$cliSource"-cli-*.jar > /dev/null 2>&1 && du -b "$cliSource"-cli-*.jar | cut -d $'\t' -f 1 || echo "None" )
    patchesAvailableSize=$( ls "$patchSource"-patches-*.jar > /dev/null 2>&1 && du -b "$patchSource"-patches-*.jar | cut -d $'\t' -f 1 || echo "None" )
    integrationsAvailableSize=$( ls "$integrationsSource"-integrations-*.apk > /dev/null 2>&1 && du -b "$integrationsSource"-integrations-*.apk | cut -d $'\t' -f 1 || echo "None" )
}

resourceMenu()
{
    resourcesVars
    readarray -t resourceTable < <(echo -e "ResourceLatest_Downloaded\nCLI_${cliLatest}_${cli_available}\nPatches_${patchesLatest}_${patches_available}\nIntegrations_${integrationsLatest}_${integrations_available}" | column -t -s '_')
    "${header[@]}" --begin 2 0 --title '| Resources List |' --no-items --defaultno --yes-label "Fetch" --no-label "Cancel" --help-button --help-label "Delete All" --keep-window --no-shadow --yesno "Current Source: $source\n\n${resourceTable[0]}\n${resourceTable[1]}\n${resourceTable[2]}\n${resourceTable[3]}\n\nDo you want to fetch latest resources?" -1 -1
    resexitstatus=$?
    if [ $resexitstatus -eq 0 ]
    then
        if [ "$patchesLatest" = "$patches_available" ] && [ "$patchesLatest" = "$json_available" ] && [ "$cliLatest" = "$cli_available" ] && [ "$integrationsLatest" = "$integrations_available" ] && [ "${sourceLatest[2]}" = "$cliAvailableSize" ] && [ "${sourceLatest[7]}" = "$patchesAvailableSize" ] && [ "${sourceLatest[10]}" = "$integrationsAvailableSize" ]
        then
            python3 python-utils/sync-patches.py "$source" online > /dev/null 2>&1
            "${header[@]}" --msgbox "Resources are already downloaded !!\n\nPatches are successfully synced." 12 40
        else
            getResources
        fi
    elif [ $resexitstatus -eq 2 ]
    then
        if (! ls "$cliSource"-cli-*.jar > /dev/null 2>&1) && (! ls "$patchSource"-patches-*.jar > /dev/null 2>&1) && (! ls "$patchSource"-patches-*.json > /dev/null 2>&1) && (! ls "$integrationsSource"-integrations-*.apk > /dev/null 2>&1)
        then
            "${header[@]}" --msgbox "No resources exist !!\n\nDownload the resources first." 12 40
            mainmenu
        fi
        if "${header[@]}" --begin 2 0 --title '| Clean resources |' --no-items --defaultno --keep-window --no-shadow --yesno "Do you want to delete the resources for the source $source?\nThis will delete the following files:\n$(ls "$cliSource"-cli-*.jar && ls "$patchSource"-patches-*.jar && ls "$patchSource"-patches-*.json && ls "$integrationsSource"-integrations-*.apk)" -1 -1
        then
            ls "$cliSource"-cli-*.jar > /dev/null 2>&1 && rm "$cliSource"-cli-*.jar
            ls "$patchSource"-patches-*.jar > /dev/null 2>&1 && rm "$patchSource"-patches-*.jar
            ls "$patchSource"-patches-*.json > /dev/null 2>&1 && rm "$patchSource"-patches-*.json
            ls "$integrationsSource"-integrations-*.apk > /dev/null 2>&1 && rm "$integrationsSource"-integrations-*.apk
            mainmenu
        fi
    fi
    mainmenu
}

getResources()
{
    [ "$patchesLatest" != "$patches_available" ] && rm "$patchSource"-patches-*.jar > /dev/null 2>&1 && rm "$patchSource"-patches-*.json > /dev/null 2>&1
    [ "$cliLatest" != "$cli_available" ] && rm "$cliSource"-cli-*.jar > /dev/null 2>&1
    [ "$integrationsLatest" != "$integrations_available" ] && rm "$integrationsSource"-integrations-*.apk > /dev/null 2>&1
    [ "${sourceLatest[2]}" != "$cliAvailableSize" ] &&\
    wget -q -c "$cliUrl" -O "$cliSource"-cli-"$cliLatest".jar --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "Resource: CLI\nVersion : $cliLatest\nSize    : $cliSize\n\nDownloading..." -1 -1 && tput civis

    [ "${sourceLatest[2]}" != "$( ls "$cliSource"-cli-*.jar > /dev/null 2>&1 && du -b "$cliSource"-cli-*.jar | cut -d $'\t' -f 1 || echo "None" )" ] && "${header[@]}" --msgbox "Oops! Unable to download completely.\n\nRetry or change your Network." 12 40 && mainmenu && return 0

    [ "${sourceLatest[7]}" != "$patchesAvailableSize" ] &&\
    wget -q -c "$patchesUrl" -O "$patchSource"-patches-"$patchesLatest".jar --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "Resource: Patches\nVersion : $patchesLatest\nSize    : $patchesSize\n\nDownloading..." -1 -1 && tput civis

    wget -q -c "$jsonUrl" -O "$patchSource"-patches-"$patchesLatest".json --user-agent="$userAgent"

    [ "${sourceLatest[7]}" != "$( ls "$patchSource"-patches-*.jar > /dev/null 2>&1 && du -b "$patchSource"-patches-*.jar | cut -d $'\t' -f 1 || echo "None" )" ] &&  "${header[@]}" --msgbox "Oops! Unable to download completely.\n\nRetry or change your Network." 12 40 && mainmenu && return 0

    [ "${sourceLatest[10]}" != "$integrationsAvailableSize" ] &&\
    wget -q -c "$integrationsUrl" -O "$integrationsSource"-integrations-"$integrationsLatest".apk --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "Resource: Integrations\nVersion : $integrationsLatest\nSize    : $integrationsSize\n\nDownloading..." -1 -1 && tput civis

    [ "${sourceLatest[10]}" != "$( ls "$integrationsSource"-integrations-*.apk > /dev/null 2>&1 && du -b "$integrationsSource"-integrations-*.apk | cut -d $'\t' -f 1 || echo "None" )" ] && "${header[@]}" --msgbox "Oops! File not downloaded.\n\nRetry or change your Network." 12 40 && mainmenu && return 0

    python3 python-utils/sync-patches.py "$source" online > /dev/null 2>&1
}

fetchResources()
{
    "${header[@]}" --infobox "Please Wait !!" 12 40
    : > ".${source}latest"
    for resource in "${resources[@]}"
    do
        curl -s --fail-early --connect-timeout 2 --max-time 5  "https://api.github.com/repos/${resource}/releases/latest" | jq -r '.tag_name, (.assets[] | .browser_download_url, .size)' >> ".${source}latest"
    done
}

changeSource()
{
    internet
    source=$(cat .source)
    readarray -t allSources < <(for sourceName in $(jq -r 'keys_unsorted[]' sources.json)
        do
            echo "$sourceName"
            if [ "$sourceName" == "$source" ]
            then
                echo "on"
            else
                echo "off"
            fi
        done)
    selectedSource=$("${header[@]}" --begin 2 0 --title '| Source Selection Menu |' --keep-window --no-items --no-shadow --no-cancel --ok-label "Done" --radiolist "Use arrow keys to navigate; Press Spacebar to select option" -1 -1 15 "${allSources[@]}" 2>&1> /dev/tty)
    if [ "$source" != "$selectedSource" ]
    then
        tmp=$(mktemp)
        echo "$selectedSource" > .source
        source=$(cat .source)
        readarray -t resources < <(jq -r --arg source "$source" '.[$source][]' sources.json)
        cliSource=$(cut -d '/' -f 1 <<< "${resources[0]}")
        patchSource=$(cut -d '/' -f 1 <<< "${resources[1]}")
        integrationsSource=$(cut -d '/' -f 1 <<< "${resources[2]}")
        checkResources
    fi
    mainmenu
}

checkJson()
{
    if ! ls "$patchSource"-patches-*.json > /dev/null 2>&1
    then
        "${header[@]}" --msgbox "No Json file found !!\nPlease download resources." 12 40
        resourceMenu
        return 0
    fi
    if ! ls "$patchSource"-patches.json > /dev/null 2>&1
    then
        internet
        python3 python-utils/sync-patches.py "$source" online
    fi
}

selectApp()
{
    checkJson
    readarray -t availableApps < <(jq -r 'to_entries[] | if .value.appName != null then .key, .value.appName else empty end' "$patchSource-patches.json")
    pkgName=$("${header[@]}" --begin 2 0 --title '| App Selection Menu |' --no-items --item-help --keep-window --no-shadow --ok-label "Select" --cancel-label "Back" --menu "Use arrow keys to navigate" $patchselectionheight -1 15 "${availableApps[@]}" 2>&1> /dev/tty)
    exitstatus=$?
    if [ $exitstatus -eq 0 ]
    then
        appName=$(jq -r --arg pkgName "$pkgName" '.[$pkgName].appName' "$patchSource-patches.json")
    elif [ $exitstatus -ne 0 ]
    then
        mainmenu
    fi
    unset appVerList
}

selectPatches()
{
    checkJson
    toogleName="Exclude All"
    for i in $(jq -r --arg pkgName "$pkgName" '.[$pkgName].patches[].status' "$patchSource-patches.json")
    do
        if [ "$i" == "off" ]
        then
            toogleName="Include All"
            break
        fi
    done
    readarray -t patchesInfo < <(jq -r --arg pkgName "$pkgName" '.[$pkgName].patches[] | "\(.name)\n\(.status)\n\(.description)"' "$patchSource-patches.json")
    choices=($("${header[@]}" --begin 2 0 --title '| Patch Selection Menu |' --item-help --no-items --keep-window --no-shadow --ok-label "Save" --cancel-label "$toogleName" --help-button --help-label "Recommended" --checklist "Use arrow keys to navigate; Press Spacebar to toogle patch" $patchselectionheight -1 15 "${patchesInfo[@]}" 2>&1 >/dev/tty))
    selectPatchStatus=$?
    patchSaver
}

patchSaver()
{
    if [ $selectPatchStatus -eq 0 ]
    then
        tmp=$(mktemp)
        jq --arg pkgName "$pkgName" '.[$pkgName].patches[].status = "off"' "$patchSource-patches.json" | jq --arg pkgName "$pkgName" '(.[$pkgName].patches[] | select(IN(.name; $ARGS.positional[])) | .status ) |= "on"' --args "${choices[@]}" > "$tmp" && mv "$tmp" "$patchSource-patches.json"
        selectApp
        selectPatches
    elif [ $selectPatchStatus -eq 1 ]
    then
        if [ "$toogleName" == "Include All" ]
        then
            tmp=$(mktemp)
            jq --arg pkgName "$pkgName" '.[$pkgName].patches[].status = "on"' "$patchSource-patches.json" > "$tmp" && mv "$tmp" "$patchSource-patches.json"
            selectPatches
        elif [ "$toogleName" == "Exclude All" ]
        then
            tmp=$(mktemp)
            jq --arg pkgName "$pkgName" '.[$pkgName].patches[].status = "off"' "$patchSource-patches.json" > "$tmp" && mv "$tmp" "$patchSource-patches.json"
            selectPatches
        fi
    elif [ $selectPatchStatus -eq 2 ]
    then
        tmp=$(mktemp)
        jq --arg pkgName "$pkgName" '.[$pkgName].patches[].status = "off"' "$patchSource-patches.json" | jq --arg pkgName "$pkgName" '(.[$pkgName].patches[] | select(.excluded == false) | .status ) |= "on"' > "$tmp" && mv "$tmp" "$patchSource-patches.json"
        selectPatches
    fi
}

patchoptions()
{
    checkResources
    java -jar "$cliSource"-cli-*.jar -b "$patchSource"-patches-*.jar -m "$integrationsSource"-integrations-*.apk -c -a noinput.apk -o nooutput.apk > /dev/null 2>&1
    tput cnorm
    tmp=$(mktemp)
    "${header[@]}" --begin 2 0 --ok-label "Save" --cancel-label "Exit" --keep-window --no-shadow --title '| Options File Editor |' --editbox options.toml -1 -1 2> "$tmp" && mv "$tmp" options.toml
    tput civis
    mainmenu
}

rootInstall()
{
    "${header[@]}" --no-shadow --infobox "Installing $appName by Mounting..." 12 40
    pkgName=$pkgName appName=$appName appVer=$appVer su -mm -c 'grep $pkgName /proc/mounts | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -vl && cp ./"$appName"-Revanced-"$appVer".apk /data/local/tmp/revanced.delete && mv /data/local/tmp/revanced.delete /data/adb/revanced/"$pkgName".apk && stockApp=$(pm path $pkgName | sed -n "/base/s/package://p") && revancedApp=/data/adb/revanced/"$pkgName".apk && chmod -v 644 "$revancedApp" && chown -v system:system "$revancedApp" && chcon -v u:object_r:apk_data_file:s0 "$revancedApp" && mount -vo bind "$revancedApp" "$stockApp" && am force-stop $pkgName' > ./.mountlog 2>&1
    if ! su -c "grep -q $pkgName /proc/mounts"
    then
        "${header[@]}" --no-shadow --infobox "Installation Failed !!\nLogs saved to Revancify folder. Share the Mountlog to developer." 12 40
        cp ./.mountlog /storage/emulated/0/Revancify/mountlog.txt
        sleep 1
        mainmenu
    fi
    echo -e "#!/system/bin/sh\nwhile [ \"\$(getprop sys.boot_completed | tr -d '\\\r')\" != \"1\" ]; do sleep 1; done\n\nif [ \$(dumpsys package $pkgName | grep versionName | cut -d= -f 2 | sed -n '1p') =  \"$appVer\" ]\nthen\n\tbase_path=\"/data/adb/revanced/$pkgName.apk\"\n\tstock_path=\$( pm path $pkgName | sed -n '/base/s/package://p' )\n\n\tchcon u:object_r:apk_data_file:s0 \$base_path\n\tmount -o bind \$base_path \$stock_path\nfi" > "mount_revanced_$pkgName.sh"
    su -c "mv mount_revanced_$pkgName.sh /data/adb/service.d && chmod +x /data/adb/service.d/mount_revanced_$pkgName.sh"
    sleep 1
    su -c "settings list secure | sed -n -e 's/\/.*//' -e 's/default_input_method=//p' | xargs pidof | xargs kill -9 && pm resolve-activity --brief $pkgName | tail -n 1 | xargs am start -n && pidof com.termux | xargs kill -9" > /dev/null 2>&1
}

rootUninstall()
{ 
    selectApp
    if ! su -c "grep -q $pkgName /proc/mounts"
    then
        "${header[@]}" --msgbox "$appName Revanced is not installed(mounted) in your device." 12 40
        mainmenu
    fi
    "${header[@]}" --no-shadow --infobox "Uninstalling $appName Revanced by Unmounting..." 12 40
    pkgName=$pkgName su -mm -c 'grep $pkgName /proc/mounts | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l &&\
    stockApp=$(pm path $pkgName | sed -n "/base/s/package://p") && am force-stop $pkgName && rm /data/adb/service.d/mount_revanced_$pkgName.sh && rm -rf /data/adb/revanced/$pkgName.apk' > /dev/null 2>&1
    sleep 0.5s
    if ! su -c "grep -q $pkgName /proc/mounts"
    then
        "${header[@]}" --no-shadow --infobox "Uninstall Successful !!" 12 40
        sleep 1
        mainmenu
    else
        "${header[@]}" --no-shadow --infobox "Uninstall failed !! Something went wrong." 12 40
        sleep 1
        mainmenu
    fi
}

nonRootInstall()
{
    "${header[@]}" --no-shadow --infobox "Moving $appName-Revanced $selectedVer to Internal Storage..." 12 40
    sleep 0.5
    mv "$appName-Revanced"* /storage/emulated/0/Revancify/ > /dev/null 2>&1
    termux-open /storage/emulated/0/Revancify/"$appName-Revanced-$appVer".apk
    mainmenu
}

checkResources()
{
    if ls ".${source}latest" > /dev/null 2>&1
    then
        readarray -t sourceLatest < ".${source}latest"
    else
        resourceMenu
    fi

    if [ "${sourceLatest[2]}" = "$( ls "$cliSource"-cli-*.jar > /dev/null 2>&1 && du -b "$cliSource"-cli-*.jar | cut -d $'\t' -f 1 || echo "None" )" ] && [ "${sourceLatest[7]}" = "$( ls "$patchSource"-patches-*.jar > /dev/null 2>&1 && du -b "$patchSource"-patches-*.jar | cut -d $'\t' -f 1 || echo "None" )" ] && [ "${sourceLatest[10]}" = "$( ls "$integrationsSource"-integrations-*.apk > /dev/null 2>&1 && du -b "$integrationsSource"-integrations-*.apk | cut -d $'\t' -f 1 || echo "None" )" ] && ls "$patchSource"-patches.json > /dev/null 2>&1
    then
        return 0
    else
        resourceMenu
    fi
}


checkpatched()
{
    if [ "$variant" = "root" ]
    then
        if ls "$appName-Revanced-$appVer"* > /dev/null 2>&1
        then
            if "${header[@]}" --begin 2 0 --title '| Patched APK found |' --no-items --defaultno --keep-window --no-shadow --yesno "Current directory already contains $appName Revanced version $appVer. \n\n\nDo you want to patch $appName again?" -1 -1
            then
                rm "$appName-Revanced-$appVer"*
            else
                rootInstall
            fi
        else
            rm "$appName-Revanced-"* > /dev/null 2>&1
        fi
    elif [ "$variant" = "nonRoot" ]
    then
        if ls "/storage/emulated/0/Revancify/$appName-Revanced-$appVer"* > /dev/null 2>&1
        then
            if ! "${header[@]}" --begin 2 0 --title '| Patched APK found |' --no-items --defaultno --keep-window --no-shadow --yesno "Patched $appName with version $appVer already exists. \n\n\nDo you want to patch $appName again?" -1 -1
            then
                nonRootInstall
            fi
        fi
    fi
}

arg="$1"
checkSU()
{
    if su -c exit > /dev/null 2>&1
    then
        if [ "$arg" = '-n' ]
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

fetchApk()
{
    checkpatched
    if ls "$appName"-"$appVer"* > /dev/null 2>&1
    then
        if [ "$([ -f ".${appName}size" ] && cat ".${appName}size" || echo "0" )" != "$([ -f "$appName"-"$appVer".apk ] && du -b "$appName"-"$appVer".apk | cut -d $'\t' -f 1 || echo "None")" ]
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
    appUrl=$( ( python3 python-utils/fetch-link.py "$developer" "$remoteAppName" "$appVer" "$arch" 2>&3 | "${header[@]}" --begin 2 0 --gauge "App    : $appName\nVersion: $selectedVer\n\nScraping Download Link..." -1 -1 0 >&2 ) 3>&1 )
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
            "${header[@]}" --msgbox "No APK found on apkmirror.com for version $selectedVer !!\nTry selecting other version" 12 40
            getAppVer
        else
            "${header[@]}" --msgbox "No APK found on apkmirror.com for version $selectedVer !!\nPlease upgrade or degrade the version for patching." 12 40
            mainmenu
        fi
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

    if "${header[@]}" --begin 2 0 --title '| MicroG Prompt |' --no-items --defaultno --keep-window --no-shadow --yesno "Vanced MicroG is used to run MicroG services without root.\nYouTube and YouTube Music won't work without it.\nIf you already have MicroG, You don't need to download it.\n\n\n\n\n\nDo you want to download Vanced MicroG app?" -1 -1
    then
        internet
        readarray -t microgheaders < <(curl -s "https://api.github.com/repos/inotia00/VancedMicroG/releases/latest" | jq -r '(.assets[] | .browser_download_url, .size), .tag_name')
        wget -q -c "${microgheaders[0]}" -O "VancedMicroG-${microgheaders[2]}.apk" --show-progress --user-agent="$userAgent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "App     : Vanced MicroG\nVersion : ${microgheaders[2]}\nSize    : $(echo "${microgheaders[1]}" | numfmt --to=iec --format="%0.1f")\n\nDownloading..." -1 -1 && tput civis
        ls VancedMicroG* > /dev/null 2>&1 && mv VancedMicroG* /storage/emulated/0/Revancify/ && termux-open "/storage/emulated/0/Revancify/VancedMicroG-${microgheaders[2]}.apk"
    fi
    mainmenu
}

getAppVer()
{
    checkResources
    linkVar=$(jq -r --arg pkgName "$pkgName" '.[$pkgName].link' "$patchSource-patches.json")
    developer=$(cut -d '/' -f 3 <<< "$linkVar")
    remoteAppName=$(cut -d '/' -f 4 <<< "$linkVar")
    if [ "$variant" = "root" ]
    then
        if ! su -c "pm path $pkgName" > /dev/null 2>&1
        then
            if "${header[@]}" --begin 2 0 --title '| MicroG warning |' --no-items --defaultno --keep-window --no-shadow --yes-label "Non-Root" --no-label "Play Store" --yesno "$appName is not installed on your rooted device.\nYou have to install it from Play Store or you can proceed with Non-Root installation?\n\nWhich method do you want to proceed with?" -1 -1
            then
                variant="nonRoot"
                getAppVer
                return 0
            else
                termux-open "https://play.google.com/store/apps/details?id=$pkgName"
                mainmenu
            fi
        fi
        appVer=$(su -c dumpsys package "$pkgName" | grep -oP '(?<=versionName\=).*' | sed -e 's/[^0-9a-zA-Z]/-/g')
    elif [ "$variant" = "nonRoot" ]
    then
        
        internet
        "${header[@]}" --infobox "Please Wait !!" 12 40
        if [ -z "$appVerList" ]
        then
            readarray -t appVerList < <(python3 python-utils/fetch-versions.py "$remoteAppName" "$pkgName" "$source")
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
    selectedVer=$("${header[@]}" --begin 2 0 --title '| Version Selection Menu |' --keep-window --no-shadow --ok-label "Select" --menu "Choose App Version for $appName" -1 -1 15 "${appVerList[@]}" 2>&1> /dev/tty)
    exitstatus=$?
    appVer="${selectedVer//[^0-9a-zA-Z]/-}"
    if [ $exitstatus -ne 0 ]
    then
        mainmenu
        return 0
    fi
}

patchApp()
{
    checkJson
    readarray -t patchesArg < <(jq -r --arg pkgName "$pkgName" '.[$pkgName].patches[] | if .status == "on" then "-i " + .name else "-e " + .name end' "$patchSource-patches.json")
    java -jar "$cliSource"-cli-*.jar -b "$patchSource"-patches-*.jar -m "$integrationsSource"-integrations-*.apk -c -a "$appName-$appVer.apk" -o "$appName-Revanced-$appVer.apk" ${patchesArg[@]} --keystore revanced.keystore --custom-aapt2-binary "binaries/aapt2_$arch" --options options.toml --experimental 2>&1 | tee .patchlog | "${header[@]}" --begin 2 0 --ok-label "Continue" --cursor-off-label --programbox "Patching $appName-$appVer.apk" -1 -1
    tput civis
    sleep 2
    if ! grep -q "Finished" .patchlog
    then
        echo -e "\n\n\nVariant: $variant\nArch: $arch\nApp: $appName-$appVer.apk" >> .patchlog
        ls -1 "$source"-*-* >> .patchlog
        cp .patchlog /storage/emulated/0/Revancify/patchlog.txt
        "${header[@]}" --msgbox "Oops, Patching failed !!\nLog file saved to Revancify folder. Share the Patchlog to developer." 12 40
        mainmenu
    fi
}

checkMicrogPatch()
{
    microgStatus=$(jq -r --arg pkgName "$pkgName" '.[$pkgName].patches[] | select(.name |  test(".*microg.*")).status' "$patchSource-patches.json")
    if [ "$microgStatus" = "on" ] && [ "$variant" = "root" ]
    then
        if "${header[@]}" --begin 2 0 --title '| MicroG warning |' --no-items --defaultno --keep-window --no-shadow --yes-label "Continue" --no-label "Exclude" --yesno "You have a rooted device and you have included microg-support patch. This may result in $appName app crash.\n\n\nDo you want to exclude it or continue?" -1 -1
        then
            return 0
        else
            tmp=$(mktemp)
            jq -r --arg pkgName "$pkgName" '(.[$pkgName].patches[] | select(.name | test(".*microg.*")) | .status) |= "off"' "$patchSource-patches.json" > "$tmp" && mv "$tmp" "$patchSource-patches.json"
            return 0
        fi
    elif [ "$microgStatus" = "off" ] && [ "$variant" = "nonRoot" ]
    then
        if "${header[@]}" --begin 2 0 --title '| MicroG warning |' --no-items --defaultno --keep-window --no-shadow --yes-label "Continue" --no-label "Include" --yesno "You have a non-rooted device and you have not included microg-support patch. This may result in $appName app crash.\n\n\nDo you want to include it or continue?" -1 -1
        then
            return 0
        else
            tmp=$(mktemp)
            jq -r --arg pkgName "$pkgName" '(.[$pkgName].patches[] | select(.name | test(".*microg.*")) | .status) |= "on"' "$patchSource-patches.json" > "$tmp" && mv "$tmp" "$patchSource-patches.json"
            return 0
        fi
    fi
}

buildApp()
{
    selectApp
    checkResources
    checkJson
    getAppVer
    checkMicrogPatch
    patchApp
    ${variant}Install
}

checkSU
setup
header=(dialog --backtitle "Revancify | [Arch: $arch, SU: $variant]")
userAgent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36"
mainmenu()
{
    [ "$variant" = "root" ] && misc=(6 "Uninstall Revanced app") || misc=(6 "Download Vanced Microg")
    mainmenu=$("${header[@]}" --begin 2 0 --title '| Main Menu |' --keep-window --no-shadow --ok-label "Select" --cancel-label "Exit" --menu "Use arrow keys to navigate" -1 -1 15 1 "Patch App" 2 "Select Patches" 3 "Change Source" 4 "Check Resources" 5 "Edit Patch Options" "${misc[@]}" 2>&1> /dev/tty)
    exitstatus=$?
    if [ $exitstatus -eq 0 ]
    then
        if [ "$mainmenu" -eq "1" ]
        then
            buildApp
        elif [ "$mainmenu" -eq "2" ]
        then
            selectApp
            selectPatches
        elif [ "$mainmenu" -eq "3" ]
        then
            changeSource
        elif [ "$mainmenu" -eq "4" ]
        then
            resourceMenu
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
        fi
    elif [ $exitstatus -ne 0 ]
    then
        terminatescript
    fi
}

if [ "$arg" = '-f' ]
then
    resourcesVars
    getResources
fi
mainmenu