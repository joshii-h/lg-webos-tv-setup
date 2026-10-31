# lg-webos-tv-setup

How I turned a rooted LG OLED (B4, 2024, webOS 25 / starfish 10.3.2) into a lean,
ad-free TV with a fast custom launcher, remapped remote buttons and no LG telemetry.
Everything is reversible and nothing touches the firmware partitions.

This is a write-up of one real setup, not a one-click installer. Read each step,
check it against your own TV, and keep a way back.

| Before | After |
|---|---|
| LG Home with ad banner, "recommended" shelves, ~142 system apps | [Luma](https://github.com/ecklf/lg-luma) as Home: wallpaper, your apps, nothing else |
| ~435 MB RAM available, ~370 MB swapped | ~510–600 MB available, ~100–190 MB swapped |
| Prime / Disney+ / Rakuten / LG Channels / Alexa buttons | Prime → YouTube, others → your apps, Alexa → picture off |
| YouTube with ads | YouTube AdFree + SponsorBlock, multiple accounts |

Numbers come from `tv/measure.sh` on this TV; yours will differ.

## Requirements

- A rooted LG webOS TV with [Homebrew Channel](https://www.webosbrew.org/)
  (check [CanI.RootMy.TV](https://cani.rootmy.tv/)). Rooting is not covered here.
- SSH enabled in Homebrew Channel, your public key in `/home/root/.ssh/authorized_keys`.
- A computer with `ssh`; for the helpers also ImageMagick and Python 3 with Pillow + NumPy.

An `~/.ssh/config` entry keeps commands short:

```
Host tv
    HostName 192.168.1.63
    User root
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

## Ground rules

- **Back up first.** At least `/var/luna/preferences`, `/var/lib`, `/home/root`,
  `/media/developer` and `/var/preferences/com.webos.applicationManager`.
  The Wi-Fi link can be slow (~0.2 MB/s on 2.4 GHz); compress on the TV
  (`tar … | gzip -1`) instead of imaging whole partitions.
- **Never write to firmware partitions** (rootfs, kernel, tvservice).
- **One change at a time, then reboot and re-check.** Undo before moving on.
- Keep the TV awake while working (`general/screenSaverEnabled=off`,
  `time/automaticStandBy=0`) and restore your values afterwards.

## Pitfalls worth knowing first

- **`luna-send` sometimes prints nothing** over a plain `ssh tv '…'`
  (return code 0, empty output). Use `ssh -tt tv '…; exit'`, or inside scripts
  wrap it: `script -qc "luna-send …" /dev/null`.
- **Never set `lastInputApp` / `physicalLastInputApp` to `com.webos.app.home`.**
  It looks like the obvious way to boot straight into Home, but afterwards Home
  could not be launched at all (SAM logs `NL_APP_LAUNCH_BEGIN`, no process
  appears, black screen, also with stock LG Home). Restoring
  `com.webos.app.livetv` plus a reboot fixed it. `systemctl restart sam` hung.
- **The system app block list is partly rewritten at boot.** Some IDs (Sport,
  LG Gallery+, Music, Home Office, Learning) were dropped again after a reboot.
  Hide those in the launcher instead.
- **Luma's `home.sh enable` asks y/n.** Non-interactive: `echo y | sh home.sh enable`.
- **Luma and a modified LG Home don't mix.** Luma refuses to take over while any
  other bind mount sits on or below `/usr/palm/applications/com.webos.app.home`.
- **Cold boot:** Homebrew `init.d` hooks run ~50 s into boot, so Live TV / LG Home
  shows briefly before Luma takes over. Turn on **Quick Start+**
  (`option/quickStartMode=on`) and the TV resumes straight into Luma.

## 1. Block firmware updates and LG telemetry

An update can remove root, and current firmware usually can't be re-rooted.

1. Turn off automatic updates in the LG menu.
2. Homebrew Channel → Settings → **Block system updates**
   (sets `/var/luna/preferences/webosbrew_block_updates`).
3. Add [`tv/block-lg-hosts.sh`](tv/block-lg-hosts.sh) as a boot hook. It nulls LG
   update, ad and tracking hosts in `/etc/hosts` via a bind mount:

   ```sh
   ssh tv 'mkdir -p /media/developer/customhome'
   scp -O tv/block-lg-hosts.sh tv:/media/developer/customhome/
   ssh tv 'chmod +x /media/developer/customhome/block-lg-hosts.sh &&
     ln -sf /media/developer/customhome/block-lg-hosts.sh /var/lib/webosbrew/init.d/20-block-lg-hosts'
   ```

   Do **not** block `lgtvsdp.com` / `lgappstv.com` (Content Store) or
   `lgsmartweb.com` (voice search).
4. Network-wide, a DNS filter (AdGuard Home, Pi-hole) with HaGeZi/OISD lists
   already blocks most of these. If your router has a second public DNS server
   as fallback, check that it filters too: mine answered from the unfiltered
   fallback and LG traffic slipped through.
5. Disable telnet in Homebrew Channel once SSH key login works.

## 2. Turn off ads, recommendations and ACR

[lucataco's webos-debloat.sh](https://gist.github.com/lucataco/7c303b443934008a9031a55cfca552ec)
does this reversibly (block list, preload policy, a few settings). Always start
with `--plan` and `--dry-run`.

```sh
scp -O webos-debloat.sh tv:/media/developer/customhome/
ssh -tt tv 'sh /media/developer/customhome/webos-debloat.sh --plan; exit'
ssh -tt tv 'sh /media/developer/customhome/webos-debloat.sh --apply --only sdk,remote; exit'
ssh -tt tv 'sh /media/developer/customhome/webos-debloat.sh --settings-off; exit'   # promos, sports alerts, Live Plus
ssh -tt tv 'sh /media/developer/customhome/webos-debloat.sh --preload-off; exit'
```

[`tv/debloat-ids.txt`](tv/debloat-ids.txt) lists every extra ID I hid
(`--id <id>` per entry). I kept `com.webos.app.cmp-client` (consent management)
and `com.webos.app.renewupdate` (recovery flow) on purpose.

## 3. Luma as Home

[Luma](https://github.com/ecklf/lg-luma) is a native launcher (Rust/SDL), confirmed
on several webOS 25 TVs. It never changes system settings and falls back to LG Home
if the takeover fails.

```sh
# install (verify sha256 from the release first)
scp -O com.ecklf.luma_*_arm.ipk tv:/tmp/luma.ipk
ssh -tt tv 'luna-send -i luna://com.webos.appInstallService/dev/install \
  "{\"id\":\"com.ecklf.luma\",\"ipkUrl\":\"/tmp/luma.ipk\",\"subscribe\":true}"'

# take over the Home button (adds init.d/64-luma-home)
ssh -tt tv 'echo y | sh /media/developer/apps/usr/palm/applications/com.ecklf.luma/home.sh enable; exit'
ssh tv 'sh /var/lib/luma-home/home.sh status'

# undo
ssh tv 'sh /var/lib/luma-home/home.sh disable'
```

Settings live in `/media/developer/com.ecklf.luma/preferences.json`
([example](tv/luma/preferences.example.json)): `favorites` order, `hidden` apps,
`input_modes` (`"com.webos.app.hdmi3": "Off"` hides an input), `hour_24`, weather.
Edit only while Luma/Home is closed, keep owner and mode (`600`), validate the JSON.
A broken file silently resets Luma to defaults.

### Your own wallpaper without the phone upload

Luma takes exactly 1920×1080 (the TV's UI plane is 1080p anyway; only video is 4K):

```sh
pc/make-luma-wallpaper.py ~/Pictures/wall.jpg /tmp/wp     # prints custom-<id>
scp -O -r /tmp/wp/custom-<id> tv:/media/developer/com.ecklf.luma/wallpapers/
# then on the TV: chown -R to the owner of preferences.json, chmod 600 the files,
# set "background": "custom-<id>" while Luma is closed
```

### Alternative: slim down LG's own Home

Before Luma I stripped the stock Flutter Home with a bind-mounted `home.xml`
(no hero banner, no Q-cards, no recommendation shelf) based on
[mareklarek/webos10-homescreen-customization](https://github.com/mareklarek/webos10-homescreen-customization).
See [`tv/lg-home-classic/`](tv/lg-home-classic/). Do not combine it with Luma.

## 4. Remote buttons

[LG Input Hook](https://github.com/Simon34545/lginputhook) (Homebrew repo) remaps
buttons. Web UI on `http://<tv-ip>:1842/`, config in
`/home/root/.config/lginputhook/keybinds.json` ([mine](tv/inputhook/keybinds.json)).

The keys are the **`uinput_code`** from the log, not the `keyid`. On the MR24 remote:

| Button | uinput_code | Mapped to |
|---|---|---|
| Netflix | 1037 | unchanged |
| Prime Video | 1038 | YouTube |
| Disney+ | 1042 | Nebula |
| LG Channels | 1043 | Jellyfin |
| Rakuten TV | 1044 | Zattoo |
| Alexa | 1086 | [`screen-toggle.sh`](tv/screen-toggle.sh): picture off/on, sound keeps playing |

Leave the Home button alone when Luma owns it.

## 5. YouTube without ads

[YouTube AdFree](https://github.com/webosbrew/youtube-webos) (Homebrew repo)
uses the same app ID as the official app, so uninstall the official one first
(`luna-send -i luna://com.webos.appInstallService/remove '{"id":"youtube.leanback.v4","subscribe":true}'`).
Accounts need to sign in again; several accounts work as usual. Because it is
installed under `/media/developer`, the LG store does not update it.

## Helpers

- [`tv/measure.sh`](tv/measure.sh): available RAM, swap, process count and launch times
  (`ssh -tt tv 'sh measure.sh netflix:cold com.webos.app.home:warm; exit'`).
- [`pc/tvshot`](pc/tvshot): screenshot via LG's capture service. Unlike a VNC
  capture tool, this doesn't kick other VNC clients off.

## Credits

[webosbrew / Homebrew Channel](https://www.webosbrew.org/),
[Luma](https://github.com/ecklf/lg-luma),
[webos-debloat](https://gist.github.com/lucataco/7c303b443934008a9031a55cfca552ec),
[LG Input Hook](https://github.com/Simon34545/lginputhook),
[YouTube AdFree](https://github.com/webosbrew/youtube-webos),
[webos10-homescreen-customization](https://github.com/mareklarek/webos10-homescreen-customization),
[Level1Techs LG block list](https://forum.level1techs.com/t/lg-tv-block-mini-how-to/255178).

## License

MIT, see [LICENSE](LICENSE). Use at your own risk; you are modifying your own TV.
