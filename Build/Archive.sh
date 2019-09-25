#!/bin/sh

TEAM_ID="XXXXXXXXXX"
BUNDLE_ID="com.iccir.Embrace"

NOTARY_APPLE_ID="<redacted>"
NOTARY_ITC_PROVIDER="RicciAdams1115211120"
NOTARY_PASSWORD="<redacted>"

ZIP_PREFIX="Embrace"
ZIP_TO="$HOME/Desktop"
UPLOAD_TO="<redacted>"

# ----------------------------------

TMP_DIR=`mktemp -d /tmp/Embrace-Archive.XXXXXX`

# 1. Export archive to tmp location and set EXPORTED_FILE
mkdir -p "${TMP_DIR}"
defaults write "${TMP_DIR}/options.plist" method developer-id
defaults write "${TMP_DIR}/options.plist" teamID "$TEAM_ID"

xcodebuild -exportArchive -archivePath "${ARCHIVE_PATH}" -exportOptionsPlist "${TMP_DIR}/options.plist" -exportPath "${TMP_DIR}"

APP_FILE=$(find "${TMP_DIR}" -name "$FULL_PRODUCT_NAME" | head -1)


# 2. Push parent of $APP_FILE to directory stack
pushd "$APP_FILE"/.. > /dev/null

# 3. Zip up APP_FILE to "App.zip" and upload to notarization server
zip --symlinks -r App.zip $(basename "$APP_FILE")

xcrun altool --notarize-app \
    --file App.zip --type osx \
    --primary-bundle-id "$NOTARY_BUNDLE_ID" \
    --username "$NOTARY_APPLE_ID" \
    --password "$NOTARY_PASSWORD" \
    -itc_provider "$NOTARY_ITC_PROVIDER" \
    > "${TMP_DIR}/Notary.output"

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
