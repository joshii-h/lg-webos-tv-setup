#!/bin/sh
# Slim LG Home with a custom banner image: bind-mounts modified assets over the
# stock Flutter Home. Originals stay untouched. Expects home.xml and optional
# bg/{hd,2k,4k}.png (banner sizes 1180x601 / 1770x902 / 3540x1803) in $SRC.
# Undo: remove the init.d symlink and reboot.
ASSETS=/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets
SRC=/media/developer/customhome
M=/tmp/weboshome-merged
umount "$ASSETS" 2>/dev/null
rm -rf "$M"
mkdir "$M" || exit 1
cp -a "$ASSETS"/. "$M"/ || exit 1
cp "$SRC/home.xml" "$M/home.xml" || exit 1
# banner image
for r in hd 2k 4k; do
    [ -f "$SRC/bg/$r.png" ] && cp "$SRC/bg/$r.png" "$M/images/$r/bg_banner_img.png"
done
# blank the banner texts (i18n is a symlink -> make a real copy)
if [ -L "$M/i18n" ]; then
    I=$(readlink "$M/i18n"); rm "$M/i18n"; cp -a "$I" "$M/i18n" || exit 1
fi
for f in "$M"/i18n/*.json; do
    sed -i -e 's/"Start a new experience with webOS\.": *"[^"]*"/"Start a new experience with webOS.": ""/' \
           -e 's/"Go to Apps": *"[^"]*"/"Go to Apps": ""/' "$f"
done
mount --bind "$M" "$ASSETS"
pkill -f "flutter-client -i com.webos.app.home" || true
