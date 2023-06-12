#!/usr/bin/bash

if [ -z "$TERMUX_VERSION" ]; then
    echo -e "\e[1;31mTermux not detected !!\e[0m\n\e[1;31mInstall aborted !!\e[0m"
    exit 1
fi

if [ -d "$HOME/Revancify" ]; then
    ./Revancify/revancify
    exit 0
fi

if ! command -v git &> /dev/null; then
    if ! pkg update -y; then
        echo -e "\e[1;31mOops !!
Possible causes of error:
1. Termux from Playstore is not maintained. Download Termux from github.
2. Unstable internet Connection.
3. Repository issues. Clear Termux Data and retry."
        exit 1
    fi
    pkg install git -y
fi

if git clone --depth=1 https://github.com/decipher3114/Revancify.git; then
    ./Revancify/revancify
else
    echo -e "\e[1;31mInstall Failed !!\e[0m"
    echo "Please Try again"
    exit 1
fi