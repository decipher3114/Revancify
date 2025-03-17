#!/usr/bin/bash

deleteApps() {
    if "${DIALOG[@]}" \
        --title '| Delete Assets |' \
        --defaultno \
        --yesno "Please confirm to delete the apps.\nIt will delete all the downloaded and patched apps." -1 -1; then
        rm -rf "apps"/* "$STORAGE"/Patched/* &> /dev/null
    fi
}
