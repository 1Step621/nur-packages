{
  lib,
  writeShellApplication,
  coreutils,
  fuzzel,
  networkmanager,
  gawk,
  gnugrep,
  gnused,
}:
writeShellApplication {
  name = "fuzzel-network";

  runtimeInputs = [
    coreutils
    fuzzel
    networkmanager
    gawk
    gnugrep
    gnused
  ];

  text = ''
    #!/bin/bash
    set -euo pipefail

    FIFO=$(mktemp -u)
    mkfifo "$FIFO"

    fuzzel --dmenu --prompt="Wi-Fi  " < "$FIFO" > /tmp/fuzzel_choice &
    FUZPID=$!

    echo -n "" > "$FIFO"

    IFACE=$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2=="wifi"{print $1; exit}')

    {
        nmcli dev wifi rescan ifname "$IFACE" >/dev/null 2>&1

        CURRENT=$(nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes' | cut -d: -f2)

        nmcli -t -f SSID,SIGNAL dev wifi list 2>/dev/null \
        | awk -F: '!seen[$1]++ && $1 != ""' \
        | while IFS=: read -r ssid signal; do
            if   [ "$signal" -ge 75 ]; then icon="󰤨"
            elif [ "$signal" -ge 50 ]; then icon="󰤥"
            elif [ "$signal" -ge 25 ]; then icon="󰤢"
            else icon="󰤟"
            fi
            [ "$ssid" = "$CURRENT" ] && mark=" ✓" || mark=""
            echo "$icon    $ssid$mark"
        done
    } > "$FIFO"

    wait $FUZPID
    CHOSEN=$(cat /tmp/fuzzel_choice)
    rm -f "$FIFO" /tmp/fuzzel_choice

    [ -z "$CHOSEN" ] && exit 0

    SSID=$(echo "$CHOSEN" | sed 's/^.    //' | sed 's/ ✓$//')

    [ "$SSID" = "$CURRENT" ] && exit 0

    if nmcli con show "$SSID" &>/dev/null; then
        nmcli con up "$SSID"
    else
        sleep 0.5
        PASS=$(fuzzel --dmenu --password --prompt="Password  ")
        nmcli dev wifi connect "$SSID" password "$PASS" ifname "$IFACE"
    fi
  '';

  meta = with lib; {
    description = "A network connection manager for Fuzzel";
    license = licenses.mit;
    mainProgram = "fuzzel-network";
    platforms = platforms.linux;
  };
}
