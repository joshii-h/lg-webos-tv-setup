#!/bin/sh
# Null LG update, ad and tracking hosts locally (complements webosbrew_block_updates).
# Undo: delete this hook and reboot.
HOSTS="snu.lge.com su.lge.com su-ssl.lge.com nsu.lge.com snu-dev.lge.com su-dev.lge.com ngfts.lge.com
ibs.nextlgsdp.com ibsstat.nextlgsdp.com rdx2.nextlgsdp.com
nudge.lgtvcommon.com recommend.lgtvcommon.com cdpbeacon.lgtvcommon.com rdl.lgtvcommon.com wiseresource.lgtvcommon.com
lggalleryplus.com tv.wiselg.com lgshopsvc.lgappstv.com lgsmartad.com info.lgsmartad.com"
if ! mount | grep -q " on /etc/hosts "; then
    cp /etc/hosts /tmp/hosts && mount --bind /tmp/hosts /etc/hosts || exit 1
fi
grep -q "# lg-block" /etc/hosts && exit 0
echo "# lg-block (webosbrew init.d)" >> /etc/hosts
for h in $HOSTS; do echo "0.0.0.0 $h" >> /etc/hosts; done
