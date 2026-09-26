# 🚀 Как запустить Audio Player

## Способ 1: Прямой запуск (рекомендуется)

```bash
# Без компиляции (Go запустит интерпретатор)
go run keenetic-audio-player-v2.go

# Или через модули
go run ./keenetic-audio-player-v2.go
```

## Способ 2: Компиляция и запуск

```bash
# Скомпилировать
go build -o audio-player keenetic-audio-player-v2.go

# Запустить скомпилированный файл
./audio-player
```

## Способ 3: Компиляция для конкретной платформы

```bash
# Для Keenetic ARM7
GOOS=linux GOARCH=arm GOARM=7 go build -o audio-player keenetic-audio-player-v2.go

# Для ARM64
GOOS=linux GOARCH=arm64 go build -o audio-player keenetic-audio-player-v2.go

# Для x86_64 (ПК)
GOOS=linux GOARCH=amd64 go build -o audio-player keenetic-audio-player-v2.go

# Для macOS
GOOS=darwin GOARCH=arm64 go build -o audio-player keenetic-audio-player-v2.go
```

## Требования

✅ **Установленный Go:**
```bash
# Проверьте версию
go version

# Требуется Go 1.16+
# Скачайте с https://golang.org/dl/
```

✅ **Установленный плеер:**
```bash
# Ubuntu/Debian
sudo apt install ffmpeg

# Keenetic
opkg install ffmpeg

# CentOS
sudo yum install ffmpeg

# macOS
brew install ffmpeg
```

## Если получаете ошибку "go: command not found"

Это значит что Go не установлен. Установите:

### На Linux (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install golang-go
```

### На macOS
```bash
brew install go
```

### На Windows
Скачайте с https://golang.org/dl/ и установите

### На Keenetic
```bash
# Go обычно не нужен на роутере
# Используйте компиляцию на ПК и загрузку готового файла
```

## Быстрый старт

```bash
# 1. Установите Go (если ещё нет)
# 2. Перейдите в папку проекта
cd ~/audio-player

# 3. Запустите
go run keenetic-audio-player-v2.go

# 4. Откройте браузер
# http://localhost:8080
```

## Если хотите использовать инсталлятор

```bash
chmod +x install.sh
./install.sh

# Инсталлятор сам скомпилирует и установит приложение
```

## Структура после запуска

Приложение автоматически создаст:
```
./media/           ← папка для аудио файлов
./playlist.json    ← плейлист (создаётся автоматически)
./logs/            ← папка для логов (если используется)
```

## Проверка что работает

```bash
# 1. Приложение запущено если видите:
# 🎵 ════════════════════════════════════════════════════════════
#     Keenetic Audio Player v2.0
# ════════════════════════════════════════════════════════════

# 2. Откройте http://localhost:8080 в браузере
```

## Остановка приложения

```bash
# Нажмите Ctrl+C в терминале
```

---

**Всё готово! Наслаждайтесь музыкой! 🎵**
