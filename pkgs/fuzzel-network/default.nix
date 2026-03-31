{
  lib,
  writeShellApplication,
  coreutils,
  slurp,
  wf-recorder,
}:
writeShellApplication {
  name = "fuzzel-network";

  runtimeInputs = [
    coreutils
  ];

  text = ''
    #!/bin/bash

    set -euo pipefail

    CURRENT=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)

    NETWORKS=$(nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null \
        | awk -F: '!seen[$1]++ && $1 != ""' \
        | while IFS=: read -r ssid signal _security; do
            if   [ "$signal" -ge 75 ]; then icon="󰤨"
            elif [ "$signal" -ge 50 ]; then icon="󰤥"
            elif [ "$signal" -ge 25 ]; then icon="󰤢"
            else icon="󰤟"
            fi
            [ "$ssid" = "$CURRENT" ] && mark=" ✓" || mark=""
            echo "$icon    $ssid$mark"
        done)

    OPTIONS="$NETWORKS
    󰤭    切断する"

    CHOSEN=$(echo "$OPTIONS" | fuzzel --dmenu --prompt="Wi-Fi  ")

    SSID=$(echo "$CHOSEN" | sed 's/^.    //' | sed 's/ ✓$//')

    [ -z "$CHOSEN" ] && exit 0

    if [ "$SSID" = "切断する" ]; then
        nmcli dev disconnect wlan0
        exit 0
    fi

    if nmcli con show "$SSID" &>/dev/null; then
        nmcli con up "$SSID"
    else
        PASS=$(echo "" | fuzzel --dmenu --prompt="Password for $SSID  ")
        nmcli dev wifi connect "$SSID" password "$PASS"
    fi
  '';

  meta = with lib; {
    description = "A network connection manager for Fuzzel";
    license = licenses.mit;
    mainProgram = "fuzzel-network";
    platforms = platforms.linux;
  };
}
