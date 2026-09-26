#!/bin/sh
set -eu

if [ -n "${AUDIO_PLAYER_HOME:-}" ]; then
    INSTALL_DIR=$AUDIO_PLAYER_HOME
elif [ -x "$(dirname "$0")/audio-player" ]; then
    INSTALL_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
elif [ -d /opt/audio-player ]; then
    INSTALL_DIR=/opt/audio-player
elif [ -d /usr/local/bin/audio-player ]; then
    INSTALL_DIR=/usr/local/bin/audio-player
elif [ -d /mnt/sda1/audio-player ]; then
    INSTALL_DIR=/mnt/sda1/audio-player
elif [ -d "${HOME:-}/audio-player" ]; then
    INSTALL_DIR=$HOME/audio-player
else
    echo "Audio Player не найден. Укажите AUDIO_PLAYER_HOME=/путь/к/установке." >&2
    exit 1
fi

case "$INSTALL_DIR" in
    /*) ;;
    *) echo "Укажите абсолютный путь установки." >&2; exit 1 ;;
esac
case "$INSTALL_DIR" in
    /|/opt|/opt/etc|/etc|/usr|/usr/local|/mnt|/home|/root)
        echo "Отказ: небезопасный путь установки: $INSTALL_DIR" >&2
        exit 1
        ;;
esac

if [ "$(id -u)" -ne 0 ]; then
    echo "Нужна root-консоль устройства; sudo не требуется на Keenetic." >&2
    exit 1
fi

echo "Будут удалены приложение и все данные в $INSTALL_DIR, включая аудио, плейлист и логи."
printf '%s' "Для подтверждения введите yes: "
IFS= read -r CONFIRM || CONFIRM=""
if [ "$CONFIRM" != "yes" ]; then
    echo "Удаление отменено."
    exit 0
fi

ENTWARE_SCRIPT=/opt/etc/init.d/S99audio-player
ENTWARE_CONFIG=/opt/etc/audio-player-install-dir
if [ -f "$ENTWARE_CONFIG" ] && [ "$(cat "$ENTWARE_CONFIG" 2>/dev/null || true)" = "$INSTALL_DIR" ]; then
    if [ -x "$ENTWARE_SCRIPT" ]; then
        "$ENTWARE_SCRIPT" stop >/dev/null 2>&1 || true
        rm -f "$ENTWARE_SCRIPT"
    fi
    rm -f "$ENTWARE_CONFIG"
fi

if command -v systemctl >/dev/null 2>&1 && [ -f /etc/systemd/system/audio-player.service ]; then
    systemctl stop audio-player >/dev/null 2>&1 || true
    systemctl disable audio-player >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/audio-player.service
    systemctl daemon-reload >/dev/null 2>&1 || true
fi

if [ -f /etc/init.d/audio-player ]; then
    /etc/init.d/audio-player stop >/dev/null 2>&1 || true
    rm -f /etc/init.d/audio-player
fi

if command -v crontab >/dev/null 2>&1; then
    CURRENT_CRONTAB=$(crontab -l 2>/dev/null || true)
    if printf '%s\n' "$CURRENT_CRONTAB" | grep -F "$INSTALL_DIR/audio-player" >/dev/null 2>&1; then
        printf '%s\n' "$CURRENT_CRONTAB" | grep -Fv "$INSTALL_DIR/audio-player" | crontab -
    fi
fi

if [ -f "$INSTALL_DIR/audio-player.pid" ]; then
    PID=$(cat "$INSTALL_DIR/audio-player.pid" 2>/dev/null || true)
    case "$PID" in
        ''|*[!0-9]*) ;;
        *)
            kill "$PID" 2>/dev/null || true
            sleep 1
            kill -9 "$PID" 2>/dev/null || true
            ;;
    esac
fi
pkill -f "$INSTALL_DIR/audio-player" 2>/dev/null || true

rm -f "$INSTALL_DIR/audio-player.pid"
rm -rf "$INSTALL_DIR"
echo "Audio Player удалён."
