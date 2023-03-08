#!/bin/bash

UserAgent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36"

arch=$(getprop ro.product.cpu.abi)
organisation="$1"
appName="$2"
appVer="$3"
path="$4"
pup="$path/binaries/pup_$arch"

page1=$(curl -vsL -A "$UserAgent" "https://www.apkmirror.com/apk/$organisation/$appName/$appName-$appVer-release" 2>&1)

grep -q 'class="error404"' <<< "$page1" && echo noversion >&2 && exit 1

page2=$("$pup" -p --charset utf-8 ':parent-of(:parent-of(span:contains("APK")))' <<< "$page1")


[[ "$("$pup" -p --charset utf-8 ':parent-of(div:contains("noarch"))' <<< "$page2")" == "" ]] || arch=noarch
[[ "$("$pup" -p --charset utf-8 ':parent-of(div:contains("universal"))' <<< "$page2")" == "" ]] || arch=universal


readarray -t url1 < <("$pup" -p --charset utf-8 ":parent-of(div:contains(\"$arch\")) a.accent_color attr{href}" <<< "$page2")

[ "${#url1[@]}" -eq 0 ] && echo noapk >&2 && exit 1
echo 33

url2=$(curl -sL -A "$UserAgent" "https://www.apkmirror.com${url1[-1]}" | "$pup" -p --charset utf-8 'a:contains("Download APK") attr{href}')

[ "$url2" == "" ] && echo error >&2 && exit 1
echo 66

url3=$(curl -sL -A "$UserAgent" "https://www.apkmirror.com$url2" | "$pup" -p --charset UTF-8 'a[data-google-vignette="false"][rel="nofollow"] attr{href}')

[ "$url3" == "" ] && echo error >&2 && exit 1
echo 100

echo "https://www.apkmirror.com$url3" >&2