#!/bin/bash

# 🎵 Keenetic Audio Player - Инсталлятор
# Интерактивная установка с выбором папки и способа автозапуска

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Переменные
INSTALL_DIR=""
MEDIA_DIR=""
CONFIG_FILE=""
EXECUTABLE=""
OS_TYPE=$(uname -s)
ARCH=$(uname -m)

# Функции утилит

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║          🎵 Keenetic Audio Player v2.0                    ║"
    echo "║                   Инсталлятор                              ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
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
    
    read -p "Выберите вариант (1-5) [1]: " choice
    choice=${choice:-1}
    
    case $choice in
        1) INSTALL_DIR="/opt/audio-player" ;;
        2) INSTALL_DIR="/usr/local/bin/audio-player" ;;
        3) INSTALL_DIR="$HOME/audio-player" ;;
        4) INSTALL_DIR="/mnt/sda1/audio-player" ;;
        5) 
            read -p "Введите путь: " INSTALL_DIR
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
    
    local missing=0
    
    # Проверяем Go
    if ! command -v go &> /dev/null; then
        print_error "Go не установлен"
        echo "Установите Go с https://golang.org/dl/ или через пакетный менеджер"
        missing=$((missing + 1))
    else
        print_success "Go установлен: $(go version)"
    fi
    
    # Проверяем плееры
    echo ""
    echo "Проверка доступных плееров:"
    
    local player_found=0
    
    if command -v ffplay &> /dev/null; then
        print_success "ffplay установлен (лучший выбор)"
        player_found=1
    fi
    
    if command -v aplay &> /dev/null; then
        print_success "aplay установлен"
        player_found=1
    fi
    
    if command -v mpg123 &> /dev/null; then
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
        read -p "Продолжить несмотря на ошибки? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Инсталляция отменена"
            exit 1
        fi
    fi
}

# Компиляция
compile_app() {
    print_section "Компиляция приложения"
    
    # Проверяем что исходный файл существует
    if [ ! -f "keenetic-audio-player-v2.go" ]; then
        print_error "Файл keenetic-audio-player-v2.go не найден"
        exit 1
    fi
    
    echo "Компилирование для $ARCH_NAME..."
    echo "Это может занять некоторое время..."
    echo ""
    
    if [ "$GO_ARM" != "" ]; then
        GOOS=linux GOARCH=$GO_ARCH GOARM=$GO_ARM go build -o audio-player keenetic-audio-player-v2.go
    else
        GOOS=linux GOARCH=$GO_ARCH go build -o audio-player keenetic-audio-player-v2.go
    fi
    
    if [ ! -f "audio-player" ]; then
        print_error "Компиляция не удалась"
        exit 1
    fi
    
    EXECUTABLE="$PWD/audio-player"
    local size=$(du -h audio-player | cut -f1)
    print_success "Компиляция завершена (размер: $size)"
}

# Подготовка папок
prepare_directories() {
    print_section "Подготовка папок"
    
    # Проверяем прав доступа
    if [ "$INSTALL_DIR" = "/opt/audio-player" ] || [ "$INSTALL_DIR" = "/usr/local/bin/audio-player" ]; then
        if [ ! -w "$(dirname $INSTALL_DIR)" ]; then
            print_error "Нет прав для установки в $INSTALL_DIR"
            print_info "Попробуйте: sudo ./install.sh"
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
    chmod +x "$INSTALL_DIR/audio-player"
    print_success "Приложение установлено"
    
    # Создаём скрипт запуска
    cat > "$INSTALL_DIR/start.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
exec ./audio-player
EOF
    chmod +x "$INSTALL_DIR/start.sh"
    print_success "Скрипт запуска создан"
    
    # Создаём пустой плейлист
    echo '{"items":[]}' > "$CONFIG_FILE"
    print_success "Конфигурация инициализирована"
}

# Выбор способа автозапуска
choose_autostart() {
    print_section "Автозапуск"
    
    echo "Выберите способ автозапуска при перезагрузке:"
    echo "1) Systemd сервис (рекомендуется для Linux)"
    echo "2) Crontab (для роутеров и систем без systemd)"
    echo "3) Init.d скрипт (для старых систем)"
    echo "4) Не устанавливать автозапуск"
    echo ""
    
    read -p "Выберите вариант (1-4) [1]: " autostart_choice
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

# Systemd сервис
setup_systemd() {
    print_section "Установка Systemd сервиса"
    
    # Проверяем наличие systemd
    if ! command -v systemctl &> /dev/null; then
        print_warning "Systemd не найден, используя Crontab"
        setup_cron
        return
    fi
    
    local service_file="/etc/systemd/system/audio-player.service"
    
    # Проверяем права
    if [ ! -w "$(dirname $service_file)" ]; then
        print_warning "Требуются права администратора для установки сервиса"
        echo "Выполните: sudo ./install.sh"
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
    
    local init_file="/etc/init.d/audio-player"
    
    if [ ! -w "$(dirname $init_file)" ]; then
        print_warning "Требуются права администратора"
        echo "Выполните: sudo ./install.sh"
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

# Показ информации об установке
show_summary() {
    print_section "Установка завершена! 🎉"
    
    echo -e "${GREEN}Информация об установке:${NC}"
    echo ""
    echo "📍 Папка установки:     $INSTALL_DIR"
    echo "📁 Папка медиа:         $MEDIA_DIR"
    echo "⚙️  Конфиг-файл:        $CONFIG_FILE"
    echo "🎵 Приложение:          $INSTALL_DIR/audio-player"
    echo "📜 Логи:                $INSTALL_DIR/logs/"
    echo ""
    
    echo -e "${GREEN}Следующие шаги:${NC}"
    echo ""
    echo "1️⃣  ${CYAN}Запустите приложение:${NC}"
    echo "   $INSTALL_DIR/audio-player"
    echo ""
    echo "2️⃣  ${CYAN}Откройте браузер:${NC}"
    echo "   http://localhost:8080"
    echo ""
    echo "3️⃣  ${CYAN}Добавьте аудио файлы:${NC}"
    echo "   - Через веб-интерфейс (перетащите файлы)"
    echo "   - Или скопируйте в: $MEDIA_DIR"
    echo ""
    
    echo -e "${GREEN}Полезные команды:${NC}"
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
    echo "   # Удаление (если нужно)"
    echo "   rm -rf $INSTALL_DIR"
    echo ""
}

# Запрос на запуск приложения
ask_run_now() {
    print_section "Готово к запуску"
    
    read -p "Запустить приложение сейчас? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [ -z "$REPLY" ]; then
        echo ""
        echo "Запуск приложения..."
        echo -e "${GREEN}════════════════════════════════════════════${NC}"
        echo ""
        cd "$INSTALL_DIR"
        exec ./audio-player
    else
        echo ""
        print_info "Вы можете запустить приложение позже:"
        echo "$INSTALL_DIR/audio-player"
    fi
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
