#!/bin/bash

UserAgent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"

arch=$(getprop ro.product.cpu.abi)
developer="$1"
appName="$2"
appVer="$3"

page1=$(curl -vsL -A "$UserAgent" "https://www.apkmirror.com/apk/$developer/$appName/$appName-$appVer-release" 2>&1)

canonicalUrl=$(pup -p --charset utf-8 'link[rel="canonical"] attr{href}' <<<"$page1")
if [[ "$canonicalUrl" == *"apk-download"* ]]; then
    urls=("${canonicalUrl/"https://www.apkmirror.com/"//}")
    url1=${urls[-1]}
else
    grep -q 'class="error404"' <<<"$page1" && echo noversion >&2 && exit 1

    page2=$(pup -p --charset utf-8 ':parent-of(span:contains("BUNDLE"))' <<<"$page1")

    if [ "$page2" != "" ]; then
        readarray -t urls < <(pup -p --charset utf-8 'a.accent_color attr{href}' <<<"$page2")
        appType="bundle"
        url1=${urls[0]}
    else
        page2=$(pup -p --charset utf-8 ':parent-of(:parent-of(span:contains("APK")))' <<<"$page1")
        
        [[ "$(pup -p --charset utf-8 ':parent-of(div:contains("noarch"))' <<<"$page2")" == "" ]] || arch=noarch
        [[ "$(pup -p --charset utf-8 ':parent-of(div:contains("universal"))' <<<"$page2")" == "" ]] || arch=universal

        readarray -t urls < <(pup -p --charset utf-8 ":parent-of(div:contains(\"$arch\")) a.accent_color attr{href}" <<<"$page2")
        [ "${#urls[@]}" -eq 0 ] && echo noapk >&2 && exit 1
        appType="apk"
        url1="${urls[-1]}"
    fi

fi
echo 33

page3=$(curl -sL -A "$UserAgent" "https://www.apkmirror.com$url1")

url2=$(pup -p --charset utf-8 'a:contains("Download APK") attr{href}' <<<"$page3")
size=$(pup -p --charset utf-8 ':parent-of(:parent-of(svg[alt="APK file size"])) div text{}' <<<"$page3" | sed -n 's/.*(//;s/ bytes.*//;s/,//gp')

[ "$url2" == "" ] && echo error >&2 && exit 1
echo 66

url3=$(curl -sL -A "$UserAgent" "https://www.apkmirror.com$url2" | pup -p --charset UTF-8 'a:contains("here") attr{href}' | head -n 1)

[ "$url3" == "" ] && echo error >&2 && exit 1
echo 100

echo "https://www.apkmirror.com$url3" >&2
echo "$size" >&2
echo "$appType" >&2