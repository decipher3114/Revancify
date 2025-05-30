#!/usr/bin/bash

PKG_NAME="$1"
UNINSTALL_FROM_ALL_USERS="$2"
STORAGE="$3"

if [ -z "$STORAGE" ]; then
    log() { echo "$1"; }
else
    log() { echo "- $1" >> "$STORAGE/rish_log.txt"; }
fi

# Uninstall command
if [ "$UNINSTALL_FROM_ALL_USERS" = true ]; then
    CMD_RISH="pm uninstall --user all $PKG_NAME"
else
    CMD_RISH="pm uninstall --user current $PKG_NAME"
fi

# Execute the uninstall command using rish
OUTPUT=$(rish -c "$CMD_RISH" 2>&1)
log "Uninstall command: $CMD_RISH"
log "Uninstall output: $OUTPUT"

# Check the output for success or failure
if echo "$OUTPUT" | grep -q "^Success"; then
    log "Uninstall succeeded."
    exit 0
else
    log "Uninstall failed or with empty output, checking if package is still present."
    if [ "$UNINSTALL_FROM_ALL_USERS" == true ]; then
        if rish -c "dumpsys package $PKG_NAME" 2>&1 | grep -q "Unable to find package"; then
            log "Package $PKG_NAME no longer present in any user."
            exit 0
        else
            log "Package $PKG_NAME still present in another user."
            exit 1
        fi
    else
        if rish -c "pm list packages --user current" 2>&1 | grep -q "package:$PKG_NAME"; then
            log "Package $PKG_NAME still present for current user."
            exit 1
        else
            log "Package $PKG_NAME fully uninstalled."
            exit 0
        fi
    fi
fi