#!/usr/bin/bash

initiateWorkflow() {
    while true; do
        case "$TASK" in
        "CHOOSE_APP")
            chooseApp || break
            TASK="APP_FETCH"
            ;;
        "APP_FETCH")
            "$APP_SRC"AppFetch || continue
            TASK="MANAGE_PATCHES"
            ;;
        "MANAGE_PATCHES")
            managePatches || continue
            TASK="EDIT_OPTIONS"
            ;;
        "EDIT_OPTIONS")
            editOptions || continue
            TASK="PATCH_APP"
            ;;
        "PATCH_APP")
            patchApp || break
            TASK="INSTALL_APP"
            ;;
        "INSTALL_APP")
            installApp
            break
            ;;
        esac
    done
}
