#!/bin/sh
# Measure available RAM, swap, process count and app launch times.
# Run via ssh -tt (luna-send needs a terminal): sh measure.sh netflix:cold com.webos.app.home:warm
up(){ cut -d' ' -f1 /proc/uptime; }
fg(){ luna-send -n 1 luna://com.webos.applicationManager/getForegroundAppInfo '{}' 2>/dev/null | grep -o '"appId":"[^"]*"' | cut -d'"' -f4; }
launch(){ # $1=appId  $2=cold|warm
  id=$1
  if [ "$2" = cold ]; then luna-send -n 1 luna://com.webos.applicationManager/closeByAppId "{\"id\":\"$id\"}" >/dev/null 2>&1; sleep 3; fi
  t0=$(up)
  luna-send -n 1 luna://com.webos.applicationManager/launch "{\"id\":\"$id\"}" >/dev/null 2>&1
  i=0; while [ "$(fg)" != "$id" ] && [ $i -lt 200 ]; do i=$((i+1)); done
  t1=$(up)
  echo "$id $2: $(awk "BEGIN{printf \"%.2f\", $t1-$t0}") s"
}
echo "MemAvailable: $(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo) MB, Swap belegt: $(awk '/SwapTotal/{t=$2}/SwapFree/{f=$2}END{print int((t-f)/1024)}' /proc/meminfo) MB, Prozesse: $(ls -d /proc/[0-9]* | wc -l)"
for a in "$@"; do launch ${a%%:*} ${a##*:}; done
