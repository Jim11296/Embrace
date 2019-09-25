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

# ----------------------------------

show_notification ()
{
    osascript -e "display notification \"$1\" with title \"Archiving ${BUILD_STRING}\""
}

TMP_DIR=`mktemp -d /tmp/Embrace-Archive.XXXXXX`

# 1. Export archive to tmp location and set APP_FILE, push to parent directory
mkdir -p "${TMP_DIR}"
defaults write "${TMP_DIR}/options.plist" method developer-id
defaults write "${TMP_DIR}/options.plist" teamID "$TEAM_ID"

echo "$ARCHIVE_PATH|$FULL_PRODUCT_NAME" > "${TMP_DIR}/Log"

xcodebuild -exportArchive -archivePath "${ARCHIVE_PATH}" -exportOptionsPlist "${TMP_DIR}/options.plist" -exportPath "${TMP_DIR}"

APP_FILE=$(find "${TMP_DIR}" -name "$FULL_PRODUCT_NAME" | head -1)

BUILD_NUMBER=$(echo -n $(defaults read "$APP_FILE"/Contents/Info.plist CFBundleVersion | sed 's/\s//g' ))
BUILD_STRING="${APP_NAME}-${BUILD_NUMBER}"

pushd "$APP_FILE"/.. > /dev/null


# 2. Zip up $APP_FILE to "App.zip" and upload to notarization server

zip --symlinks -r App.zip $(basename "$APP_FILE")

show_notification "Uploading to Apple notary service."

NOTARY_UUID=$(
    xcrun altool --notarize-app \
    --file App.zip --type osx \
    --primary-bundle-id "$NOTARY_BUNDLE_ID" \
    --username "$NOTARY_APPLE_ID" \
    --password "$NOTARY_PASSWORD" \
    --asc_provider "$NOTARY_ASC_PROVIDER" \
    2>&1 | grep RequestUUID | awk '{print $3}'
)


# 3. Wait for notarization

NOTARY_SUCCESS=0

while :
do
show_notification "Waiting for notary response."
    progress=$(xcrun altool --notarization-info "${NOTARY_UUID}" -u "${NOTARY_APPLE_ID}" -p "${NOTARY_PASSWORD}" 2>&1)

    if [ $? -ne 0 ] || [[  "${progress}" =~ "Invalid" ]] ; then
        break
    fi

    if [[  "${progress}" =~ "success" ]]; then
        NOTARY_SUCCESS=1
        break
    fi

    sleep 5
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
