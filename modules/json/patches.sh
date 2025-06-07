#!/usr/bin/bash

managePatches() {
    local ENABLED_PATCHES_LIST BUTTON_TEXT PATCHES_ARRAY UPDATED_PATCHES CHOICES EXIT_CODE
    readarray -t ENABLED_PATCHES_LIST < <(
        jq -nrc --arg PKG_NAME "$PKG_NAME" --argjson ENABLED_PATCHES "$ENABLED_PATCHES" '
        $ENABLED_PATCHES |
        if any(.[]; .pkgName == $PKG_NAME) then
            .[] | select(.pkgName == $PKG_NAME) | .patches[]
        else
            empty
        end'
    )
    BUTTON_TEXT="Recommended"

    while true; do

        readarray -t PATCHES_ARRAY < <(
            jq -nrc \
                --arg PKG_NAME "$PKG_NAME" \
                --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '
                $AVAILABLE_PATCHES[] |
                select(.pkgName == $PKG_NAME or .pkgName == null) |
                .patches |
                .recommended[], .optional[] |
                . as $PATCH |
                if ($ARGS.positional | index($PATCH)) != null then
                    $PATCH, "on"
                else
                    $PATCH, "off"
                end
            ' --args "${ENABLED_PATCHES_LIST[@]}"
        )

        CHOICES=$(
            "${DIALOG[@]}" \
                --title '| Patch Selection Menu |' \
                --no-items \
                --separate-output \
                --ok-label 'Done' \
                --cancel-label "$BUTTON_TEXT" \
                --help-button \
                --help-label "Back" \
                --checklist "$NAVIGATION_HINT\n$SELECTION_HINT" -1 -1 0 \
                "${PATCHES_ARRAY[@]}" 2>&1 > /dev/tty
        )
        EXIT_CODE=$?

        [ "$CHOICES" != "" ] && readarray -t ENABLED_PATCHES_LIST <<< "$CHOICES"

        case "$EXIT_CODE" in
            0)
                if [ ${#ENABLED_PATCHES_LIST[@]} -eq 0 ]; then
                    notify msg "No patches enabled!!\nPatches selection couldn't be empty. Enable some patches to continue."
                    continue
                fi
                break
                ;;
            1)
                if [ "$BUTTON_TEXT" == "Recommended" ]; then
                    readarray -t ENABLED_PATCHES_LIST < <(jq -nrc --arg PKG_NAME "$PKG_NAME" --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '$AVAILABLE_PATCHES[] | select(.pkgName == $PKG_NAME or .pkgName == null) | .patches | .recommended[]')
                    BUTTON_TEXT="Enable All"
                elif [ "$BUTTON_TEXT" == "Enable All" ]; then
                    readarray -t ENABLED_PATCHES_LIST < <(jq -nrc --arg PKG_NAME "$PKG_NAME" --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '$AVAILABLE_PATCHES[] | select(.pkgName == $PKG_NAME or .pkgName == null) | .patches | .recommended[], .optional[]')
                    BUTTON_TEXT="Disable All"
                elif [ "$BUTTON_TEXT" == "Disable All" ]; then
                    ENABLED_PATCHES_LIST=()
                    BUTTON_TEXT="Recommended"
                fi
                ;;
            2)
                TASK="CHOOSE_APP"
                return 1
                ;;
        esac
    done

    clear

    UPDATED_PATCHES=$(
        jq -nc --arg PKG_NAME "$PKG_NAME" --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" --argjson ENABLED_PATCHES "$ENABLED_PATCHES" '
            [
                $AVAILABLE_PATCHES[] |
                select(.pkgName == $PKG_NAME or .pkgName == null) |
                .options[]
            ] as $AVAILABLE_OPTIONS |
            $ENABLED_PATCHES |
            if any(.[]; .pkgName == $PKG_NAME) then
                .
            else
                . += [{"pkgName": $PKG_NAME}]
            end |
            map(
                if .pkgName == $PKG_NAME then
                    .patches |= [$ARGS.positional | if (.[0] == "") then empty else .[] end] |
                    .options |= (
                        . as $SAVED_OPTIONS | [
                            $AVAILABLE_OPTIONS[] |
                            . as $OPTION |
                            .patchName as $PATCH_NAME |
                            if ($ARGS.positional | index($PATCH_NAME)) != null then
                                .title as $TITLE |
                                .key as $KEY |
                                .default as $DEFAULT |
                                {
                                    "title": $TITLE,
                                    "patchName": $PATCH_NAME,
                                    "key": $KEY,
                                    "value": (($SAVED_OPTIONS[]? | select(.key == $KEY and .patchName == $PATCH_NAME) | .value) // $DEFAULT)
                                }
                            else
                                empty
                            end
                        ]
                    )
                else
                    .
                end
            )
        ' --args "${ENABLED_PATCHES_LIST[@]}"
    )

    echo "$UPDATED_PATCHES" > "$STORAGE/$SOURCE-patches.json"
    ENABLED_PATCHES="$UPDATED_PATCHES"
}
