#!/bin/sh

# 🎵 Keenetic Audio Player - Инсталлятор
# Быстрая автоматическая установка без лишних вопросов

set -e

# Переменные
INSTALL_DIR=""
MEDIA_DIR=""
CONFIG_FILE=""
EXECUTABLE=""
INTERACTIVE=0
NETWORK_INTERFACE="${AUDIO_PLAYER_INTERFACE:-auto}"
APP_PORT="${AUDIO_PLAYER_PORT:-8181}"
BIND_ADDR="${AUDIO_PLAYER_BIND:-0.0.0.0}"
OS_TYPE=$(uname -s)
ARCH=$(uname -m)

while [ $# -gt 0 ]; do
    case "$1" in
        -i|--interactive)
            INTERACTIVE=1
            shift
            ;;
        --interface|-if)
            NETWORK_INTERFACE="$2"
            shift 2
            ;;
        --interface=*)
            NETWORK_INTERFACE="${1#*=}"
            shift
            ;;
        --port|-p)
            APP_PORT="$2"
            shift 2
            ;;
        --port=*)
            APP_PORT="${1#*=}"
            shift
            ;;
        --bind)
            BIND_ADDR="$2"
            shift 2
            ;;
        --bind=*)
            BIND_ADDR="${1#*=}"
            shift
            ;;
        -h|--help)
            echo "Использование: $0 [опции]"
            echo "  -i, --interactive            Интерактивный выбор параметров установки"
            echo "  --interface <iface>          Интерфейс домашней сети (br0, eth0, auto...)"
            echo "  --port <port>                Порт веб-сервера (по умолчанию: 8181)"
            echo "  --bind <addr>                Адрес привязки (по умолчанию: 0.0.0.0)"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Функции утилит

print_header() {
    clear 2>/dev/null || true
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║          🎵 Keenetic Audio Player v2.0                    ║"
    echo "║                   Инсталлятор                              ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
}

print_section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

print_success() {
    echo "✅ $1"
}

print_info() {
    echo "ℹ️  $1"
}

print_warning() {
    echo "⚠️  $1"
}

print_error() {
    echo "❌ $1"
}

# Определение системы
detect_system() {
    print_section "Определение системы"
    
    echo "ОС: $OS_TYPE"
    echo "Архитектура: $ARCH"
    
    case $ARCH in
        armv7l|armv7) 
            GO_ARCH="arm"
            GO_ARM="7"
            ARCH_NAME="ARM7 (новые Keenetic)"
            ;;
        armv5l|armv5)
            GO_ARCH="arm"
            GO_ARM="5"
            ARCH_NAME="ARM5 (старые Keenetic)"
            ;;
        aarch64|arm64)
            GO_ARCH="arm64"
            ARCH_NAME="ARM64 (новейшие Keenetic)"
            ;;
        x86_64|amd64)
            GO_ARCH="amd64"
            ARCH_NAME="x86_64 (ПК/сервер)"
            ;;
        i386|i686)
            GO_ARCH="386"
            ARCH_NAME="x86 (32-bit ПК)"
            ;;
        armv6l|armv6)
            GO_ARCH="arm"
            GO_ARM="6"
            ARCH_NAME="ARM6"
            ;;
        mipsel|mipsle|mips)
            opkg_arches=""
            if command -v opkg >/dev/null 2>&1; then
                opkg_arches=$(opkg print-architecture 2>/dev/null || true)
            elif [ -x /opt/bin/opkg ]; then
                opkg_arches=$(/opt/bin/opkg print-architecture 2>/dev/null || true)
            fi
            case "$opkg_arches" in
                *mipselsf*) GO_ARCH="mipsle"; GO_MIPS="softfloat" ;;
                *mipselhf*) GO_ARCH="mipsle"; GO_MIPS="hardfloat" ;;
                *mipssf*) GO_ARCH="mips"; GO_MIPS="softfloat" ;;
                *mipshf*) GO_ARCH="mips"; GO_MIPS="hardfloat" ;;
                *mipsel*) GO_ARCH="mipsle"; GO_MIPS="softfloat" ;;
                *)
                    if [ "$ARCH" = "mipsel" ] || [ "$ARCH" = "mipsle" ]; then
                        GO_ARCH="mipsle"
                    elif [ "$(printf '\001\000\000\000' | od -An -tu4 2>/dev/null | tr -d ' ')" = "1" ]; then
                        GO_ARCH="mipsle"
                    else
                        GO_ARCH="mipsle"
                    fi
                    GO_MIPS="softfloat"
                    ;;
            esac
            if [ -n "${AUDIO_PLAYER_MIPS_FLOAT:-}" ]; then
                GO_MIPS="$AUDIO_PLAYER_MIPS_FLOAT"
            fi
            case "$GO_MIPS" in
                softfloat|hardfloat) ;;
                *) GO_MIPS="softfloat" ;;
            esac
            case "$GO_ARCH:$GO_MIPS" in
                mipsle:*) ARCH_NAME="MIPS little-endian ($GO_MIPS)" ;;
                mips:*) ARCH_NAME="MIPS big-endian ($GO_MIPS)" ;;
            esac
            ;;
        ppc64le)
            GO_ARCH="ppc64le"
            ARCH_NAME="PowerPC 64-bit little-endian"
            ;;
        riscv64)
            GO_ARCH="riscv64"
            ARCH_NAME="RISC-V 64-bit"
            ;;
        *)
            print_error "Неподдерживаемая архитектура: $ARCH"
            exit 1
            ;;
    esac
    
    print_success "Архитектура: $ARCH_NAME"
}

# Выбор папки установки
choose_install_dir() {
    print_section "Папка установки"
    
    if [ -n "${AUDIO_PLAYER_HOME:-}" ]; then
        INSTALL_DIR="$AUDIO_PLAYER_HOME"
    elif [ $INTERACTIVE -eq 1 ]; then
        echo "1) /opt/audio-player           (рекомендуется)"
        echo "2) /usr/local/bin/audio-player"
        echo "3) ~/audio-player              (в домашней папке)"
        echo "4) /mnt/sda1/audio-player      (на USB-диске)"
        echo "5) Введите свой путь..."
        printf '%s' "Выберите вариант (1-5) [1]: "
        IFS= read -r choice || choice=""
        case "$choice" in
            2) INSTALL_DIR="/usr/local/bin/audio-player" ;;
            3) INSTALL_DIR="$HOME/audio-player" ;;
            4) INSTALL_DIR="/mnt/sda1/audio-player" ;;
            5) 
                printf '%s' "Введите путь: "
                IFS= read -r INSTALL_DIR || INSTALL_DIR=""
                ;;
            *) INSTALL_DIR="/opt/audio-player" ;;
        esac
    else
        # Автоматический выбор без лишних вопросов
        if [ -d "/opt" ]; then
            INSTALL_DIR="/opt/audio-player"
        elif [ -d "/mnt/sda1" ]; then
            INSTALL_DIR="/mnt/sda1/audio-player"
        else
            INSTALL_DIR="$HOME/audio-player"
        fi
    fi
    
    print_success "Папка установки: $INSTALL_DIR"
}

# Сетевые функции
get_interface_ip() {
    local iface="$1"
    [ -n "$iface" ] || return 1
    if command -v ip >/dev/null 2>&1; then
        ip -4 addr show dev "$iface" 2>/dev/null | awk '$1 == "inet" { split($2, a, "/"); print a[1]; exit }'
    elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig "$iface" 2>/dev/null | awk '/inet addr:/ { sub("addr:", "", $2); print $2; exit } /inet / && $2 ~ /^[0-9]+\./ { print $2; exit }'
    fi
}

get_all_interfaces() {
    if [ -d /sys/class/net ]; then
        for dev in /sys/class/net/*; do
            [ -e "$dev" ] || continue
            dev_name=$(basename "$dev")
            [ "$dev_name" != "lo" ] && echo "$dev_name"
        done
    elif command -v ip >/dev/null 2>&1; then
        ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -v '^lo$'
    elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig 2>/dev/null | grep -E '^[a-zA-Z0-9_-]+' | awk '{print $1}' | tr -d ':' | grep -v '^lo$'
    fi
}

detect_home_network_ip() {
    local target_iface="${1:-auto}"
    local found_ip=""

    if [ -n "$target_iface" ] && [ "$target_iface" != "auto" ]; then
        found_ip=$(get_interface_ip "$target_iface")
        if [ -n "$found_ip" ]; then
            echo "$found_ip"
            return 0
        fi
    fi

    # 1. Keenetic Home Network bridge (br0)
    found_ip=$(get_interface_ip "br0")
    if [ -n "$found_ip" ]; then
        echo "$found_ip"
        return 0
    fi

    # 2. OpenWrt LAN bridge (br-lan)
    found_ip=$(get_interface_ip "br-lan")
    if [ -n "$found_ip" ]; then
        echo "$found_ip"
        return 0
    fi

    # 3. Маршрут по умолчанию (default dev)
    if command -v ip >/dev/null 2>&1; then
        default_dev=$(ip route show 2>/dev/null | awk '/^default/ { for (i=1; i<=NF; i++) if ($i == "dev") print $(i+1) }' | head -n1)
        if [ -n "$default_dev" ]; then
            found_ip=$(get_interface_ip "$default_dev")
            if [ -n "$found_ip" ]; then
                echo "$found_ip"
                return 0
            fi
        fi
    fi

    # 4. Первый не-loopback интерфейс с приватным диапазоном IP
    for iface in $(get_all_interfaces); do
        ip_cand=$(get_interface_ip "$iface")
        case "$ip_cand" in
            192.168.*|10.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*)
                echo "$ip_cand"
                return 0
                ;;
        esac
    done

    # 5. Любой активный не-loopback IP
    for iface in $(get_all_interfaces); do
        ip_cand=$(get_interface_ip "$iface")
        if [ -n "$ip_cand" ] && [ "$ip_cand" != "127.0.0.1" ]; then
            echo "$ip_cand"
            return 0
        fi
    done

    # Запасное значение по умолчанию для Keenetic
    echo "192.168.1.1"
}

choose_network_interface() {
    print_section "Настройка сети и интерфейса"

    local ifaces=""
    if command -v sort >/dev/null 2>&1; then
        ifaces=$(get_all_interfaces | sort -u)
    else
        ifaces=$(get_all_interfaces)
    fi

    if [ $INTERACTIVE -eq 1 ]; then
        echo "Сервер слушает на 0.0.0.0 (всегда доступны и домашняя сеть, и localhost)."
        echo "Выберите интерфейс домашней сети для отображения и привязки:"
        echo ""
        echo "1) auto - Автоопределение (br0 / br-lan / LAN IP) [рекомендуется для Keenetic]"

        idx=2
        for iface in $ifaces; do
            ip_val=$(get_interface_ip "$iface")
            note=""
            if [ "$iface" = "br0" ]; then
                note=" (Домашняя сеть Keenetic)"
            elif [ "$iface" = "br-lan" ]; then
                note=" (Домашняя сеть OpenWrt)"
            fi
            if [ -n "$ip_val" ]; then
                echo "$idx) $iface - IP: $ip_val$note"
            else
                echo "$idx) $iface$note"
            fi
            eval "iface_choice_$idx=\"$iface\""
            idx=$((idx + 1))
        done
        echo "$idx) Ввести имя интерфейса или IP вручную..."
        custom_idx=$idx

        printf '%s' "Выберите вариант (1-$custom_idx) [1]: "
        IFS= read -r if_choice || if_choice=""

        if [ "$if_choice" = "$custom_idx" ]; then
            printf '%s' "Введите имя интерфейса (например, br0 или eth0): "
            IFS= read -r manual_if || manual_if=""
            [ -n "$manual_if" ] && NETWORK_INTERFACE="$manual_if"
        elif [ -n "$if_choice" ] && [ "$if_choice" -gt 1 ] && [ "$if_choice" -lt "$custom_idx" ] 2>/dev/null; then
            sel_if=$(eval "echo \"\$iface_choice_$if_choice\"")
            [ -n "$sel_if" ] && NETWORK_INTERFACE="$sel_if"
        else
            NETWORK_INTERFACE="auto"
        fi

        printf '%s' "Порт веб-интерфейса [$APP_PORT]: "
        IFS= read -r user_p || user_p=""
        if [ -n "$user_p" ]; then
            APP_PORT="$user_p"
        fi
    fi

    detected_home_ip=$(detect_home_network_ip "$NETWORK_INTERFACE")
    print_success "Интерфейс: $NETWORK_INTERFACE"
    print_success "IP домашней сети: $detected_home_ip"
    print_success "Порт: $APP_PORT"
    print_success "Локальный доступ (localhost / 127.0.0.1): включён обязательно"
}


# Проверка требований
check_requirements() {
    print_section "Проверка компонентов"
    
    if ! command -v curl >/dev/null 2>&1; then
        print_error "curl не установлен (нужен для загрузки сборки)"
        exit 1
    else
        print_success "curl установлен"
    fi

    player_found=0
    
    if command -v ffplay >/dev/null 2>&1; then
        print_success "ffplay установлен"
        player_found=1
    fi
    
    if command -v ffmpeg >/dev/null 2>&1; then
        print_success "ffmpeg установлен"
        player_found=1
    fi

    if command -v aplay >/dev/null 2>&1; then
        print_success "aplay установлен"
        player_found=1
    fi
    
    if command -v mpg123 >/dev/null 2>&1; then
        print_success "mpg123 установлен"
        player_found=1
    fi

    if command -v mpv >/dev/null 2>&1; then
        print_success "mpv установлен"
        player_found=1
    fi
    
    if [ $player_found -eq 0 ]; then
        print_warning "Плеер ещё не установлен (его можно поставить позже):"
        echo "  Keenetic (Entware): opkg install ffmpeg alsa-utils mpg123"
        echo "  Ubuntu/Debian:      apt install ffmpeg alsa-utils mpg123"
    fi
}

# Загрузка готовой сборки
compile_app() {
    print_section "Загрузка приложения"

    asset=""
    case "$GO_ARCH:$GO_ARM" in
        amd64:) asset="audio-player-linux-amd64" ;;
        386:) asset="audio-player-linux-386" ;;
        arm64:) asset="audio-player-linux-arm64" ;;
        arm:5) asset="audio-player-linux-armv5" ;;
        arm:6) asset="audio-player-linux-armv6" ;;
        arm:7) asset="audio-player-linux-armv7" ;;
        mipsle:*) asset="audio-player-linux-mipsle-$GO_MIPS" ;;
        mips:*) asset="audio-player-linux-mips-$GO_MIPS" ;;
        ppc64le:) asset="audio-player-linux-ppc64le" ;;
        riscv64:) asset="audio-player-linux-riscv64" ;;
        *) print_error "Для архитектуры $ARCH_NAME нет готовой сборки"; exit 1 ;;
    esac

    release_tag="${AUDIO_PLAYER_VERSION:-latest}"
    if [ $INTERACTIVE -eq 1 ] && [ -z "${AUDIO_PLAYER_VERSION:-}" ]; then
        printf '%s' "Версия релиза [latest]: "
        IFS= read -r user_tag || user_tag=""
        if [ -n "$user_tag" ]; then
            release_tag="$user_tag"
        fi
    fi

    if [ "$release_tag" = "latest" ]; then
        base_url="https://github.com/phenomenonRT/keenetic-audio-player-v2/releases/latest/download"
    else
        base_url="https://github.com/phenomenonRT/keenetic-audio-player-v2/releases/download/$release_tag"
    fi

    url="$base_url/$asset"
    temp_file=$(mktemp "${TMPDIR:-/tmp}/audio-player.XXXXXX")
    
    echo "Загрузка $asset..."
    if ! curl -fL --retry 3 "$url" -o "$temp_file"; then
        rm -f "$temp_file"
        print_error "Не удалось загрузить $asset ($release_tag). Проверьте интернет-соединение."
        exit 1
    fi
    
    if [ ! -s "$temp_file" ]; then
        rm -f "$temp_file"
        print_error "Загруженный файл пустой"
        exit 1
    fi

    # Проверка ELF (только если GNU od доступен и выдаёт корректные данные, не ломая BusyBox)
    case "$GO_ARCH" in
        386) expected_class="01"; expected_endian="01"; expected_machine="0300" ;;
        amd64) expected_class="02"; expected_endian="01"; expected_machine="3e00" ;;
        arm) expected_class="01"; expected_endian="01"; expected_machine="2800" ;;
        arm64) expected_class="02"; expected_endian="01"; expected_machine="b700" ;;
        mipsle) expected_class="01"; expected_endian="01"; expected_machine="0800" ;;
        mips) expected_class="01"; expected_endian="02"; expected_machine="0008" ;;
        ppc64le) expected_class="02"; expected_endian="01"; expected_machine="1500" ;;
        riscv64) expected_class="02"; expected_endian="01"; expected_machine="f300" ;;
    esac
    
    if command -v od >/dev/null 2>&1 && command -v cut >/dev/null 2>&1; then
        elf_header=$(od -An -tx1 -N 20 "$temp_file" 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) printf "%s", $i }' || true)
        if [ -n "$elf_header" ] && [ "${#elf_header}" -ge 40 ]; then
            elf_magic=$(printf '%s' "$elf_header" | cut -c1-8)
            elf_class=$(printf '%s' "$elf_header" | cut -c9-10)
            elf_endian=$(printf '%s' "$elf_header" | cut -c11-12)
            elf_machine=$(printf '%s' "$elf_header" | cut -c37-40)
            if [ "$elf_magic" = "7f454c46" ]; then
                if [ "$elf_class" != "$expected_class" ] || [ "$elf_endian" != "$expected_endian" ] || [ "$elf_machine" != "$expected_machine" ]; then
                    rm -f "$temp_file"
                    print_error "Несоответствие архитектуры: получено machine=$elf_machine, ожидалось $expected_machine"
                    exit 1
                fi
            fi
        fi
    fi

    EXECUTABLE="$temp_file"
    chmod +x "$EXECUTABLE"
    print_success "Приложение загружено: $asset"
}

# Подготовка папок
prepare_directories() {
    print_section "Подготовка папок"
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/media"
    mkdir -p "$INSTALL_DIR/logs"
    
    MEDIA_DIR="$INSTALL_DIR/media"
    CONFIG_FILE="$INSTALL_DIR/playlist.json"
    
    print_success "Папки созданы в $INSTALL_DIR"
}

# Установка файлов
install_files() {
    print_section "Установка файлов"
    
    cp "$EXECUTABLE" "$INSTALL_DIR/audio-player"
    rm -f "$EXECUTABLE"
    chmod +x "$INSTALL_DIR/audio-player"
    print_success "Приложение установлено"

    # Создаём файл конфигурации сети
    cat > "$INSTALL_DIR/audio-player.conf" << EOF
# 🎵 Keenetic Audio Player - Конфигурация сети
# Сетевой интерфейс для домашней сети (auto, br0, br-lan, eth0 и др.)
# При значении "auto" плеер автоматически определяет интерфейс домашней сети (br0 на Keenetic)
NETWORK_INTERFACE="$NETWORK_INTERFACE"

# Порт веб-сервера (по умолчанию 8181)
PORT="$APP_PORT"

# Адрес привязки (по умолчанию 0.0.0.0 для одновременного доступа через домашнюю сеть и localhost)
BIND_ADDR="$BIND_ADDR"
EOF
    chmod 644 "$INSTALL_DIR/audio-player.conf"
    print_success "Конфигурация сети: $INSTALL_DIR/audio-player.conf"
    
    # Создаём скрипт запуска
    cat > "$INSTALL_DIR/start.sh" << 'EOF'
#!/bin/sh
cd "$(dirname "$0")"
[ -f "./audio-player.conf" ] && . ./audio-player.conf
export NETWORK_INTERFACE PORT BIND_ADDR
exec ./audio-player
EOF
    chmod +x "$INSTALL_DIR/start.sh"

    # Устанавливаем audio-player.sh
    if [ -f "$(dirname "$0")/audio-player.sh" ]; then
        cp "$(dirname "$0")/audio-player.sh" "$INSTALL_DIR/audio-player.sh"
        chmod +x "$INSTALL_DIR/audio-player.sh"
    elif curl -fsSL --retry 3 "https://raw.githubusercontent.com/phenomenonRT/keenetic-audio-player-v2/main/audio-player.sh" -o "$INSTALL_DIR/audio-player.sh"; then
        chmod +x "$INSTALL_DIR/audio-player.sh"
    fi
    print_success "Скрипт управления: $INSTALL_DIR/audio-player.sh"

    # Устанавливаем uninstall.sh
    if [ -f "$(dirname "$0")/uninstall.sh" ]; then
        cp "$(dirname "$0")/uninstall.sh" "$INSTALL_DIR/uninstall.sh"
        chmod +x "$INSTALL_DIR/uninstall.sh"
    elif curl -fsSL --retry 3 "https://raw.githubusercontent.com/phenomenonRT/keenetic-audio-player-v2/main/uninstall.sh" -o "$INSTALL_DIR/uninstall.sh"; then
        chmod +x "$INSTALL_DIR/uninstall.sh"
    fi
    
    # Инициализируем плейлист если не существует
    if [ ! -f "$CONFIG_FILE" ]; then
        echo '{"items":[]}' > "$CONFIG_FILE"
    fi
    print_success "Файлы успешно размещены"
}

# Автозапуск
setup_autostart() {
    print_section "Настройка автозапуска"

    # 1. Keenetic Entware
    if [ -x /opt/etc/init.d/rc.unslung ] || [ -d "/opt/etc/init.d" ]; then
        setup_entware
        return
    fi

    # 2. Systemd
    if command -v systemctl >/dev/null 2>&1 && [ -d "/etc/systemd/system" ]; then
        setup_systemd
        return
    fi

    # 3. Crontab
    if command -v crontab >/dev/null 2>&1; then
        setup_cron
        return
    fi

    print_info "Автозапуск пропущен (запускайте вручную через start.sh)"
}

setup_entware() {
    INIT_DIR="/opt/etc/init.d"
    INIT_FILE="$INIT_DIR/S99audio-player"
    INSTALL_CONFIG="/opt/etc/audio-player-install-dir"

    mkdir -p "$INIT_DIR" 2>/dev/null || true
    printf '%s\n' "$INSTALL_DIR" > "$INSTALL_CONFIG" 2>/dev/null || true

    cat > "$INIT_FILE" << 'EOF'
#!/bin/sh
CONFIG_FILE="/opt/etc/audio-player-install-dir"
INSTALL_DIR=$(cat "$CONFIG_FILE" 2>/dev/null)
[ -n "$INSTALL_DIR" ] || INSTALL_DIR="/opt/audio-player"
APP="$INSTALL_DIR/audio-player"
PID_FILE="$INSTALL_DIR/audio-player.pid"
LOG_FILE="$INSTALL_DIR/logs/audio-player.log"

start_player() {
    if [ ! -x "$APP" ]; then
        echo "Audio Player not found: $APP" >&2
        return 1
    fi
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE" 2>/dev/null)
        case "$pid" in
            ''|0|*[!0-9]*) pid="" ;;
        esac
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "Audio Player is already running (PID $pid)"
            return 0
        fi
        rm -f "$PID_FILE"
    fi
    mkdir -p "$INSTALL_DIR/logs"
    cd "$INSTALL_DIR" || return 1
    [ -f "$INSTALL_DIR/audio-player.conf" ] && . "$INSTALL_DIR/audio-player.conf"
    export NETWORK_INTERFACE PORT BIND_ADDR
    ./audio-player >> "$LOG_FILE" 2>&1 &
    echo "$!" > "$PID_FILE"
    echo "Audio Player started (PID $(cat "$PID_FILE"))"
}

stop_player() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Audio Player is not running"
        return 0
    fi
    pid=$(cat "$PID_FILE" 2>/dev/null)
    case "$pid" in
        ''|0|*[!0-9]*) rm -f "$PID_FILE"; echo "Invalid PID file removed"; return 0 ;;
    esac
    if kill "$pid" 2>/dev/null; then
        rm -f "$PID_FILE"
        echo "Audio Player stopped"
    else
        rm -f "$PID_FILE"
        echo "Audio Player process was not found"
    fi
}

case "${1:-start}" in
    start) start_player ;;
    stop) stop_player ;;
    restart) stop_player; start_player ;;
    *) echo "Usage: $0 {start|stop|restart}" >&2; exit 1 ;;
esac
EOF
    chmod +x "$INIT_FILE"
    AUTOSTART_KIND="entware"
    print_success "Entware автозапуск установлен: $INIT_FILE"
}

setup_systemd() {
    service_file="/etc/systemd/system/audio-player.service"
    
    if [ ! -w "/etc/systemd/system" ]; then
        print_info "Нет прав на запись в /etc/systemd/system, пропускаем"
        return
    fi
    
    cat > "$service_file" << EOF
[Unit]
Description=Keenetic Audio Player
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
EnvironmentFile=-$INSTALL_DIR/audio-player.conf
ExecStart=$INSTALL_DIR/audio-player
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    chmod 644 "$service_file"
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable audio-player 2>/dev/null || true
    systemctl start audio-player 2>/dev/null || true
    AUTOSTART_KIND="systemd"
    print_success "Systemd сервис установлен и запущен"
}

setup_cron() {
    if crontab -l 2>/dev/null | grep -q audio-player; then
        return
    fi
    (crontab -l 2>/dev/null || true; echo "@reboot $INSTALL_DIR/audio-player >> $INSTALL_DIR/logs/audio-player.log 2>&1 &") | crontab -
    print_success "Добавлено в crontab (@reboot)"
}

get_router_ips() {
    if command -v ip >/dev/null 2>&1; then
        ip addr show 2>/dev/null | awk '$1 == "inet" { split($2, a, "/"); if (a[1] !~ /^127\./) print a[1] }'
    elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig 2>/dev/null | awk '/inet addr:/ { sub("addr:", "", $2); print $2 } /inet / && $2 ~ /^[0-9]+\./ { print $2 }'
    fi
}

start_application() {
    print_section "Запуск приложения"
    
    if [ "${AUTOSTART_KIND:-}" = "entware" ]; then
        /opt/etc/init.d/S99audio-player start
    elif [ "${AUTOSTART_KIND:-}" = "systemd" ]; then
        systemctl start audio-player 2>/dev/null || true
    else
        cd "$INSTALL_DIR"
        nohup ./audio-player >> logs/audio-player.log 2>&1 &
        echo "$!" > "$INSTALL_DIR/audio-player.pid"
        print_success "Приложение запущено в фоне"
    fi
    
    sleep 1
    print_section "Готово! 🎉"
    echo "📍 Папка: $INSTALL_DIR"
    echo "📋 Управление: $INSTALL_DIR/audio-player.sh"
    echo ""
    echo "🌐 Откройте в браузере:"
    router_ips=$(get_router_ips)
    if [ -n "$router_ips" ]; then
        for router_ip in $router_ips; do
            echo "   👉 http://$router_ip:8181"
        done
    else
        echo "   👉 http://192.168.1.1:8181"
    fi
    echo ""
}

# Главная функция
main() {
    print_header
    detect_system
    choose_install_dir
    check_requirements
    compile_app
    prepare_directories
    install_files
    setup_autostart
    start_application
}

main "$@"
