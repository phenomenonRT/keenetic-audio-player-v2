#!/bin/bash

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

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Функции

print_header() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║          🎵 Audio Player Manager                           ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo "Установка: $INSTALL_DIR"
    echo ""
}

print_help() {
    print_header
    echo -e "${YELLOW}Доступные команды:${NC}"
    echo ""
    echo "  ${CYAN}start${NC}              - Запустить приложение"
    echo "  ${CYAN}stop${NC}               - Остановить приложение"
    echo "  ${CYAN}restart${NC}            - Перезагрузить приложение"
    echo "  ${CYAN}status${NC}             - Показать статус"
    echo "  ${CYAN}logs${NC}               - Просмотр логов (последние 20 строк)"
    echo "  ${CYAN}logs-follow${NC}        - Просмотр логов в реальном времени"
    echo "  ${CYAN}upload <file>${NC}      - Загрузить аудио файл"
    echo "  ${CYAN}list-tracks${NC}        - Список всех треков в плейлисте"
    echo "  ${CYAN}clear-tracks${NC}       - Очистить плейлист (опасно!)"
    echo "  ${CYAN}info${NC}               - Информация об установке"
    echo "  ${CYAN}uninstall${NC}          - Удалить приложение"
    echo "  ${CYAN}help${NC}               - Эта справка"
    echo ""
    echo -e "${YELLOW}Примеры:${NC}"
    echo ""
    echo "  $0 start"
    echo "  $0 upload ~/music/song.mp3"
    echo "  $0 logs-follow"
    echo "  $0 status"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Команды

cmd_start() {
    print_header
    print_info "Запуск приложения..."
    
    if pgrep -f "$INSTALL_DIR/audio-player" > /dev/null 2>&1; then
        print_warning "Приложение уже запущено"
        return 0
    fi
    
    cd "$INSTALL_DIR"
    nohup ./audio-player >> logs/audio-player.log 2>&1 &
    
    sleep 2
    
    if pgrep -f "$INSTALL_DIR/audio-player" > /dev/null 2>&1; then
        print_success "Приложение запущено"
        echo ""
        echo "🌐 Откройте браузер: http://localhost:8181"
    else
        print_error "Ошибка запуска приложения"
        echo "Проверьте логи: tail -f $INSTALL_DIR/logs/audio-player.log"
        return 1
    fi
}

cmd_stop() {
    print_header
    print_info "Остановка приложения..."
    
    if ! pgrep -f "$INSTALL_DIR/audio-player" > /dev/null 2>&1; then
        print_warning "Приложение не запущено"
        return 0
    fi
    
    pkill -f "$INSTALL_DIR/audio-player"
    sleep 1
    
    if pgrep -f "$INSTALL_DIR/audio-player" > /dev/null 2>&1; then
        pkill -9 -f "$INSTALL_DIR/audio-player"
        sleep 1
    fi
    
    if ! pgrep -f "$INSTALL_DIR/audio-player" > /dev/null 2>&1; then
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
    
    if pgrep -f "$INSTALL_DIR/audio-player" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Статус: ЗАПУЩЕНО${NC}"
        echo ""
        echo "Информация о процессе:"
        ps aux | grep "$INSTALL_DIR/audio-player" | grep -v grep | awk '{print "  PID: " $2 ", CPU: " $3 "%, MEM: " $4 "%"}'
    else
        echo -e "${RED}⏹️  Статус: ОСТАНОВЛЕНО${NC}"
    fi
    
    echo ""
    echo "Информация о системе:"
    echo "  Установка: $INSTALL_DIR"
    echo "  Музыка: $INSTALL_DIR/media"
    echo "  Конфиг: $INSTALL_DIR/playlist.json"
    echo "  Логи: $INSTALL_DIR/logs"
    
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
    local file="$2"
    
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
    
    cp "$file" "$INSTALL_DIR/media/"
    
    print_success "Файл загружен в $INSTALL_DIR/media/"
    
    # Отправляем запрос на обновление плейлиста
    curl -s http://localhost:8181/api/playlist > /dev/null 2>&1 || true
}

cmd_list_tracks() {
    print_header
    
    if [ ! -f "$INSTALL_DIR/playlist.json" ]; then
        print_warning "Файл плейлиста не найден"
        return 1
    fi
    
    echo "Треки в плейлисте:"
    echo ""
    
    # Простой парсинг JSON для вывода
    grep -o '"name":"[^"]*"' "$INSTALL_DIR/playlist.json" | cut -d'"' -f4 | nl
}

cmd_clear_tracks() {
    print_header
    print_warning "Это удалит все треки из плейлиста!"
    echo ""
    read -p "Вы уверены? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Отмено"
        return 0
    fi
    
    # Очищаем плейлист
    echo '{"items":[]}' > "$INSTALL_DIR/playlist.json"
    
    # Опционально удаляем файлы
    read -p "Удалить также файлы? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$INSTALL_DIR/media"/*
        print_success "Файлы удалены"
    fi
    
    print_success "Плейлист очищен"
}

cmd_info() {
    print_header
    
    echo -e "${CYAN}Информация об установке:${NC}"
    echo ""
    echo "📍 Главная папка: $INSTALL_DIR"
    echo "📁 Медиа файлы: $INSTALL_DIR/media"
    echo "📋 Плейлист: $INSTALL_DIR/playlist.json"
    echo "📜 Логи: $INSTALL_DIR/logs"
    echo "🔧 Приложение: $INSTALL_DIR/audio-player"
    echo ""
    
    echo -e "${CYAN}Системная информация:${NC}"
    echo ""
    
    if command -v uname > /dev/null; then
        echo "ОС: $(uname -s)"
        echo "Архитектура: $(uname -m)"
    fi
    
    if command -v go > /dev/null; then
        echo "Go версия: $(go version | cut -d' ' -f3)"
    fi
    
    echo ""
    
    echo -e "${CYAN}Проверка компонентов:${NC}"
    echo ""
    
    if [ -f "$INSTALL_DIR/audio-player" ]; then
        local size=$(ls -lh "$INSTALL_DIR/audio-player" | awk '{print $5}')
        print_success "Приложение установлено (размер: $size)"
    else
        print_error "Приложение не найдено"
    fi
    
    if command -v ffplay > /dev/null; then
        print_success "ffplay установлен"
    elif command -v aplay > /dev/null; then
        print_success "aplay установлен"
    elif command -v mpg123 > /dev/null; then
        print_success "mpg123 установлен"
    else
        print_warning "Плеер не найден"
    fi
    
    if [ -d "$INSTALL_DIR/media" ]; then
        local count=$(ls -1 "$INSTALL_DIR/media" 2>/dev/null | wc -l)
        print_success "Папка медиа содержит $count файлов"
    fi
    
    if [ -f "$INSTALL_DIR/playlist.json" ]; then
        print_success "Файл плейлиста существует"
    fi
    
    echo ""
    echo -e "${CYAN}Размеры:${NC}"
    echo ""
    echo "Приложение: $(du -h "$INSTALL_DIR/audio-player" 2>/dev/null | cut -f1)"
    echo "Медиа: $(du -sh "$INSTALL_DIR/media" 2>/dev/null | cut -f1)"
    echo "Всего: $(du -sh "$INSTALL_DIR" 2>/dev/null | cut -f1)"
}

cmd_uninstall() {
    print_header
    print_warning "Это удалит приложение и все данные!"
    echo ""
    echo "Будут удалены:"
    echo "  - Приложение"
    echo "  - Все аудио файлы"
    echo "  - Плейлист"
    echo "  - Логи"
    echo ""
    
    read -p "Вы уверены? (укажите 'yes' для подтверждения): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "Удаление отменено"
        return 0
    fi
    
    # Останавливаем приложение
    pkill -f "$INSTALL_DIR/audio-player" || true
    
    # Удаляем systemd сервис если есть
    if [ -f "/etc/systemd/system/audio-player.service" ]; then
        sudo systemctl stop audio-player 2>/dev/null || true
        sudo systemctl disable audio-player 2>/dev/null || true
        sudo rm /etc/systemd/system/audio-player.service 2>/dev/null || true
        sudo systemctl daemon-reload 2>/dev/null || true
    fi
    
    # Удаляем из crontab
    crontab -l 2>/dev/null | grep -v audio-player | crontab - 2>/dev/null || true
    
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
