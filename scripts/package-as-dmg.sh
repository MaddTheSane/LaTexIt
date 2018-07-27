#!/bin/sh
if [[ -z "${PROJECT_DIR}" ]]; then
  PROJECT_DIR="/Users/chacha/Programmation/Cocoa/Projets/Applications/LaTeXiT-mainline"
fi
if [[ -z "${BUILT_PRODUCTS_DIR}" ]]; then
  BUILT_PRODUCTS_DIR="/Volumes/Snow Leopard/Users/chacha/Temporary/XCode/Deployment"
fi
if [[ -z "${PROJECT_NAME}" ]]; then
  PROJECT_NAME="LaTeXiT"
fi

VERSION=$(defaults read "${BUILT_PRODUCTS_DIR}/${PROJECT_NAME}.app/Contents/Info" CFBundleShortVersionString)
VERSION2=`echo "${VERSION}" | sed "s/\\./_/g" | sed "s/\\ /-/g"`
echo "VERSION=<$VERSION>, VERSION2=<$VERSION2>"
VOLNAME="LaTeXiT ${VERSION}"
DMGNAME="${PROJECT_NAME}-${VERSION2}"
SPARSEPATH="${BUILT_PRODUCTS_DIR}/${DMGNAME}.sparseimage"
DMGPATH="${BUILT_PRODUCTS_DIR}/${DMGNAME}.dmg"
hdiutil create -fs HFS+ -ov -type SPARSE -volname "${VOLNAME}" -fsargs "-c c=64,a=16,e=16" "${SPARSEPATH}"
hdiutil attach "${SPARSEPATH}"

ditto "${BUILT_PRODUCTS_DIR}/${PROJECT_NAME}.app" "/Volumes/${VOLNAME}/${PROJECT_NAME}.app"
ditto "${PROJECT_DIR}/Resources/documentation/Licence.rtf" "/Volumes/${VOLNAME}/Licence.rtf"
ditto "${PROJECT_DIR}/Resources/documentation/Licence_CeCILL_V2-fr.txt" "/Volumes/${VOLNAME}/Licence_CeCILL_V2-fr.txt"
ditto "${PROJECT_DIR}/Resources/documentation/Licence_CeCILL_V2-en.txt" "/Volumes/${VOLNAME}/Licence_CeCILL_V2-en.txt"
ditto "${PROJECT_DIR}/Resources/documentation/Lisez-moi.rtfd" "/Volumes/${VOLNAME}/Lisez-moi.rtfd"
ditto "${PROJECT_DIR}/Resources/documentation/Read Me.rtfd" "/Volumes/${VOLNAME}/Read Me.rtfd"
ditto "${PROJECT_DIR}/Resources/documentation/Lies mich.rtfd" "/Volumes/${VOLNAME}/Lies mich.rtfd"
ditto "${PROJECT_DIR}/Resources/documentation/Léeme.rtfd" "/Volumes/${VOLNAME}/Léeme.rtfd"

osascript -e 'tell application "Finder"' -e "make new alias to folder (posix file \"/Applications\") at folder (posix file \"/Volumes/${VOLNAME}\")" -e 'end tell'

hdiutil detach "/Volumes/${VOLNAME}"
hdiutil compact "${SPARSEPATH}"
SECTORS=`hdiutil resize "${SPARSEPATH}" | cut -f 1`
hdiutil resize -sectors "${SECTORS}" "${SPARSEPATH}"
hdiutil convert -imagekey zlib-level=9 -format UDZO -ov "${SPARSEPATH}" -o "${DMGPATH}"
rm -rf "${SPARSEPATH}"
