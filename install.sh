#!/usr/bin/bash

servers=("google.com" "raw.githubusercontent.com")

for server in "${servers[@]}"; do
    if ! ping -c 1 -W 3 "$server"&> /dev/null; then
        echo -e "\e[1;31m$server is not reachable with your current network.\nChange your network configuration.\e[0m"
    fi
done

if [ -z "$TERMUX_VERSION" ]; then
    echo -e "\e[1;31mTermux not detected !!\e[0m\n\e[1;31mInstall aborted !!\e[0m"
    exit 1
fi

if [ -d "$HOME/Revancify" ]; then
    ./Revancify/revancify
    exit 0
fi

if ! command -v git &> /dev/null; then
    if ! pkg update -y -o Dpkg::Options::="--force-confnew"; then
        echo -e "\e[1;31mOops !!
Possible causes of error:
1. Termux from Playstore is not maintained. Download Termux from github.
2. Unstable internet Connection.
3. Repository issues. Clear Termux Data and retry."
        exit 1
    fi
    pkg install git -y -o Dpkg::Options::="--force-confnew"
fi

if git clone --depth=1 https://github.com/decipher3114/Revancify.git; then
    ./Revancify/revancify
else
    echo -e "\e[1;31mInstall Failed !!\e[0m"
    echo "Please Try again"
    exit 1
fi