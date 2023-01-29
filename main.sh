#!/data/data/com.termux/files/usr/bin/bash

terminatescript(){
    clear && echo "Script terminated" ; rm -rf *cache; tput cnorm ; cd ~ ; exit
}
trap terminatescript SIGINT

# For update change this sentence here...

setup()
{
    arch=$(getprop ro.product.cpu.abi)
    mkdir -p /storage/emulated/0/Revancify

    sourceString='[{"sourceMaintainer" : "revanced", "sourceStatus" : "on"},{"sourceMaintainer" : "inotia00", "sourceStatus" : "off"}]'
    if ! ls sources* > /dev/null 2>&1
    then
        echo $sourceString | jq '.' > sources.json
    else
        sed -i 's/YTMusic/YouTube-Music/g' sources.json
        sed -i 's/TikTok/Tik-Tok/g' sources.json
    fi
    source=$(jq -r 'map(select(.sourceStatus == "on"))[].sourceMaintainer' sources.json)
}

internet()
{
    if ping -c 1 google.com > /dev/null 2>&1
    then
        return 0
    else
        "${header[@]}" --msgbox "Oops! No Internet Connection available.\n\nConnect to Internet and try again later" 12 40
        mainmenu
    fi
}


resourcemenu()
{
    internet

    python3 python-utils/revanced-latest.py "$source" && readarray -t source_latest < .${source}latest
    
    if [ "${source_latest[0]}" = "error" ]
    then
        "${header[@]}" --msgbox "Oops! Unable to connect to Github.\n\nRetry or change your Network." 12 40
        mainmenu
        return 0
    fi

    cli_latest="${source_latest[0]}"
    cli_url="${source_latest[1]}"
    cli_size="$(numfmt --to=iec --format="%0.1f" "${source_latest[2]}")"
    patches_latest="${source_latest[3]}"
    json_url="${source_latest[4]}"
    json_size="${source_latest[5]}"
    patches_url="${source_latest[6]}"
    patches_size="$(numfmt --to=iec --format="%0.1f" "${source_latest[7]}")"
    integrations_latest="${source_latest[8]}"
    integrations_url="${source_latest[9]}"
    integrations_size="$(numfmt --to=iec --format="%0.1f" "${source_latest[10]}")"


    ls ${source}-cli-*.jar > /dev/null 2>&1 && cli_available=$(basename ${source}-cli-*.jar .jar | cut -d '-' -f 3) || cli_available="Not found"
    ls ${source}-patches-*.jar > /dev/null 2>&1 && patches_available=$(basename ${source}-patches-*.jar .jar | cut -d '-' -f 3) || patches_available="Not found"
    ls ${source}-patches-*.json > /dev/null 2>&1 && json_available=$(basename ${source}-patches-*.json .json | cut -d '-' -f 3) || json_available="Not found"
    ls ${source}-integrations-*.apk > /dev/null 2>&1 && integrations_available=$(basename ${source}-integrations-*.apk .apk | cut -d '-' -f 3) || integrations_available="Not found"

    readarray -t resourcefilelines < <(echo -e "Resource_Latest_Downloaded\nCLI_${cli_latest}_${cli_available}\nPatches_${patches_latest}_${patches_available}\nIntegrations_${integrations_latest}_${integrations_available}" | column -t -s '_')

    cli_available_size=$( ls ${source}-cli-*.jar > /dev/null 2>&1 && du -b ${source}-cli-*.jar | cut -d $'\t' -f 1 || echo "None" )
    patches_available_size=$( ls ${source}-patches-*.jar > /dev/null 2>&1 && du -b ${source}-patches-*.jar | cut -d $'\t' -f 1 || echo "None" )
    integrations_available_size=$( ls ${source}-integrations-*.apk > /dev/null 2>&1 && du -b ${source}-integrations-*.apk | cut -d $'\t' -f 1 || echo "None" )

    "${header[@]}" --begin 2 0 --title '| Resources List |' --no-items --defaultno --yes-label "Fetch" --no-label "Cancel" --help-button --help-label "Delete All" --keep-window --no-shadow --yesno "Current Source: $source\n\n${resourcefilelines[0]}\n${resourcefilelines[1]}\n${resourcefilelines[2]}\n${resourcefilelines[3]}\n\nDo you want to fetch latest resources?" -1 -1
    resexitstatus=$?
    if [ $resexitstatus -eq 0 ]
    then
        if [ "$patches_latest" = "$patches_available" ] && [ "$patches_latest" = "$json_available" ] && [ "$cli_latest" = "$cli_available" ] && [ "$integrations_latest" = "$integrations_available" ] && [ "${source_latest[2]}" = "$cli_available_size" ] && [ "${source_latest[7]}" = "$patches_available_size" ] && [ "${source_latest[10]}" = "$integrations_available_size" ]
        then
            "${header[@]}" --msgbox "Resources are already downloaded !!\n\nPatches are successfully synced." 12 40
            python3 python-utils/sync-patches.py "$source" > /dev/null 2>&1
        else
            [ "$patches_latest" != "$patches_available" ] && rm ${source}-patches-*.jar > /dev/null 2>&1 && rm ${source}-patches-*.json
            [ "$cli_latest" != "$cli_available" ] && rm ${source}-cli-*.jar > /dev/null 2>&1
            [ "$integrations_latest" != "$integrations_available" ] && rm ${source}-integrations-*.apk > /dev/null 2>&1
            getresources
        fi
    elif [ $resexitstatus -eq 2 ]
    then
        if ! ls -1 ${source}-*-* > /dev/null 2>&1
        then
            "${header[@]}" --msgbox "No resources exist !!\n\nDownload the resources first." 12 40
            mainmenu
        fi
        if "${header[@]}" --begin 2 0 --title '| Clean resources |' --no-items --defaultno --keep-window --no-shadow --yesno "Do you want to delete the resources for the source $source?\nThis will delete the following files:\n$(ls -1 ${source}-*-*)" -1 -1
        then
            ls ${source}-cli-*.jar > /dev/null 2>&1 && rm ${source}-cli-*.jar
            ls ${source}-patches-*.jar > /dev/null 2>&1 && rm ${source}-patches-*.jar
            ls ${source}-patches-*.json > /dev/null 2>&1 && rm ${source}-patches-*.json
            ls ${source}-integrations-*.apk > /dev/null 2>&1 && rm ${source}-integrations-*.apk
            mainmenu
        fi
    fi
    mainmenu
}

getresources()
{
    [ "${source_latest[2]}" != "$cli_available_size" ] &&\
    wget -q -c "$cli_url" -O ${source}-cli-"$cli_latest".jar --show-progress --user-agent="$useragent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "Resource: CLI\nVersion : $cli_latest\nSize    : $cli_size\n\nDownloading..." -1 -1 && tput civis

    [ "${source_latest[2]}" != "$( ls ${source}-cli-*.jar > /dev/null 2>&1 && du -b ${source}-cli-*.jar | cut -d $'\t' -f 1 || echo "None" )" ] && "${header[@]}" --msgbox "Oops! Unable to download completely.\n\nRetry or change your Network." 12 40 && mainmenu && return 0
    
    [ "${source_latest[7]}" != "$patches_available_size" ] &&\
    wget -q -c "$patches_url" -O ${source}-patches-"$patches_latest".jar --show-progress --user-agent="$useragent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "Resource: Patches\nVersion : $patches_latest\nSize    : $patches_size\n\nDownloading..." -1 -1 && tput civis

    wget -q -c "$json_url" -O ${source}-patches-"$patches_latest".json --user-agent="$useragent"

    [ "${source_latest[7]}" != "$( ls ${source}-patches-*.jar > /dev/null 2>&1 && du -b ${source}-patches-*.jar | cut -d $'\t' -f 1 || echo "None" )" ] &&  "${header[@]}" --msgbox "Oops! Unable to download completely.\n\nRetry or change your Network." 12 40 && mainmenu && return 0

    [ "${source_latest[10]}" != "$integrations_available_size" ] &&\
    wget -q -c "$integrations_url" -O ${source}-integrations-"$integrations_latest".apk --show-progress --user-agent="$useragent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "Resource: Integrations\nVersion : $integrations_latest\nSize    : $integrations_size\n\nDownloading..." -1 -1 && tput civis

    [ "${source_latest[10]}" != "$( ls ${source}-integrations-*.apk > /dev/null 2>&1 && du -b ${source}-integrations-*.apk | cut -d $'\t' -f 1 || echo "None" )" ] && "${header[@]}" --msgbox "Oops! File not downloaded.\n\nRetry or change your Network." 12 40 && mainmenu && return 0

    python3 python-utils/sync-patches.py "$source" > /dev/null 2>&1
}


changesource()
{
    internet
    source=$(jq -r 'map(select(.sourceStatus == "on"))[].sourceMaintainer' sources.json)
    allsources=($(jq -r '.[] | "\(.sourceMaintainer) \(.sourceStatus)"' sources.json))
    selectedsource=$("${header[@]}" --begin 2 0 --title '| Source Selection Menu |' --keep-window --no-items --no-shadow --no-cancel --ok-label "Done" --radiolist "Use arrow keys to navigate; Press Spacebar to select option" -1 -1 15 "${allsources[@]}" 2>&1> /dev/tty)
    if [ "$source" != "$selectedsource" ]
    then
        tmp=$(mktemp)
        jq -r 'map(select(.).sourceStatus = "off")' sources.json | jq -r --arg selectedsource "$selectedsource" 'map(select(.sourceMaintainer == $selectedsource).sourceStatus = "on")' > "$tmp" && mv "$tmp" sources.json
        source=$(jq -r 'map(select(.sourceStatus == "on"))[].sourceMaintainer' sources.json)
        checkresources
    fi
    mainmenu
}

checkjson()
{
    if ! ls ${source}-patches-*.json > /dev/null 2>&1
    then
        "${header[@]}" --msgbox "No Json file found !!\nPlease download resources." 12 40
        resourcemenu
        return 0
    fi
    if ! ls ${source}-patches.json > /dev/null 2>&1
    then
        python3 python-utils/sync-patches.py "$source"
    fi
}

selectapp()
{
    checkjson
    readarray -t availableapps < <(jq -r 'map(select(.appName != null))[].appName' ${source}-patches.json)
    appname=$("${header[@]}" --begin 2 0 --title '| App Selection Menu |' --no-items --keep-window --no-shadow --ok-label "Select" --menu "Use arrow keys to navigate" -1 -1 15 "${availableapps[@]}" 2>&1> /dev/tty)
    exitstatus=$?
    if [ $exitstatus -eq 0 ]
    then
        pkgname=$(jq -r --arg appname "$appname" '.[] | select(.appName == $appname).pkgName' ${source}-patches.json)
    elif [ $exitstatus -ne 0 ]
    then
        mainmenu
    fi
}


selectpatches()
{
    checkjson
    patchselectionheight=$(($(tput lines) - 3))
    readarray -t patchesinfo < <(jq -r --arg pkgname "$pkgname" 'map(select(.pkgName == $pkgname))[].patches[] | "\(.name)\n\(.status)\n\(.description)"' "${source}-patches.json")
    choices=($("${header[@]}" --begin 2 0 --title '| Patch Selection Menu |' --item-help --no-items --keep-window --no-shadow --help-button --help-label "Exclude all" --extra-button --extra-label "Include all" --ok-label "Save" --no-cancel --checklist "Use arrow keys to navigate; Press Spacebar to toogle patch" $patchselectionheight -1 15 "${patchesinfo[@]}" 2>&1 >/dev/tty))
    selectpatchstatus=$?
    patchsaver
}

patchsaver()
{
    if [ $selectpatchstatus -eq 0 ]
    then
        tmp=$(mktemp)
        jq --arg pkgname "$pkgname" 'map(select(.pkgName == $pkgname).patches[].status = "off")' "${source}-patches.json" | jq '(.[].patches[] | select(IN(.name; $ARGS.positional[])) | .status ) |= "on"' --args "${choices[@]}" > "$tmp" && mv "$tmp" "${source}-patches.json"
        mainmenu
    elif [ $selectpatchstatus -eq 2 ]
    then
        tmp=$(mktemp)
        jq --arg pkgname "$pkgname" 'map(select(.pkgName == $pkgname).patches[].status = "off")' "${source}-patches.json" > "$tmp" && mv "$tmp" "${source}-patches.json"
        selectpatches
    elif [ $selectpatchstatus -eq 3 ]
    then
        tmp=$(mktemp)
        jq --arg pkgname "$pkgname" 'map(select(.pkgName == $pkgname).patches[].status = "on")' "${source}-patches.json" > "$tmp" && mv "$tmp" "${source}-patches.json"
        selectpatches
    fi
}


patchoptions()
{
    checkresources
    java -jar ${source}-cli-*.jar -b ${source}-patches-*.jar -m ${source}-integrations-*.apk -c -a noinput.apk -o nooutput.apk > /dev/null 2>&1
    tput cnorm
    tmp=$(mktemp)
    "${header[@]}" --begin 2 0 --ok-label "Save" --cancel-label "Exit" --keep-window --no-shadow --title '| Options File Editor |' --editbox options.toml -1 -1 2> "$tmp" && mv "$tmp" options.toml
    tput civis
    mainmenu
}

rootinstall()
{   
    "${header[@]}" --no-shadow --infobox "Installing $appname by Mounting..." 12 40
    pkgname=$pkgname appname=$appname appver=$appver su -mm -c 'grep $pkgname /proc/mounts | while read -r line; do echo $line | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l > /dev/null 2>&1; done &&\
    cp /data/data/com.termux/files/home/storage/Revancify/"$appname"Revanced-"$appver".apk /data/local/tmp/revanced.delete &&\
    mv /data/local/tmp/revanced.delete /data/adb/revanced/"$pkgname".apk &&\
    stockapp=$(pm path $pkgname | grep base | sed "s/package://g") &&\
    revancedapp=/data/adb/revanced/"$pkgname".apk &&\
    chmod 644 "$revancedapp" &&\
    chown system:system "$revancedapp" &&\
    chcon u:object_r:apk_data_file:s0 "$revancedapp" &&\
    mount -o bind "$revancedapp" "$stockapp" &&\
    am force-stop $pkgname' 2>&1 .mountlog
    if ! su -c "grep -q $pkgname /proc/mounts"
    then
        "${header[@]}" --no-shadow --infobox "Installation Failed !!\nLogs saved to Revancify folder. Share the Mountlog to developer." 12 40
        cp .mountlog /storage/emulated/0/Revancify/mountlog.txt
        sleep 1
        mainmenu
    fi
    echo -e "#!/system/bin/sh\nwhile [ \"\$(getprop sys.boot_completed | tr -d '\\\r')\" != \"1\" ]; do sleep 1; done\n\nif [ \$(dumpsys package $pkgname | grep versionName | cut -d= -f 2 | sed -n '1p') =  \"$appver\" ]\nthen\n\tbase_path=\"/data/adb/revanced/$pkgname.apk\"\n\tstock_path=\$( pm path $pkgname | grep base | sed 's/package://g' )\n\n\tchcon u:object_r:apk_data_file:s0 \$base_path\n\tmount -o bind \$base_path \$stock_path\nfi" > mount_revanced_$pkgname.sh
    su -c "mv mount_revanced_$pkgname.sh /data/adb/service.d && chmod +x /data/adb/service.d/mount_revanced_$pkgname.sh"
    sleep 1
    su -c "settings list secure | sed -n -e 's/\/.*//' -e 's/default_input_method=//p' | xargs pidof | xargs kill -9 && pm resolve-activity --brief $pkgname | tail -n 1 | xargs am start -n && pidof com.termux | xargs kill -9" > /dev/null 2>&1
}

rootuninstall()
{   
    selectapp
    if ! su -c "grep -q $pkgname /proc/mounts"
    then
        "${header[@]}" --msgbox "$appname Revanced is not installed(mounted) in your device." 12 40
        mainmenu
    fi
    "${header[@]}" --no-shadow --infobox "Uninstalling $appname Revanced by Unmounting..." 12 40
    pkgname=$pkgname su -mm -c 'grep $pkgname /proc/mounts | while read -r line; do echo $line | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l > /dev/null 2>&1; done &&\
    stockapp=$(pm path $pkgname | grep base | sed "s/package://g") &&\
    am force-stop $pkgname &&\
    rm /data/adb/service.d/mount_revanced_$pkgname.sh &&\
    rm -rf /data/adb/revanced/$pkgname.apk' > /dev/null 2>&1
    sleep 0.5s
    if ! su -c "grep -q $pkgname /proc/mounts"
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

nonrootinstall()
{
    mv "$appname"Revanced* /storage/emulated/0/Revancify/ > /dev/null 2>&1
    termux-open /storage/emulated/0/Revancify/"$appname"Revanced-"$appver".apk
    mainmenu
    return 0
}

checkresources()
{
    if ls .${source}latest > /dev/null 2>&1
    then
        readarray -t source_latest < .${source}latest
    else
        resourcemenu
    fi

    if [ "${source_latest[2]}" = "$( ls ${source}-cli-*.jar > /dev/null 2>&1 && du -b ${source}-cli-*.jar | cut -d $'\t' -f 1 || echo "None" )" ] && [ "${source_latest[7]}" = "$( ls ${source}-patches-*.jar > /dev/null 2>&1 && du -b ${source}-patches-*.jar | cut -d $'\t' -f 1 || echo "None" )" ] && [ "${source_latest[10]}" = "$( ls ${source}-integrations-*.apk > /dev/null 2>&1 && du -b ${source}-integrations-*.apk | cut -d $'\t' -f 1 || echo "None" )" ] && ls ${source}-patches.json > /dev/null 2>&1
    then
        return 0
    else
        resourcemenu
    fi
}


checkpatched()
{
    if [ "$variant" = "root" ]
    then
        if ls "$appname"Revanced-"$appver"* > /dev/null 2>&1
        then
            if "${header[@]}" --begin 2 0 --title '| Patched APK found |' --no-items --defaultno --keep-window --no-shadow --yesno "Current directory already contains $appname Revanced version $appver. \n\n\nDo you want to patch $appname again?" -1 -1
            then
                rm "$appname"Revanced-"$appver"*
            else
                rootinstall
            fi
        else
            rm "$appname"Revanced-* > /dev/null 2>&1
        fi
    elif [ "$variant" = "nonroot" ]
    then
        if ls /storage/emulated/0/Revancify/"$appname"Revanced-"$appver"* > /dev/null 2>&1
        then
            if ! "${header[@]}" --begin 2 0 --title '| Patched APK found |' --no-items --defaultno --keep-window --no-shadow --yesno "Patched $appname with version $appver already exists. \n\n\nDo you want to patch $appname again?" -1 -1
            then
                nonrootinstall
            fi
        fi
    fi
}
arg="$1"
sucheck()
{
    if su -c exit > /dev/null 2>&1
    then
        if [ "$arg" = '-n' ]
        then
            variant=nonroot
        else
            variant=root
            su -c "mkdir -p /data/adb/revanced"
        fi
    else
        variant=nonroot
    fi
}

fetchapk()
{
    checkpatched
    if ls "$appname"-"$appver"* > /dev/null 2>&1
    then
        if [ "$([ -f ."$appname"size ] && cat ."$appname"size || echo "0" )" != "$([ -f "$appname"-"$appver".apk ] && du -b "$appname"-"$appver".apk | cut -d $'\t' -f 1 || echo "None")" ]
        then
            app_dl
        fi
    else
        rm "$appname"*.apk > /dev/null 2>&1
        app_dl
    fi
    apkargs="-a $appname-$appver.apk -o ${appname}Revanced-$appver.apk"
}

app_dl()
{
    internet
    appurl=$( ( python3 python-utils/fetch-link.py "$appname" "$appver" "$organisation" "$arch" 2>&3 | "${header[@]}" --begin 2 0 --gauge "App    : $appname\nVersion: $appver\n\nScraping Download Link..." -1 -1 0 >&2 ) 3>&1 )
    tput civis
    curl -s -L -I "$appurl" -A "$useragent" | sed -n '/Content-Length/s/Content-Length: //p' > ."$appname"size
    if [ "$appurl" = "error" ]
    then
        "${header[@]}" --msgbox "Unable to fetch link !!\nThere is some problem with your internet connection. Disable VPN or Change your network." 12 40
        mainmenu
        return 0
    elif [ "$appurl" = "noapk" ]
    then
        "${header[@]}" --msgbox "No APK found.\nTry selecting other version" 12 40
        mainmenu
        return 0
    fi
    wget -q -c "$appurl" -O "$appname"-"$appver".apk --show-progress --user-agent="" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "App    : $appname\nVersion: $appver\nSize   : $(numfmt --to=iec --format="%0.1f" < ".${appname}size" )\n\nDownloading..." -1 -1
    tput civis
    sleep 0.5s
    if [ "$(cat ."$appname"size)" != "$(du -b "$appname"-"$appver".apk | cut -d $'\t' -f 1)" ]
    then
        "${header[@]}" --msgbox "Oh No !!\nUnable to complete download. Please Check your internet connection and Retry." 12 40
        mainmenu
    fi      
}

dlmicrog()
{

    if "${header[@]}" --begin 2 0 --title '| MicroG Prompt |' --no-items --defaultno --keep-window --no-shadow --yesno "Vanced MicroG is used to run MicroG services without root.\nYouTube and YouTube Music won't work without it.\nIf you already have MicroG, You don't need to download it.\n\n\n\n\n\nDo you want to download Vanced MicroG app?" -1 -1
    then
        internet
        readarray -t microgheaders < <(curl -s "https://api.github.com/repos/inotia00/VancedMicroG/releases/latest" | jq -r '(.assets[] | .browser_download_url, .size), .tag_name')
        wget -q -c "${microgheaders[0]}" -O "VancedMicroG-${microgheaders[2]}.apk" --show-progress --user-agent="$useragent" 2>&1 | stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' | "${header[@]}" --begin 2 0 --gauge "App     : Vanced MicroG\nVersion : ${microgheaders[2]}\nSize    : $(echo "${microgheaders[1]}" | numfmt --to=iec --format="%0.1f")\n\nDownloading..." -1 -1 && tput civis
        ls VancedMicroG* > /dev/null 2>&1 && mv VancedMicroG* /storage/emulated/0/Revancify/ && termux-open "/storage/emulated/0/Revancify/VancedMicroG-${microgheaders[2]}.apk"
    fi
    mainmenu
}

setargs()
{
    includepatches=$(while read -r line; do printf %s"$line" " "; done < <(jq -r --arg pkgname "$pkgname" '.[] | select(.pkgName == $pkgname) | .patches[] | select(.status == "on") | .name' "${source}-patches.json" | sed "s/^/-i /g"))
    excludepatches=$(while read -r line; do printf %s"$line" " "; done < <(jq -r --arg pkgname "$pkgname" '.[] | select(.pkgName == $pkgname) | .patches[] | select(.status == "off") | .name' "${source}-patches.json" | sed "s/^/-e /g"))
}


getapplist()
{
    checkresources
    internet
    "${header[@]}" --infobox "Please Wait !!" 12 40
    readarray -t appverlist < <(python3 python-utils/fetch-versions.py "$appname" "$source")
    organisation="${appverlist[-1]}"
    unset appverlist[-1]
}


versionselector()
{
    if [ "${appverlist[0]}" = "error" ]
    then
        "${header[@]}" --msgbox "Unable to fetch link !!\nThere is some problem with your internet connection. Disable VPN or Change your network." 12 40
        mainmenu
    fi
    verchoosed=$("${header[@]}" --begin 2 0 --title '| Version Selection Menu |' --no-items --keep-window --no-shadow --ok-label "Select" --menu "Choose App Version for $appname" -1 -1 15 "${appverlist[@]}" 2>&1> /dev/tty)
    exitstatus=$?
    appver=$(echo "$verchoosed" | cut -d " " -f 1)
    if [ $exitstatus -ne 0 ]
    then
        mainmenu
        return 0
    fi
}


patchapp()
{
    if ! ls ${source}-patches.json > /dev/null 2>&1
    then
        python3 python-utils/sync-patches.py "$source"
    fi
    setargs
    java -jar ${source}-cli-*.jar -b ${source}-patches-*.jar -m ${source}-integrations-*.apk -c $apkargs $includepatches $excludepatches --keystore revanced.keystore --custom-aapt2-binary binaries/aapt2_"$arch" --options options.toml --experimental 2>&1 | tee .patchlog | "${header[@]}" --begin 2 0 --ok-label "Continue" --cursor-off-label --programbox "Patching $appname-$appver.apk" -1 -1
    tput civis
    sleep 2
    if ! grep -q "Finished" .patchlog
    then
        echo -e "\n\n\nVariant: $variant\nArch: $arch\nApp: $appname-$appver.apk" >> .patchlog
        cp .patchlog /storage/emulated/0/Revancify/patchlog.txt
        "${header[@]}" --msgbox "Oops, Patching failed !!\nLog file saved to Revancify folder. Share the Patchlog to developer." 12 40
        mainmenu
    fi
}

checkmicrogpatch()
{
    microgstatus=$(jq -r --arg pkgname $pkgname '.[] | select(.pkgName == $pkgname) | .patches[] | select(.name |  test(".*microg.*")).status' "${source}-patches.json")
    if [ "$microgstatus" = "on" ] && [ "$variant" = "root" ]
    then
        if "${header[@]}" --begin 2 0 --title '| MicroG warning |' --no-items --defaultno --keep-window --no-shadow --yes-label "Continue" --no-label "Exclude" --yesno "You have a rooted device and you have included microg-support patch. This may result in $appname app crash.\n\n\nDo you want to exclude it or continue?" -1 -1
        then
            return 0
        else
            tmp=$(mktemp)
            jq -r --arg pkgname $pkgname '(.[] | select(.pkgName == $pkgname) | .patches[] | select(.name | test(".*microg.*")) | .status) |= "off"' "${source}-patches.json" > "$tmp" && mv "$tmp" "${source}-patches.json"
            return 0
        fi
    elif [ "$microgstatus" = "off" ] && [ "$variant" = "nonroot" ]
    then
        if "${header[@]}" --begin 2 0 --title '| MicroG warning |' --no-items --defaultno --keep-window --no-shadow --yes-label "Continue" --no-label "Include" --yesno "You have a non-rooted device and you have not included microg-support patch. This may result in $appname app crash.\n\n\nDo you want to include it or continue?" -1 -1
        then
            return 0
        else
            tmp=$(mktemp)
            jq -r --arg pkgname $pkgname '(.[] | select(.pkgName == $pkgname) | .patches[] | select(.name | test(".*microg.*")) | .status) |= "on"' "${source}-patches.json" > "$tmp" && mv "$tmp" "${source}-patches.json"
            return 0
        fi
    fi
}

#Build apps
buildapp()
{
    selectapp
    checkresources
    if ! ls ${source}-patches.json > /dev/null 2>&1
    then
        internet
        python3 python-utils/sync-patches.py "$source"
    fi
    getapplist
    if [ "$variant" = "root" ]
    then
        if ! su -c "pm path $pkgname" > /dev/null 2>&1
        then 
            termux-open "https://play.google.com/store/apps/details?id="$pkgname
            mainmenu
        fi
        appver=$(su -c dumpsys package $pkgname | grep versionName | cut -d '=' -f 2 | sed -n '1p')
    elif [ "$variant" = "nonroot" ]
    then
        versionselector
    fi
    checkmicrogpatch
    fetchapk
    patchapp
    if [ "$variant" = "root" ]
    then
        rootinstall
    elif [ "$variant" = "nonroot" ]
    then
        nonrootinstall
    fi
}

sucheck
setup
header=(dialog --backtitle "Revancify  |  [Arch: $arch, SU: $variant]")
useragent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36"
mainmenu()
{
    [ "$variant" = "root" ] && misc=(6 "Uninstall Revanced app") || misc=(6 "Download Vanced Microg")
    mainmenu=$("${header[@]}" --begin 2 0 --title '| Main Menu |' --keep-window --no-shadow --ok-label "Select" --cancel-label "Exit" --menu "Use arrow keys to navigate" -1 -1 15 1 "Patch App" 2 "Select Patches" 3 "Change Source" 4 "Check Resources" 5 "Edit Patch Options" "${misc[@]}" 2>&1> /dev/tty)
    exitstatus=$?
    if [ $exitstatus -eq 0 ]
    then
        if [ "$mainmenu" -eq "1" ]
        then
            buildapp
        elif [ "$mainmenu" -eq "2" ]
        then
            selectapp
            selectpatches
        elif [ "$mainmenu" -eq "3" ]
        then
            changesource
        elif [ "$mainmenu" -eq "4" ]
        then
            resourcemenu
        elif [ "$mainmenu" -eq "5" ]
        then
            patchoptions
        elif [ "$mainmenu" -eq "6" ]
        then
            if [ "$variant" = "root" ]
            then
                rootuninstall
            elif [ "$variant" = "nonroot" ]
            then
                dlmicrog
            fi
        fi
    elif [ $exitstatus -ne 0 ]
    then
        terminatescript
    fi
}


mainmenu
