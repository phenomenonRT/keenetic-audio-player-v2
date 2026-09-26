#!/bin/sh
set -eu

REPOSITORY="phenomenonRT/keenetic-audio-player-v2"
RAW_BASE="https://raw.githubusercontent.com/${REPOSITORY}/main"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/keenetic-audio-player-install.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' 0

if ! command -v curl >/dev/null 2>&1; then
    echo "Ошибка: для установки нужен curl." >&2
    exit 1
fi

if ! curl -fsSL --retry 3 "${RAW_BASE}/install.sh" -o "${TMP_DIR}/install.sh"; then
    echo "Ошибка: не удалось скачать установщик из GitHub." >&2
    exit 1
fi

sh "${TMP_DIR}/install.sh" "$@"
