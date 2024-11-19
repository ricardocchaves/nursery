#!/bin/sh
# Splits a full log file into multiple files, one per component.

DEST_FOLDER_SUFIX="_split"

print_usage() {
    echo "USAGE: $0 <src_log_file>"
}

main() {
    SRC_LOG=$1
    DEST_FOLDER="$SRC_LOG"$DEST_FOLDER_SUFIX
    echo "Saving logs to "$DEST_FOLDER"/"
    mkdir -p $DEST_FOLDER

    # Go line by line, grep ID, write to different files
    while read -r line; do
        APP=$(echo $line | awk -F'[][]' '{print $3}' | sed 's/^ *//' | awk -F':' '{print $1}')
        if [ -z "$APP" ]; then
            APP="empty"
        fi
        APP=$(basename $APP) # cases where APP like /etc/nexar/usb_autosuspend_off.sh

        echo "$line" >> "${DEST_FOLDER}/${APP}.log"
    done < "$SRC_LOG"

    echo "Done!"
}

if [ $# -ne 1 ]; then
    print_usage
    exit 1
fi

main "$@"
