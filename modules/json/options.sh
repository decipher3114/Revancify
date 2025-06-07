#!/usr/bin/bash

editOptions() {
    local OPTIONS_JSON OPTIONS_LIST CURRENT_VALUE TYPE DESCRIPTION VALUE ALLOWED_VALUES NEW_VALUE EXIT_CODE TEMP_FILE UPDATED_OPTIONS UPDATED_PATCHES

    OPTIONS_JSON=$(
        jq -nc \
            --arg PKG_NAME "$PKG_NAME" \
            --argjson ENABLED_PATCHES "$ENABLED_PATCHES" '
            $ENABLED_PATCHES[] | select(.pkgName == $PKG_NAME) | .options
        '
    )

    [ "$OPTIONS_JSON" == '[]' ] && return

    readarray -t OPTIONS_LIST < <(
        jq -r '
            .[] |
            (
                {
                    "key": .key,
                    "patchName": .patchName
                } |
                tostring
            ),
            .title
        ' <<< "$OPTIONS_JSON"
    )
    while true; do

        unset EXIT_CODE

        if [ -z "$SELECTED_OPTION" ]; then
            SELECTED_OPTION="$(
                "${DIALOG[@]}" \
                    --title '| Select Option Key |' \
                    --no-tags \
                    --ok-label 'Edit' \
                    --cancel-label 'Done' \
                    --help-button \
                    --help-label 'Back' \
                    --menu "$NAVIGATION_HINT" -1 -1 0 \
                    "${OPTIONS_LIST[@]}" 2>&1 > /dev/tty
            )"
            case "$?" in
                1)
                    break
                    ;;
                2)
                    TASK="MANAGE_PATCHES"
                    unset OPTIONS_JSON SELECTED_OPTION CURRENT_VALUE NEW_VALUE
                    return 1
                    ;;
            esac
        else

            readarray -t CURRENT_VALUE < <(
                jq -r --arg SELECTED_OPTION "$SELECTED_OPTION" '
                    .[] |
                    select(
                        .key as $KEY |
                        .patchName as $PATCH_NAME |
                        $SELECTED_OPTION |
                        fromjson |
                        .key == $KEY and .patchName == $PATCH_NAME
                    ) |
                    .value |
                    if (. | type) == "array" then
                        .[]
                    else
                        .
                    end |
                    if . != null then
                        .
                    else
                        empty
                    end
                ' <<< "$OPTIONS_JSON"
            )

            source <(
                jq -nrc \
                    --arg PKG_NAME "$PKG_NAME" \
                    --arg SELECTED_OPTION "$SELECTED_OPTION" \
                    --arg CURRENT_VALUE "${CURRENT_VALUE[0]}" \
                    --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '
                    $AVAILABLE_PATCHES[] |
                    select(.pkgName == $PKG_NAME or .pkgName == null) |
                    .options[] |
                    select(
                        .key as $KEY |
                        .patchName as $PATCH_NAME |
                        $SELECTED_OPTION |
                        fromjson |
                        .key == $KEY and .patchName == $PATCH_NAME
                    ) |
                    "TYPE=\(.type)",
                    "DESCRIPTION=\"\(.description | gsub("\n"; "\\n") | gsub("\""; "\\\""))\"",
                    "VALUES=(
                        \(
                            [
                                .values |
                                if (length != 0) then (
                                    if any(.[]; match(".*?(?= \\()").string == $CURRENT_VALUE) then
                                    (
                                        .[] |
                                        if match(".*?(?= \\()").string == $CURRENT_VALUE then
                                            ., "on"
                                        else
                                            ., "off"
                                        end
                                    ) else (
                                        (.[] | ., "off"), "\($CURRENT_VALUE) (Custom)", "on"
                                    ) end
                                ) else
                                    empty
                                end
                            ] |
                            map("\"\(.)\"") |
                            join(" ")
                        )
                    )"
                '
            )

            while true; do
                if [ "$TYPE" == "$BOOLEAN" ] || [ "${VALUES[0]}" != "" ]; then
                    if [ "$TYPE" != "$BOOLEAN" ]; then
                        ALLOWED_VALUES=("${VALUES[@]}" "Custom Value" "off")
                    else
                        if [ "${CURRENT_VALUE[0]}" == "true" ]; then
                            ALLOWED_VALUES=("true" "on" "false" "off")
                        else
                            ALLOWED_VALUES=("true" "off" "false" "on")
                        fi
                    fi
                    NEW_VALUE=$(
                        "${DIALOG[@]}" \
                            --title '| Choose Option Value |' \
                            --no-items \
                            --ok-label 'Done' \
                            --cancel-label 'Cancel' \
                            --help-button \
                            --help-label 'Description' \
                            --radiolist "$NAVIGATION_HINT\n$SELECTION_HINT" -1 -1 0 \
                            "${ALLOWED_VALUES[@]}" 2>&1 > /dev/tty
                    )
                    EXIT_CODE=$?
                    unset ALLOWED_VALUES

                    case "$EXIT_CODE" in
                        1)
                            unset NEW_VALUE
                            break
                            ;;
                        2)
                            "${DIALOG[@]}" \
                                --title '| Option Description |' \
                                --msgbox "Value Type : $TYPE\nDescription: $DESCRIPTION" -1 -1
                            continue
                            ;;
                    esac
                    NEW_VALUE=${NEW_VALUE%% (*}
                    if [ "$NEW_VALUE" == "Custom Value" ]; then
                        unset NEW_VALUE
                    fi
                fi

                if [ -z "$NEW_VALUE" ]; then
                    tput cnorm
                    if [ "$TYPE" == "$STRINGARRAY" ]; then
                        TEMP_FILE="$(mktemp)"
                        printf "%s\n" "${CURRENT_VALUE[@]}" > "$TEMP_FILE"
                        tput cnorm
                        NEW_VALUE=$(
                            "${DIALOG[@]}" \
                                --title '| Edit Option Value |' \
                                --help-button \
                                --help-label "Description" \
                                --editbox "$TEMP_FILE" -1 -1 \
                                2>&1 1>&2 1> /dev/tty
                        )
                        EXIT_CODE=$?
                        rm "$TEMP_FILE"
                        readarray -t NEW_VALUE <<< "$NEW_VALUE"
                    else
                        NEW_VALUE=$(
                            "${DIALOG[@]}" \
                                --title '| Edit Option Value |' \
                                --help-button \
                                --help-label \
                                "Description" \
                                --inputbox "Enter $TYPE\nLeave empty to set as null" -1 -1 \
                                "${CURRENT_VALUE[@]}" \
                                2>&1 1>&2 1> /dev/tty
                        )
                        EXIT_CODE=$?
                    fi

                    tput civis
                    case "$EXIT_CODE" in
                        1)
                            unset NEW_VALUE
                            break
                            ;;
                        2)
                            "${DIALOG[@]}" \
                                --title '| Option Description |' \
                                --msgbox "Value Type : $TYPE\n# Each line represents an individual value.\nDescription: $DESCRIPTION" -1 -1
                            continue
                            ;;
                    esac
                fi

                if [ "${NEW_VALUE[*]}" == "${CURRENT_VALUE[*]}" ]; then
                    break
                fi

                if [[ $TYPE == "$NUMBER" && ! "${NEW_VALUE[*]}" =~ ^[0-9]+$ ]]; then
                    notify msg "This field should contain only numbers."
                    continue
                fi

                if UPDATED_OPTIONS=$(
                    jq -e \
                        --arg SELECTED_OPTION "$SELECTED_OPTION" \
                        --arg TYPE "$TYPE" \
                        --arg STRING "$STRING" \
                        --arg NUMBER "$NUMBER" \
                        --arg BOOLEAN "$BOOLEAN" '
                        map(
                            .key as $KEY |
                            .patchName as $PATCH_NAME |
                            if ($SELECTED_OPTION | fromjson | .key == $KEY and .patchName == $PATCH_NAME) then
                                .value |= (
                                    $ARGS.positional |
                                    if length == 0 then
                                        null
                                    elif length == 1 then
                                        if $TYPE == $BOOLEAN then
                                            .[0] | toboolean
                                        elif $TYPE == $NUMBER then
                                            .[0] | tonumber
                                        elif $TYPE == $STRING then
                                            .[0] | tostring
                                        else
                                            .
                                        end
                                    else
                                        .
                                    end
                                )
                            else
                                .
                            end
                        )
                    ' --args "${NEW_VALUE[@]}" <<< "$OPTIONS_JSON" 2> /dev/null
                ); then
                    OPTIONS_JSON="$UPDATED_OPTIONS"
                fi
                break
            done
            unset CURRENT_VALUE TYPE DESCRIPTION VALUES ALLOWED_VALUES SELECTED_OPTION NEW_VALUE UPDATED_OPTIONS
        fi
    done

    UPDATED_PATCHES=$(jq -c \
        --arg PKG_NAME "$PKG_NAME" \
        --argjson ENABLED_PATCHES "$ENABLED_PATCHES" '
            . as $OPTIONS_JSON |
            $ENABLED_PATCHES |
            map(
                if .pkgName == $PKG_NAME then
                    .options |= $OPTIONS_JSON
                else
                    .
                end
            )
        ' <<< "$OPTIONS_JSON")

    echo "$UPDATED_PATCHES" > "$STORAGE/$SOURCE-patches.json"

    ENABLED_PATCHES="$UPDATED_PATCHES"
}
