#!/usr/bin/bash

initiateWorkflow() {
    TASK="CHOOSE_APP"
    while true; do
        case "$TASK" in
            "CHOOSE_APP")
                chooseApp || break
                ;;
            "DOWNLOAD_APP")
                downloadApp || continue
                TASK="MANAGE_PATCHES"
                ;;
            "IMPORT_APP")
                importApp || continue
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
