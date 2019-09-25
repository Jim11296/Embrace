#!/bin/sh

TEAM_ID="XXXXXXXXXX"

APP_NAME="Embrace"

NOTARY_BUNDLE_ID="com.iccir.Embrace"
NOTARY_APPLE_ID="<redacted>"
NOTARY_ASC_PROVIDER="RicciAdams1115211120"
NOTARY_PASSWORD="<redacted>"

ZIP_TO="$HOME/Desktop"
UPLOAD_TO="<redacted>"
BUILD_STRING=""
#
#ARCHIVE_PATH='/Users/iccir/Library/Developer/Xcode/Archives/2019-09-25/Embrace 2019-09-25, 1.34 AM.xcarchive'
#FULL_PRODUCT_NAME='Embrace.app'

# ----------------------------------

show_notification ()
{
    osascript -e "display notification \"$1\" with title \"Archiving ${BUILD_STRING}\""
}

add_log ()
{
    echo $1 >> "${TMP_DIR}/log.txt"
}

get_plist_build ()
{
    printf $(defaults read "$1" CFBundleVersion | sed 's/\s//g' )
}

TMP_DIR=`mktemp -d /tmp/Embrace-Archive.XXXXXX`

# 1. Export archive to tmp location and set APP_FILE, push to parent directory
mkdir -p "${TMP_DIR}"
defaults write "${TMP_DIR}/options.plist" method developer-id
defaults write "${TMP_DIR}/options.plist" teamID "$TEAM_ID"

xcodebuild -exportArchive -archivePath "${ARCHIVE_PATH}" -exportOptionsPlist "${TMP_DIR}/options.plist" -exportPath "${TMP_DIR}"

APP_FILE=$(find "${TMP_DIR}" -name "$FULL_PRODUCT_NAME" | head -1)

BUILD_NUMBER=$(get_plist_build "$APP_FILE"/Contents/Info.plist)
BUILD_STRING="${APP_NAME}-${BUILD_NUMBER}"

add_log "ARCHIVE_PATH = '$ARCHIVE_PATH'"
add_log "FULL_PRODUCT_NAME = '$FULL_PRODUCT_NAME'"
add_log "BUILD_NUMBER = '$BUILD_NUMBER'"
add_log "BUILD_STRING = '$BUILD_STRING'"
add_log "APP_FILE = '$APP_FILE'"

pushd "$APP_FILE"/.. > /dev/null


# 2. Zip up $APP_FILE to "App.zip" and upload to notarization server

zip --symlinks -r App.zip $(basename "$APP_FILE")

show_notification "Uploading to Apple notary service."

NOTARY_UUID=$(
    xcrun altool \
    --notarize-app --file App.zip --type osx \
    --primary-bundle-id "$NOTARY_BUNDLE_ID" \
    --username "$NOTARY_APPLE_ID" \
    --password "$NOTARY_PASSWORD" \
    --asc-provider "$NOTARY_ASC_PROVIDER" \
    2>&1 | grep RequestUUID | awk '{print $3}'
)


add_log "NOTARY_UUID = '$NOTARY_UUID'"

# 3. Wait for notarization

NOTARY_SUCCESS=0

while true
do
show_notification "Waiting for notary response."
    NOTARY_OUTPUT=$(
        xcrun altool \
        --notarization-info "${NOTARY_UUID}" \
        --username "$NOTARY_APPLE_ID" \
        --password "$NOTARY_PASSWORD" \
        2>&1
    )

    if [ $? -ne 0 ]; then
        add_log "altool --notarization-info returned $?"
    fi

    add_log "${NOTARY_OUTPUT}"
    
    if [[ "${NOTARY_OUTPUT}" =~ "Invalid" ]] ; then
        add_log "altool --notarization-info results invalid"
        break
    fi

    if [[ "${NOTARY_OUTPUT}" =~ "success" ]]; then
        NOTARY_SUCCESS=1
        break
    fi

    sleep 10
done


# 4. Staple

if [ $NOTARY_SUCCESS -eq 1 ] ; then
    xcrun stapler staple "$APP_FILE"

    show_notification "Uploading stapled application."

else
    show_notification "Error during notarization."
fi

#
#
#
#
#
#success=0
#for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
#    echo "Checking progress..."
#    progress=$(xcrun altool --notarization-info "${notarize_uuid}"  -u "${app_store_id}" -p "${app_store_password}" 2>&amp;1 )
#    Echo "${progress}"
# 
#    if [ $? -ne 0 ] || [[  "${progress}" =~ "Invalid" ]] ; then
#        echo "Error with notarization. Exiting"
#        break
#    fi
# 
#    if [[  "${progress}" =~ "success" ]]; then
#        success=1
#        break
#    else
#        echo "Not completed yet. Sleeping for 30 seconds"
#    fi
#    sleep 30
#done

# 4. Poll until we see a "


popd > /dev/null

#
#EXPORTED_FILE
#
#
#
#pushd "$APP_FILE"/.. > /dev/null
#APP_ZIP_FILE="$OPTARG-$build_number.zip"
#zip --symlinks -r "$APP_ZIP_FILE" $(basename "$LAST_FILE")
#LAST_FILE="$APP_ZIP_FILE"
#popd > /dev/null
#
