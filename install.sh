#!/bin/sh

# 🎵 Keenetic Audio Player - Инсталлятор
# Интерактивная установка с выбором папки и способа автозапуска

set -e

# Цвета
RED=''
GREEN=''
YELLOW=''
BLUE=''
CYAN=''
NC=''

# Переменные
INSTALL_DIR=""
MEDIA_DIR=""
CONFIG_FILE=""
EXECUTABLE=""
OS_TYPE=$(uname -s)
ARCH=$(uname -m)

# Функции утилит

print_header() {
    clear 2>/dev/null || true
    printf '%s\n' "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║          🎵 Keenetic Audio Player v2.0                    ║"
    echo "║                   Инсталлятор                              ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    printf '%s\n' "${NC}"
}

print_section() {
    echo ""
    printf '%s\n' "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf '%s\n' "${CYAN}$1${NC}"
    printf '%s\n' "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    printf '%s\n' "${GREEN}✅ $1${NC}"
}

print_info() {
    printf '%s\n' "${CYAN}ℹ️  $1${NC}"
}

print_warning() {
    printf '%s\n' "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    printf '%s\n' "${RED}❌ $1${NC}"
}

# Получение информации о системе
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
                    elif [ "$(printf '\001\000\000\000' | od -An -tu4 | tr -d ' ')" = "1" ]; then
                        GO_ARCH="mipsle"
                    else
                        GO_ARCH="mips"
                    fi
                    GO_MIPS="softfloat"
                    ;;
            esac
            if [ -n "${AUDIO_PLAYER_MIPS_FLOAT:-}" ]; then
                GO_MIPS="$AUDIO_PLAYER_MIPS_FLOAT"
            fi
            case "$GO_MIPS" in
                softfloat|hardfloat) ;;
                *) print_error "AUDIO_PLAYER_MIPS_FLOAT должен быть softfloat или hardfloat"; exit 1 ;;
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
    print_section "Выбор папки установки"
    
    echo "По умолчанию будет использована: /opt/audio-player"
    echo ""
    echo "Вы можете выбрать свой путь. Доступные варианты:"
    echo "1) /opt/audio-player           (рекомендуется)"
    echo "2) /usr/local/bin/audio-player (для системного устанавливающего)"
    echo "3) ~/audio-player              (в домашней папке)"
    echo "4) /mnt/sda1/audio-player      (на роутере Keenetic)"
    echo "5) Введите свой путь..."
    echo ""
    
    printf '%s' "Выберите вариант (1-5) [1]: "
    IFS= read -r choice || choice=""
    choice=${choice:-1}
    
    case $choice in
        1) INSTALL_DIR="/opt/audio-player" ;;
        2) INSTALL_DIR="/usr/local/bin/audio-player" ;;
        3) INSTALL_DIR="$HOME/audio-player" ;;
        4) INSTALL_DIR="/mnt/sda1/audio-player" ;;
        5) 
            printf '%s' "Введите путь: "
            IFS= read -r INSTALL_DIR || INSTALL_DIR=""
            ;;
        *)
            print_error "Неверный выбор"
            choose_install_dir
            return
            ;;
    esac
    
    print_success "Папка установки: $INSTALL_DIR"
}

# Проверка требований
check_requirements() {
    print_section "Проверка требований"
    
    missing=0
    
    # Проверяем загрузчик
    if ! command -v curl >/dev/null 2>&1; then
        print_error "curl не установлен (нужен для загрузки сборки с GitHub)"
        missing=$((missing + 1))
    else
        print_success "curl установлен"
    fi

    # Проверяем плееры
    echo ""
    echo "Проверка доступных плееров:"
    
    player_found=0
    
    if command -v ffplay >/dev/null 2>&1; then
        print_success "ffplay установлен (лучший выбор)"
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
    
    if [ $player_found -eq 0 ]; then
        print_warning "Плеер не найден"
        echo "Установите один из них:"
        echo "  На Keenetic: opkg install ffmpeg"
        echo "  На Ubuntu/Debian: sudo apt install ffmpeg"
        echo "  На CentOS: sudo yum install ffmpeg"
        missing=$((missing + 1))
    fi
    
    if [ $missing -gt 0 ]; then
        printf '%s' "Продолжить несмотря на ошибки? (y/N): "
        IFS= read -r REPLY || REPLY=""
        case "$REPLY" in
            y|Y) ;;
            *) print_error "Инсталляция отменена"; exit 1 ;;
        esac
    fi
}

# Загрузка готовой сборки
compile_app() {
    print_section "Загрузка приложения с GitHub"

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

    release_tag="${AUDIO_PLAYER_VERSION:-}"
    if [ -z "$release_tag" ]; then
        printf '%s' "Версия релиза [latest]: "
        IFS= read -r release_tag || release_tag=""
    fi
    release_tag=${release_tag:-latest}

    base_url=""
    if [ "$release_tag" = "latest" ]; then
        base_url="https://github.com/phenomenonRT/keenetic-audio-player-v2/releases/latest/download"
    else
        case "$release_tag" in
            [A-Za-z0-9]*) ;;
            *) print_error "Некорректный тег релиза: $release_tag"; exit 1 ;;
        esac
        case "$release_tag" in
            *[!A-Za-z0-9._-]*) print_error "Некорректный тег релиза: $release_tag"; exit 1 ;;
        esac
        base_url="https://github.com/phenomenonRT/keenetic-audio-player-v2/releases/download/$release_tag"
    fi

    url="$base_url/$asset"
    temp_file=$(mktemp "${TMPDIR:-/tmp}/audio-player.XXXXXX")
    if ! curl -fL --retry 3 "$url" -o "$temp_file"; then
        rm -f "$temp_file"
        print_error "Не удалось загрузить $asset для релиза $release_tag. Проверьте тег и наличие сборки этой архитектуры в GitHub Release."
        exit 1
    fi
    if [ ! -s "$temp_file" ]; then
        rm -f "$temp_file"
        print_error "GitHub вернул пустой файл"
        exit 1
    fi

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
        elf_header=$(od -An -tx1 -N20 "$temp_file" 2>/dev/null | tr -d ' \n')
        elf_magic=$(printf '%s' "$elf_header" | cut -c1-8)
        elf_class=$(printf '%s' "$elf_header" | cut -c9-10)
        elf_endian=$(printf '%s' "$elf_header" | cut -c11-12)
        elf_machine=$(printf '%s' "$elf_header" | cut -c37-40)
        if [ "$elf_magic" != "7f454c46" ] || [ "$elf_class" != "$expected_class" ] || [ "$elf_endian" != "$expected_endian" ] || [ "$elf_machine" != "$expected_machine" ]; then
            rm -f "$temp_file"
            print_error "Релиз содержит бинарник не для этой архитектуры ($ARCH_NAME); установка остановлена."
            exit 1
        fi
    fi

    EXECUTABLE="$temp_file"
    chmod +x "$EXECUTABLE"
    print_success "Приложение загружено: $asset (релиз $release_tag)"
}
# Подготовка папок
prepare_directories() {
    print_section "Подготовка папок"
    
    # Проверяем прав доступа
    if [ "$INSTALL_DIR" = "/opt/audio-player" ] || [ "$INSTALL_DIR" = "/usr/local/bin/audio-player" ]; then
        if [ ! -w "$(dirname "$INSTALL_DIR")" ]; then
            print_error "Нет прав для установки в $INSTALL_DIR"
            print_info "Запустите установщик из root-консоли устройства."
            exit 1
        fi
    fi
    
    echo "Создание папок..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/media"
    mkdir -p "$INSTALL_DIR/logs"
    
    MEDIA_DIR="$INSTALL_DIR/media"
    CONFIG_FILE="$INSTALL_DIR/playlist.json"
    
    print_success "Папки созданы:"
    echo "  $INSTALL_DIR - основная папка"
    echo "  $MEDIA_DIR - аудио файлы"
    echo "  $INSTALL_DIR/logs - логи"
}

# Установка файлов
install_files() {
    print_section "Установка файлов"
    
    echo "Копирование приложения..."
    cp "$EXECUTABLE" "$INSTALL_DIR/audio-player"
    rm -f "$EXECUTABLE"
    chmod +x "$INSTALL_DIR/audio-player"
    print_success "Приложение установлено"
    
    # Создаём скрипт запуска
    cat > "$INSTALL_DIR/start.sh" << 'EOF'
#!/bin/sh
cd "$(dirname "$0")"
exec ./audio-player
EOF
    chmod +x "$INSTALL_DIR/start.sh"
    print_success "Скрипт запуска создан"

    if curl -fsSL --retry 3 "https://raw.githubusercontent.com/phenomenonRT/keenetic-audio-player-v2/main/uninstall.sh" -o "$INSTALL_DIR/uninstall.sh"; then
        chmod +x "$INSTALL_DIR/uninstall.sh"
        print_success "Деинсталлятор установлен: $INSTALL_DIR/uninstall.sh"
    else
        print_warning "Не удалось скачать деинсталлятор; его можно запустить отдельно из репозитория"
    fi
    
    # Создаём пустой плейлист
    echo '{"items":[]}' > "$CONFIG_FILE"
    print_success "Конфигурация инициализирована"
}

# Выбор способа автозапуска
choose_autostart() {
    print_section "Автозапуск"

    if [ -x /opt/etc/init.d/rc.unslung ]; then
        print_info "Обнаружен Entware rc.unslung; настрою автозапуск для Keenetic"
        setup_entware
        return
    fi

    echo "Выберите способ автозапуска при перезагрузке:"
    echo "1) Systemd сервис (рекомендуется для Linux)"
    echo "2) Crontab (для роутеров и систем без systemd)"
    echo "3) Init.d скрипт (для старых систем)"
    echo "4) Не устанавливать автозапуск"
    echo ""
    
    printf '%s' "Выберите вариант (1-4) [1]: "
    IFS= read -r autostart_choice || autostart_choice=""
    autostart_choice=${autostart_choice:-1}
    
    case $autostart_choice in
        1) setup_systemd ;;
        2) setup_cron ;;
        3) setup_initd ;;
        4) print_info "Автозапуск не установлен" ;;
        *)
            print_error "Неверный выбор"
            choose_autostart
            ;;
    esac
}

# Entware /opt/etc/init.d/rc.unslung
setup_entware() {
    print_section "Установка Entware init-скрипта"

    INIT_DIR="/opt/etc/init.d"
    INIT_FILE="$INIT_DIR/S99audio-player"
    INSTALL_CONFIG="/opt/etc/audio-player-install-dir"

    if [ ! -w "$INIT_DIR" ] || [ ! -w "$(dirname "$INSTALL_CONFIG")" ]; then
        print_error "Нет прав на запись в /opt/etc/init.d. Запустите установщик из root-консоли Keenetic."
        return 1
    fi

    printf '%s\n' "$INSTALL_DIR" > "$INSTALL_CONFIG"
    cat > "$INIT_FILE" << 'EOF'
#!/bin/sh
CONFIG_FILE="/opt/etc/audio-player-install-dir"
INSTALL_DIR=$(cat "$CONFIG_FILE" 2>/dev/null)
[ -n "$INSTALL_DIR" ] || exit 1
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
    print_success "Установлен $INIT_FILE; rc.unslung будет запускать его при старте Entware"
    echo "Управление: $INIT_FILE {start|stop|restart}"
}

# Systemd сервис
setup_systemd() {
    print_section "Установка Systemd сервиса"
    
    # Проверяем наличие systemd
    if ! command -v systemctl >/dev/null 2>&1; then
        print_warning "Systemd не найден, используя Crontab"
        setup_cron
        return
    fi
    
    service_file="/etc/systemd/system/audio-player.service"
    
    # Проверяем права
    if [ ! -w "$(dirname "$service_file")" ]; then
        print_warning "Требуются права администратора для установки сервиса"
        echo "Запустите установщик из root-консоли устройства."
        return
    fi
    
    cat > "$service_file" << EOF
[Unit]
Description=Keenetic Audio Player
Documentation=
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/audio-player
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=audio-player

[Install]
WantedBy=multi-user.target
EOF
    
    chmod 644 "$service_file"
    systemctl daemon-reload
    systemctl enable audio-player
    systemctl start audio-player
    
    print_success "Systemd сервис установлен"
    echo "Команды управления:"
    echo "  systemctl start audio-player   - запустить"
    echo "  systemctl stop audio-player    - остановить"
    echo "  systemctl status audio-player  - статус"
    echo "  systemctl restart audio-player - перезагрузить"
}

# Crontab
setup_cron() {
    print_section "Установка Crontab"
    
    # Проверяем есть ли уже запись
    if crontab -l 2>/dev/null | grep -q audio-player; then
        print_warning "Crontab запись уже существует"
        return
    fi
    
    (crontab -l 2>/dev/null || echo ""; echo "@reboot $INSTALL_DIR/audio-player >> $INSTALL_DIR/logs/audio-player.log 2>&1 &") | crontab -
    
    print_success "Crontab запись добавлена"
    echo "Приложение будет запущено автоматически после перезагрузки"
}

# Init.d скрипт
setup_initd() {
    print_section "Установка Init.d скрипта"
    
    init_file="/etc/init.d/audio-player"
    
    if [ ! -w "$(dirname "$init_file")" ]; then
        print_warning "Требуются права администратора"
        echo "Запустите установщик из root-консоли устройства."
        return
    fi
    
    cat > "$init_file" << EOF
#!/bin/sh
### BEGIN INIT INFO
# Provides:          audio-player
# Required-Start:    \$network
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:
# Short-Description: Keenetic Audio Player
### END INIT INFO

case "\$1" in
  start)
    echo "Starting Audio Player..."
    $INSTALL_DIR/audio-player >> $INSTALL_DIR/logs/audio-player.log 2>&1 &
    ;;
  stop)
    killall audio-player
    ;;
  *)
    echo "Usage: \$0 {start|stop}"
    exit 1
esac

exit 0
EOF
    
    chmod +x "$init_file"
    print_success "Init.d скрипт установлен"
}

# Найти IPv4-адреса устройства для доступа из локальной сети.
get_router_ips() {
    if command -v ip >/dev/null 2>&1; then
        ip addr show 2>/dev/null | awk '$1 == "inet" { split($2, a, "/"); if (a[1] !~ /^127\./) print a[1] }'
    elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig 2>/dev/null | awk '/inet addr:/ { sub("addr:", "", $2); print $2 } /inet / && $2 ~ /^[0-9]+\./ { print $2 }'
    fi
}

# Показ информации об установке
show_summary() {
    print_section "Установка завершена! 🎉"
    
    printf '%s\n' "${GREEN}Информация об установке:${NC}"
    echo ""
    echo "📍 Папка установки:     $INSTALL_DIR"
    echo "📁 Папка медиа:         $MEDIA_DIR"
    echo "⚙️  Конфиг-файл:        $CONFIG_FILE"
    echo "🎵 Приложение:          $INSTALL_DIR/audio-player"
    echo "📜 Логи:                $INSTALL_DIR/logs/"
    if [ "${AUTOSTART_KIND:-}" = "entware" ]; then
        echo "⚙️  Автозапуск:          /opt/etc/init.d/S99audio-player"
        echo "    Управление:          /opt/etc/init.d/S99audio-player start|stop|restart"
    fi
    echo ""
    
    printf '%s\n' "${GREEN}Следующие шаги:${NC}"
    echo ""
    echo "1️⃣  ${CYAN}Запустите приложение:${NC}"
    echo "   $INSTALL_DIR/audio-player"
    echo ""
    echo "2️⃣  ${CYAN}Откройте браузер с компьютера или телефона:${NC}"
    router_ips=$(get_router_ips)
    if [ -n "$router_ips" ]; then
        for router_ip in $router_ips; do
            echo "   http://$router_ip:8181"
        done
    else
        echo "   http://<IP-адрес-роутера>:8181"
        echo "   Например: http://192.168.1.1:8181"
    fi
    echo ""
    echo "3️⃣  ${CYAN}Добавьте аудио файлы:${NC}"
    echo "   - Через веб-интерфейс (перетащите файлы)"
    echo "   - Или скопируйте в: $MEDIA_DIR"
    echo ""
    
    printf '%s\n' "${GREEN}Полезные команды:${NC}"
    echo ""
    echo "   # Запустить вручную"
    echo "   $INSTALL_DIR/audio-player"
    echo ""
    echo "   # Проверить статус (если используется systemd)"
    echo "   systemctl status audio-player"
    echo ""
    echo "   # Просмотреть логи"
    echo "   tail -f $INSTALL_DIR/logs/audio-player.log"
    echo ""
    echo "   # Удаление приложения и его данных"
    echo "   $INSTALL_DIR/uninstall.sh"
    echo ""
}

# Запрос на запуск приложения
ask_run_now() {
    print_section "Готово к запуску"
    
    printf '%s' "Запустить приложение сейчас? (Y/n): "
    IFS= read -r REPLY || REPLY=""
    case "$REPLY" in
      y|Y|'')
        echo ""
        echo "Запуск приложения..."
        printf '%s\n' "${GREEN}════════════════════════════════════════════${NC}"
        echo ""
        if [ "${AUTOSTART_KIND:-}" = "entware" ]; then
            /opt/etc/init.d/S99audio-player start
            return
        fi
        cd "$INSTALL_DIR"
        exec ./audio-player
        ;;
      *)
        echo ""
        print_info "Вы можете запустить приложение позже:"
        echo "$INSTALL_DIR/audio-player"
        ;;
    esac
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
    choose_autostart
    show_summary
    ask_run_now
}

# Запуск
main "$@"
