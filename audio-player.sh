#!/bin/sh

# 🎵 Audio Player Manager
# Управление установленным приложением

set -e

# Определяем путь установки
if [ -n "$AUDIO_PLAYER_HOME" ]; then
    INSTALL_DIR="$AUDIO_PLAYER_HOME"
elif [ -d "/opt/audio-player" ]; then
    INSTALL_DIR="/opt/audio-player"
elif [ -d "/usr/local/bin/audio-player" ]; then
    INSTALL_DIR="/usr/local/bin/audio-player"
elif [ -d "/mnt/sda1/audio-player" ]; then
    INSTALL_DIR="/mnt/sda1/audio-player"
elif [ -d "$HOME/audio-player" ]; then
    INSTALL_DIR="$HOME/audio-player"
else
    echo "❌ Audio Player не найден"
    echo "Используйте: AUDIO_PLAYER_HOME=/path/to/install $0 [команда]"
    exit 1
fi

PID_FILE="$INSTALL_DIR/audio-player.pid"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Функции

print_header() {
    printf '%b\n' "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║          🎵 Audio Player Manager                           ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    printf '%b\n' "${NC}"
    echo "Установка: $INSTALL_DIR"
    echo ""
}

print_help() {
    print_header
    printf '%b\n' "${YELLOW}Доступные команды:${NC}"
    echo ""
    echo "  start              - Запустить приложение"
    echo "  stop               - Остановить приложение"
    echo "  restart            - Перезагрузить приложение"
    echo "  status             - Показать статус"
    echo "  logs               - Просмотр логов (последние 20 строк)"
    echo "  logs-follow        - Просмотр логов в реальном времени"
    echo "  upload <file>      - Загрузить аудио файл"
    echo "  list-tracks        - Список всех треков в плейлисте"
    echo "  clear-tracks       - Очистить плейлист (опасно!)"
    echo "  info               - Информация об установке"
    echo "  uninstall          - Удалить приложение"
    echo "  help               - Эта справка"
    echo ""
    printf '%b\n' "${YELLOW}Примеры:${NC}"
    echo ""
    echo "  $0 start"
    echo "  $0 upload ~/music/song.mp3"
    echo "  $0 logs-follow"
    echo "  $0 status"
    echo ""
}

print_success() {
    printf '%b\n' "${GREEN}✅ $1${NC}"
}

print_error() {
    printf '%b\n' "${RED}❌ $1${NC}"
}

print_info() {
    printf '%b\n' "${CYAN}ℹ️  $1${NC}"
}

print_warning() {
    printf '%b\n' "${YELLOW}⚠️  $1${NC}"
}

is_running() {
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE" 2>/dev/null || true)
        case "$pid" in
            ''|0|*[!0-9]*) rm -f "$PID_FILE" ;;
            *)
                if kill -0 "$pid" 2>/dev/null; then
                    return 0
                fi
                rm -f "$PID_FILE"
                ;;
        esac
    fi
    if command -v pgrep >/dev/null 2>&1; then
        # Anchored with $ so this never self-matches the audio-player.sh
        # script invocation itself (its own path starts with the same
        # "audio-player" prefix, just followed by ".sh").
        pgrep -f "$INSTALL_DIR/audio-player\$" >/dev/null 2>&1 && return 0
    fi
    return 1
}

# Команды

cmd_start() {
    print_header
    print_info "Запуск приложения..."
    
    if is_running; then
        print_warning "Приложение уже запущено"
        return 0
    fi
    
    mkdir -p "$INSTALL_DIR/logs"
    cd "$INSTALL_DIR"
    # Подхватываем NETWORK_INTERFACE/PORT/BIND_ADDR из audio-player.conf,
    # иначе бинарник стартует с настройками по умолчанию, игнорируя выбор,
    # сделанный при установке (или через install.sh -i).
    [ -f "$INSTALL_DIR/audio-player.conf" ] && . "$INSTALL_DIR/audio-player.conf"
    export NETWORK_INTERFACE PORT BIND_ADDR
    nohup ./audio-player >> logs/audio-player.log 2>&1 &
    echo "$!" > "$PID_FILE"
    
    sleep 2
    
    if is_running; then
        print_success "Приложение запущено (PID $(cat "$PID_FILE" 2>/dev/null || true))"
        echo ""
        local display_port="${PORT:-8181}"
        echo "🖥️  Локально (всегда доступно): http://127.0.0.1:$display_port или http://localhost:$display_port"
        local router_ip=""
        if command -v ip >/dev/null 2>&1; then
            router_ip=$(ip addr show 2>/dev/null | awk '$1 == "inet" { split($2, a, "/"); if (a[1] !~ /^127\./) { print a[1]; exit } }')
        elif command -v ifconfig >/dev/null 2>&1; then
            router_ip=$(ifconfig 2>/dev/null | awk '/inet addr:/ { sub("addr:", "", $2); print $2; exit } /inet / && $2 ~ /^[0-9]+\./ { print $2; exit }')
        fi
        if [ -n "$router_ip" ]; then
            echo "🌐 Домашняя сеть: http://$router_ip:$display_port"
        else
            echo "🌐 Домашняя сеть: http://<IP-адрес-роутера>:$display_port (например, http://192.168.1.1:$display_port)"
        fi
        echo "Точный выбранный IP смотрите в: $INSTALL_DIR/logs/audio-player.log"
    else
        print_error "Ошибка запуска приложения"
        echo "Проверьте логи: tail -f $INSTALL_DIR/logs/audio-player.log"
        return 1
    fi
}

cmd_stop() {
    print_header
    print_info "Остановка приложения..."
    
    if ! is_running; then
        print_warning "Приложение не запущено"
        rm -f "$PID_FILE"
        return 0
    fi
    
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null || true
            sleep 1
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null || true
                sleep 1
            fi
        fi
        rm -f "$PID_FILE"
    fi
    
    if command -v pkill >/dev/null 2>&1; then
        # Anchored (see is_running) so this can't match audio-player.sh's
        # own invocation and kill the currently-running "stop" command.
        pkill -f "$INSTALL_DIR/audio-player\$" 2>/dev/null || true
    fi
    
    if ! is_running; then
        print_success "Приложение остановлено"
    else
        print_error "Не удалось остановить приложение"
        return 1
    fi
}

cmd_restart() {
    cmd_stop
    sleep 2
    cmd_start
}

cmd_status() {
    print_header
    
    if is_running; then
        printf '%b\n' "${GREEN}✅ Статус: ЗАПУЩЕНО${NC}"
        echo ""
        echo "Информация о процессе:"
        if [ -f "$PID_FILE" ]; then
            echo "  PID: $(cat "$PID_FILE" 2>/dev/null || true)"
        fi
        ps aux 2>/dev/null | grep "$INSTALL_DIR/audio-player" | grep -v grep | awk '{print "  PID: " $2 ", CPU: " $3 "%, MEM: " $4 "%"}' || true
    else
        printf '%b\n' "${RED}⏹️  Статус: ОСТАНОВЛЕНО${NC}"
    fi
    
    echo ""
    echo "Информация о системе:"
    echo "  Установка: $INSTALL_DIR"
    echo "  Музыка: $INSTALL_DIR/media"
    echo "  Конфиг: $INSTALL_DIR/playlist.json"
    echo "  Логи: $INSTALL_DIR/logs"
    if [ -f "$INSTALL_DIR/audio-player.conf" ]; then
        echo "  Сетевые настройки: $INSTALL_DIR/audio-player.conf"
        ( . "$INSTALL_DIR/audio-player.conf" 2>/dev/null
          echo "    Интерфейс: ${NETWORK_INTERFACE:-auto}"
          echo "    Порт: ${PORT:-8181}"
          echo "    Привязка (BIND_ADDR): ${BIND_ADDR:-0.0.0.0}"
        )
    fi
    
    echo ""
    if [ -f "$INSTALL_DIR/playlist.json" ]; then
        local track_count=$(grep -o '"id"' "$INSTALL_DIR/playlist.json" | wc -l)
        echo "  Треков в плейлисте: $track_count"
    fi
    
    if [ -d "$INSTALL_DIR/media" ]; then
        local media_size=$(du -sh "$INSTALL_DIR/media" 2>/dev/null | cut -f1)
        echo "  Размер медиа: $media_size"
    fi
}

cmd_logs() {
    print_header
    
    if [ ! -f "$INSTALL_DIR/logs/audio-player.log" ]; then
        print_warning "Логи не найдены"
        return 0
    fi
    
    echo "Последние 20 строк логов:"
    echo ""
    tail -20 "$INSTALL_DIR/logs/audio-player.log"
}

cmd_logs_follow() {
    print_header
    print_info "Просмотр логов (Ctrl+C для выхода)..."
    echo ""
    
    if [ ! -f "$INSTALL_DIR/logs/audio-player.log" ]; then
        print_warning "Логи не найдены, создаём..."
        mkdir -p "$INSTALL_DIR/logs"
        touch "$INSTALL_DIR/logs/audio-player.log"
    fi
    
    tail -f "$INSTALL_DIR/logs/audio-player.log"
}

cmd_upload() {
    local file="${2:-}"
    
    if [ -z "$file" ]; then
        print_error "Укажите файл для загрузки"
        echo "Использование: $0 upload <файл>"
        return 1
    fi
    
    if [ ! -f "$file" ]; then
        print_error "Файл не найден: $file"
        return 1
    fi
    
    print_header
    print_info "Загрузка файла: $(basename "$file")"
    
    mkdir -p "$INSTALL_DIR/media"
    cp "$file" "$INSTALL_DIR/media/"
    
    print_success "Файл загружен в $INSTALL_DIR/media/"
    
    # Отправляем запрос на обновление плейлиста
    local upload_port="8181"
    if [ -f "$INSTALL_DIR/audio-player.conf" ]; then
        upload_port=$(. "$INSTALL_DIR/audio-player.conf" 2>/dev/null; echo "${PORT:-8181}")
    fi
    curl -s "http://localhost:$upload_port/api/playlist" > /dev/null 2>&1 || true
}

cmd_list_tracks() {
    print_header
    
    if [ ! -f "$INSTALL_DIR/playlist.json" ]; then
        print_warning "Файл плейлиста не найден"
        return 1
    fi
    
    echo "Треки в плейлисте:"
    echo ""
    
    # Надёжный парсинг JSON с пробелами или без
    grep -E '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$INSTALL_DIR/playlist.json" 2>/dev/null | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' | nl || true
}

cmd_clear_tracks() {
    print_header
    print_warning "Это удалит все треки из плейлиста!"
    echo ""
    printf '%s' "Вы уверены? (y/N): "
    IFS= read -r REPLY || REPLY=""
    echo
    
    case "$REPLY" in
        y|Y) ;;
        *)
            print_info "Отменено"
            return 0
            ;;
    esac
    
    # Очищаем плейлист
    echo '{"items":[]}' > "$INSTALL_DIR/playlist.json"
    
    # Опционально удаляем файлы
    printf '%s' "Удалить также аудиофайлы из папки media? (y/N): "
    IFS= read -r REPLY || REPLY=""
    echo
    
    case "$REPLY" in
        y|Y)
            rm -f "$INSTALL_DIR/media"/* 2>/dev/null || true
            print_success "Файлы удалены"
            ;;
    esac
    
    local clear_port="8181"
    if [ -f "$INSTALL_DIR/audio-player.conf" ]; then
        clear_port=$(. "$INSTALL_DIR/audio-player.conf" 2>/dev/null; echo "${PORT:-8181}")
    fi
    curl -s "http://localhost:$clear_port/api/playlist" > /dev/null 2>&1 || true
    print_success "Плейлист очищен"
}

cmd_info() {
    print_header
    
    printf '%b\n' "${CYAN}Информация об установке:${NC}"
    echo ""
    echo "📍 Главная папка: $INSTALL_DIR"
    echo "📁 Медиа файлы: $INSTALL_DIR/media"
    echo "📋 Плейлист: $INSTALL_DIR/playlist.json"
    echo "📜 Логи: $INSTALL_DIR/logs"
    echo "🔧 Приложение: $INSTALL_DIR/audio-player"
    if [ -f "$INSTALL_DIR/audio-player.conf" ]; then
        echo "🌐 Сетевые настройки: $INSTALL_DIR/audio-player.conf"
    fi
    echo ""
    
    printf '%b\n' "${CYAN}Системная информация:${NC}"
    echo ""
    
    if command -v uname > /dev/null; then
        echo "ОС: $(uname -s)"
        echo "Архитектура: $(uname -m)"
    fi
    
    if command -v go > /dev/null; then
        echo "Go версия: $(go version | cut -d' ' -f3)"
    fi
    
    echo ""
    printf '%b\n' "${CYAN}Проверка компонентов:${NC}"
    echo ""
    
    if [ -f "$INSTALL_DIR/audio-player" ]; then
        local size=$(ls -lh "$INSTALL_DIR/audio-player" | awk '{print $5}')
        print_success "Приложение установлено (размер: $size)"
    else
        print_error "Приложение не найдено"
    fi
    
    if command -v ffplay > /dev/null; then
        print_success "ffplay установлен"
    elif command -v ffmpeg > /dev/null; then
        print_success "ffmpeg установлен"
    elif command -v aplay > /dev/null; then
        print_success "aplay установлен"
    elif command -v mpg123 > /dev/null; then
        print_success "mpg123 установлен"
    else
        print_warning "Плеер не найден (рекомендуется: opkg install ffmpeg alsa-utils mpg123)"
    fi
    
    if [ -d "$INSTALL_DIR/media" ]; then
        local count=$(ls -1 "$INSTALL_DIR/media" 2>/dev/null | wc -l)
        print_success "Папка медиа содержит $count файлов"
    fi
    
    if [ -f "$INSTALL_DIR/playlist.json" ]; then
        print_success "Файл плейлиста существует"
    fi
    
    echo ""
    printf '%b\n' "${CYAN}Размеры:${NC}"
    echo ""
    if [ -f "$INSTALL_DIR/audio-player" ]; then
        echo "Приложение: $(du -h "$INSTALL_DIR/audio-player" 2>/dev/null | cut -f1)"
    fi
    if [ -d "$INSTALL_DIR/media" ]; then
        echo "Медиа: $(du -sh "$INSTALL_DIR/media" 2>/dev/null | cut -f1)"
    fi
    echo "Всего: $(du -sh "$INSTALL_DIR" 2>/dev/null | cut -f1)"
}

cmd_uninstall() {
    if [ -x "$INSTALL_DIR/uninstall.sh" ]; then
        exec "$INSTALL_DIR/uninstall.sh"
    fi

    print_header
    print_warning "Это удалит приложение и все данные!"
    echo ""
    echo "Будут удалены:"
    echo "  - Приложение"
    echo "  - Все аудио файлы"
    echo "  - Плейлист"
    echo "  - Логи"
    echo ""
    
    printf '%s' "Вы уверены? (введите 'yes' для подтверждения): "
    IFS= read -r confirm || confirm=""
    
    if [ "$confirm" != "yes" ]; then
        print_info "Удаление отменено"
        return 0
    fi
    
    # Останавливаем приложение
    cmd_stop 2>/dev/null || true
    
    # Удаляем Entware автозапуск
    ENTWARE_SCRIPT=/opt/etc/init.d/S99audio-player
    ENTWARE_CONFIG=/opt/etc/audio-player-install-dir
    if [ -f "$ENTWARE_CONFIG" ]; then
        if [ -x "$ENTWARE_SCRIPT" ]; then
            "$ENTWARE_SCRIPT" stop >/dev/null 2>&1 || true
            rm -f "$ENTWARE_SCRIPT"
        fi
        rm -f "$ENTWARE_CONFIG"
    fi

    # Удаляем systemd сервис если есть
    if [ -f "/etc/systemd/system/audio-player.service" ]; then
        systemctl stop audio-player 2>/dev/null || true
        systemctl disable audio-player 2>/dev/null || true
        rm -f /etc/systemd/system/audio-player.service 2>/dev/null || true
        systemctl daemon-reload 2>/dev/null || true
    fi
    
    # Удаляем init.d
    if [ -f "/etc/init.d/audio-player" ]; then
        /etc/init.d/audio-player stop 2>/dev/null || true
        rm -f /etc/init.d/audio-player
    fi

    # Удаляем из crontab
    if command -v crontab >/dev/null 2>&1; then
        crontab -l 2>/dev/null | grep -v audio-player | crontab - 2>/dev/null || true
    fi
    
    # Удаляем папку
    rm -rf "$INSTALL_DIR"
    
    print_success "Audio Player удалён"
}

# Главная функция

main() {
    local command="${1:-help}"
    
    case "$command" in
        start)      cmd_start "$@" ;;
        stop)       cmd_stop "$@" ;;
        restart)    cmd_restart "$@" ;;
        status)     cmd_status "$@" ;;
        logs)       cmd_logs "$@" ;;
        logs-follow) cmd_logs_follow "$@" ;;
        upload)     cmd_upload "$@" ;;
        list-tracks|list) cmd_list_tracks "$@" ;;
        clear-tracks) cmd_clear_tracks "$@" ;;
        info)       cmd_info "$@" ;;
        uninstall)  cmd_uninstall "$@" ;;
        help|--help|-h) print_help "$@" ;;
        *)
            print_error "Неизвестная команда: $command"
            echo ""
            print_help
            exit 1
            ;;
    esac
}

main "$@"
