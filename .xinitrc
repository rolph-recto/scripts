xsetroot -cursor_name left_ptr
eval `dbus-launch --auto-syntax`

xscreensaver -no-splash &

xrandr --newmode "2560x1440x50" 256.25  2560 2736 3008 3456  1440 1443 1448 1484 -hsync +vsync
xrandr --addmode HDMI1 2560x1440x50

xrandr --newmode "1920x1080x60"  172.80  1920 2040 2248 2576  1080 1081 1084 1118  -HSync +Vsync
xrandr --addmode DP2 1920x1080x60

# trayer --edge top --align left --SetDockType true --SetPartialStrut true --expand true --width 11 --widthtype percent --transparent true --tint 0x000000 --alpha 80 --height 25 --monitor primary &
# maybe should be --monitor 0 ? idk

trayer --edge top --align left --SetDockType true --SetPartialStrut true --expand true --width 11 --widthtype percent --transparent true --tint 0x000000 --alpha 80 --height 25 --monitor 0 &

volumeicon &
fdpowermon &
nm-applet &

setxkbmap -option ctrl:nocaps
cadence-session-start --system-start

# if there's an HDMI1 connection, set it to the right
if xrandr | grep "HDMI1 connected"; then
  xrandr --output HDMI1 --right-of eDP1 --mode 1920x1200
fi


if xrandr | grep "DP2 connected"; then
  xrandr --output DP2 --right-of eDP1 --mode 1920x1080x60
fi

feh --bg-fill ~/pictures/wallpaper/brueghel-hunters-in-the-snow.jpg &

exec xmonad
