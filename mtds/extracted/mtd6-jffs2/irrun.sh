#!/bin/sh

# AK3918 camera-specific IR day/night controller.
# Times are local 24-hour time (HH:MM).
DAY_H=5
DAY_M=30
NIGHT_H=19
NIGHT_M=30
CHECK_INTERVAL=300
STATE_FILE="/tmp/ir_mode_state"

IR_LED="/sys/user-gpio/IR_LED"
WHITE_LED="/sys/user-gpio/WHITE_LED"
IRCUT="/sys/user-gpio/gpio-ircut_a"

set_gpio()
{
    FILE="$1"
    VALUE="$2"
    [ -e "$FILE" ] || return

    CURRENT=$(cat "$FILE" 2>/dev/null)
    if [ "$CURRENT" != "$VALUE" ]; then
        echo "$VALUE" > "$FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') set $FILE=$VALUE"
    fi
}

set_day_mode()
{
    echo "$(date '+%Y-%m-%d %H:%M:%S') Switching to DAY mode"
    set_gpio "$IR_LED" 0
    set_gpio "$WHITE_LED" 0
    # IR-cut filter engaged.
    set_gpio "$IRCUT" 0
    echo "day" > "$STATE_FILE"
}

set_night_mode()
{
    echo "$(date '+%Y-%m-%d %H:%M:%S') Switching to NIGHT mode"
    # Both LED banks contain IR LEDs on this camera.
    set_gpio "$IR_LED" 1
    set_gpio "$WHITE_LED" 1
    # IR-cut filter removed.
    set_gpio "$IRCUT" 1
    echo "night" > "$STATE_FILE"
}

while true
do
    NOW_H=$(date +%H)
    NOW_M=$(date +%M)

    NOW_H=$(expr "$NOW_H" + 0)
    NOW_M=$(expr "$NOW_M" + 0)

    NOW_MIN=$(expr "$NOW_H" \* 60 + "$NOW_M")
    DAY_MIN=$(expr "$DAY_H" \* 60 + "$DAY_M")
    NIGHT_MIN=$(expr "$NIGHT_H" \* 60 + "$NIGHT_M")

    CURRENT_STATE=""
    [ -f "$STATE_FILE" ] && CURRENT_STATE=$(cat "$STATE_FILE")

    if [ "$NOW_MIN" -lt "$DAY_MIN" ] || [ "$NOW_MIN" -ge "$NIGHT_MIN" ]; then
        [ "$CURRENT_STATE" = "night" ] || set_night_mode
    else
        [ "$CURRENT_STATE" = "day" ] || set_day_mode
    fi

    sleep "$CHECK_INTERVAL"
done
