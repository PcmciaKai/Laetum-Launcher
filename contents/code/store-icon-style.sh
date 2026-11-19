#!/bin/sh
# Print "filled" when the current icon theme is Papirus or builds on it (its icons
# are solid, so the filled store bag matches); print nothing otherwise (Breeze and
# other line-style themes, which get the outline bag).
# Usage: store-icon-style.sh [theme]
theme=${1:-$(kreadconfig6 --group Icons --key Theme)}
[ -n "$theme" ] || theme=breeze

bases="${XDG_DATA_HOME:-$HOME/.local/share}/icons $HOME/.icons /usr/local/share/icons /usr/share/icons"

queue=$theme
seen=" "
while [ -n "$queue" ]; do
    set -- $queue
    current=$1
    shift
    queue=$*
    case "$seen" in *" $current "*) continue ;; esac
    seen="$seen$current "
    case "$current" in
        Papirus* | ePapirus*) echo filled; exit 0 ;;
        hicolor) continue ;;
    esac
    for base in $bases; do
        [ -f "$base/$current/index.theme" ] || continue
        queue="$queue $(sed -n 's/^Inherits=//p' "$base/$current/index.theme" | tr ',' ' ')"
    done
done
