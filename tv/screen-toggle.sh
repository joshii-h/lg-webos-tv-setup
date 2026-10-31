#!/bin/sh
# Picture off/on (sound keeps playing). Meant for an LG Input Hook "exec" binding.
# luna-send sometimes prints nothing without a terminal -> give it a pty via script.
L=luna://com.webos.service.tvpower/power
ls_tty(){ script -qc "luna-send -n 1 -w 3000 $1 '{}'" /dev/null 2>/dev/null; }
if ls_tty $L/getPowerState | grep -q "Screen Off"; then
  ls_tty $L/turnOnScreen >/dev/null
else
  ls_tty $L/turnOffScreen >/dev/null
fi
