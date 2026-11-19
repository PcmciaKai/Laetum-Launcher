#!/bin/sh
# Print the name of a store icon that the current icon theme (or a theme it
# inherits from, apart from hicolor) draws itself; print nothing if it has none.
# Usage: find-store-icon.sh [theme]
theme=${1:-$(kreadconfig6 --group Icons --key Theme)}
[ -n "$theme" ] || theme=breeze

names="org.gnome.Software-symbolic gnome-software-symbolic plasmadiscover-symbolic"
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
    [ "$current" = hicolor ] && continue
    for base in $bases; do
        dir=$base/$current
        [ -d "$dir" ] || continue
        for name in $names; do
            # size/apps (Breeze), size/symbolic/apps (Papirus), symbolic/apps (Adwaita)
            for f in "$dir"/*/apps/"$name".svg "$dir"/*/symbolic/apps/"$name".svg "$dir"/symbolic/apps/"$name".svg; do
                [ -e "$f" ] && { echo "$name"; exit 0; }
            done
        done
        inherits=$(sed -n 's/^Inherits=//p' "$dir/index.theme" 2>/dev/null | tr ',' ' ')
        queue="$queue $inherits"
    done
done
