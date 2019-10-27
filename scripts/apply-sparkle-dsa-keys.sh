set -o errexit

[ "$BUILD_STYLE" = "Deployment" ] || [ "$CONFIGURATION" = "Deployment" ] || { echo Distribution target requires "'Deployment'" build style; false; }

if [[ -z "${PROJECT_NAME}" ]]; then
  PROJECT_NAME="LaTeXiT"
fi
if [[ "${PROJECT_NAME}" != "LaTeXiT" ]]; then
  PROJECT_NAME="LaTeXiT"
fi

VERSION=$(defaults read "$BUILT_PRODUCTS_DIR/$PROJECT_NAME.app/Contents/Info" CFBundleShortVersionString)
DOWNLOAD_BASE_URL="https://pierre.chachatelier.fr/latexit/downloads"
RELEASENOTES_URL="https://pierre.chachatelier.fr/latexit/downloads/latexit-changelog-fr.html#version-$VERSION"

VERSION=$(defaults read "${BUILT_PRODUCTS_DIR}/${PROJECT_NAME}.app/Contents/Info" CFBundleShortVersionString)
VERSION2=`echo "${VERSION}" | sed "s/\\./_/g" | sed "s/\\ /-/g"`
echo "VERSION=<$VERSION>, VERSION2=<$VERSION2>"
VOLNAME="LaTeXiT ${VERSION}"
DMGNAME="${PROJECT_NAME}-${VERSION2}"
SPARSEPATH="${BUILT_PRODUCTS_DIR}/${DMGNAME}.sparseimage"
DMGPATH="${BUILT_PRODUCTS_DIR}/${DMGNAME}.dmg"
#ARCHIVE_FILENAME="$PROJECT_NAME $VERSION.zip"
ARCHIVE_FILENAME="${DMGNAME}.dmg"
ARCHIVE_FILEPATH="${BUILT_PRODUCTS_DIR}/${DMGNAME}.dmg"
DOWNLOAD_URL="$DOWNLOAD_BASE_URL/$ARCHIVE_FILENAME"
KEYCHAIN_PRIVKEY_NAME="Sparkle LaTeXiT keys private"
echo "ARCHIVE_FILEPATH = $ARCHIVE_FILEPATH"

WD=$PWD

#cd "$BUILT_PRODUCTS_DIR"
#rm -f "$PROJECT_NAME"*.zip
#zip -qr "$ARCHIVE_FILENAME" "$PROJECT_NAME.app"

SIZE=$(stat -f %z "${ARCHIVE_FILEPATH}")
PUBDATE=$(date +"%a, %d %b %G %T %z")
PRIKEYFILE="key.pri"
security find-generic-password -g -s "$KEYCHAIN_PRIVKEY_NAME" 2>&1 1>/dev/null | perl -pe '($_) = /"(.+)"/; s/\\012/\n/g' > $PRIKEYFILE
cat $PRIKEYFILE
SIGNATURE=$(openssl dgst -sha1 -binary "${ARCHIVE_FILEPATH}" | openssl dgst -dss1 -sign "$PRIKEYFILE" | openssl enc -base64)
rm -f $PRIKEYFILE

[ $SIGNATURE ] || { echo Unable to load signing private key with name "'$KEYCHAIN_PRIVKEY_NAME'" from keychain; false; }

cat <<EOF
		<item>
			<title>Version $VERSION</title>
			<sparkle:releaseNotesLink>$RELEASENOTES_URL</sparkle:releaseNotesLink>
			<pubDate>$PUBDATE</pubDate>
			<enclosure
				url="$DOWNLOAD_URL"
				sparkle:version="$VERSION"
                   sparkle:shortVersionString="$VERSION"
				type="application/octet-stream"
				length="$SIZE"
				sparkle:dsaSignature="$SIGNATURE"
			/>
		</item>
EOF

cat <<EOF > "${BUILT_PRODUCTS_DIR}/sparkle.rss.part"
		<item>
			<title>Version $VERSION</title>
			<sparkle:releaseNotesLink>$RELEASENOTES_URL</sparkle:releaseNotesLink>
			<pubDate>$PUBDATE</pubDate>
			<enclosure
				url="$DOWNLOAD_URL"
				sparkle:version="$VERSION"
                   sparkle:shortVersionString="$VERSION"
				type="application/octet-stream"
				length="$SIZE"
				sparkle:dsaSignature="$SIGNATURE"
			/>
		</item>
EOF
