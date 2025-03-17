#!/usr/bin/bash

terminate() {
    killall -9 java &> /dev/null
    killall -9 dialog &> /dev/null
    killall -9 WGET &> /dev/null
    rm -rf -- *temporary*
    tput cnorm
    clear
    exit "${1:-0}"
}

setEnv() {
    if [ ! -f "$4" ]; then
        : > "$4"
    fi
    if ! grep -q "${1}=" "$4"; then
        echo "$1='$2'" >> "$4"
    elif [ "$3" == "update" ]; then
        sed -i "s|^$1=.*|$1='${2//&/\\&}'|" "$4"
    fi
}

notify() {
    dialog --backtitle 'Revancify' --"$1"box "$2" 12 45
}

internet() {
    if ! ping -c 1 google.com &> /dev/null; then
        notify msg "Oops! No Internet Connection available.\n\nConnect to Internet and try again later."
        return 1
    fi
}
