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
    CURRENT=$(nmcli -t -f ACTIVE,SSID dev wifi | awk -F: '$1=="yes"{print $2}')

    {
        nmcli -t -f SSID,SIGNAL dev wifi list \
        | awk -F: '!seen[$1]++ && $1 != ""' \
        | while IFS=: read -r ssid signal; do
            if   [ "$signal" -ge 75 ]; then icon="󰤨"
            elif [ "$signal" -ge 50 ]; then icon="󰤥"
            elif [ "$signal" -ge 25 ]; then icon="󰤢"
            else icon="󰤟"
            fi

            if [ -n "$CURRENT" ] && [ "$ssid" = "$CURRENT" ]; then
                mark=" ✓"
            else
                mark=""
            fi

            echo "$icon    $ssid$mark"
        done

        echo "󰤭    Disconnect"
        echo "󰑓    Rescan"
    } > "$FIFO" &

    wait $FUZPID
    CHOSEN=$(cat /tmp/fuzzel_choice)
    rm -f "$FIFO" /tmp/fuzzel_choice

    [ -z "$CHOSEN" ] && exit 0

    SSID=$(echo "$CHOSEN" | sed 's/^.    //' | sed 's/ ✓$//')

    if [ "$SSID" = "Disconnect" ]; then
        nmcli con down id "$CURRENT"
        exit 0
    fi

    if [ "$SSID" = "Rescan" ]; then
        fuzzel --dmenu --mesg "Rescanning..." --hide-prompt --lines 0 &
        TMPPID=$!
        nmcli dev wifi list --rescan yes >/dev/null
        kill "$TMPPID"
        $0
        exit 0
    fi

    if nmcli con show "$SSID" &>/dev/null; then
        nmcli con up "$SSID"
    else
        PASS=$(fuzzel --dmenu --password --prompt-only "Password  ")

        [ -z "$PASS" ] && exit 0
        
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
