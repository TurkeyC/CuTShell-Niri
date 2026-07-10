#!/bin/sh

socket="/tmp/niri_celestia_mpv.sock"


# Check if socket exists before using it
if [ -S "$socket" ]; then
  (
    echo '{ "command": ["script-message-to", "niri_celestia", "osc-hide"] }'
    echo '{ "command": ["script-message-to", "niri_celestia", "menu-toggle", "playlist" ] }'
    ) | socat - "$socket" > /dev/null 2>&1
  else
    echo "mpv socket not found"
fi
