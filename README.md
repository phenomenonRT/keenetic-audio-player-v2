# 🎵 Keenetic Audio Player v2.0

Профессиональный веб-плеер для роутеров Keenetic и Linux систем с красивым интерфейсом, управлением плейлистом и загрузкой файлов через браузер.

## ✨ Возможности

### Основные
- 🎧 Воспроизведение MP3, WAV, FLAC, M4A файлов
- 📱 Адаптивный дизайн для ПК и смартфонов
- 📤 Загрузка аудио файлов через веб-интерфейс (drag-drop)
- 🎵 Управление плейлистом
- ✏️ Редактирование названий треков
- 📊 Информация о количестве треков
- 🔄 Автоматическое сохранение плейлиста

### Интеграция
- REST API для управления
- Поддержка разных плееров (ffplay, aplay, mpg123)
- Работает с разными архитектурами (ARM, ARM64, x86)
- Работает на роутерах Keenetic, Linux серверах, ПК

## 🚀 Быстрая установка

### На Keenetic роутере

```bash
# 1. На ПК (в папке с файлами)
chmod +x install.sh
./install.sh

# 2. Выберите:
#    - Путь установки (рекомендуется /mnt/sda1/audio-player)
#    - Способ автозапуска (crontab для роутера)

# 3. Откройте браузер
# http://192.168.1.1:8181
```
## Установка готовой сборки с GitHub

Установщик загружает бинарник для Linux со [страницы GitHub Releases](https://github.com/phenomenonRT/keenetic-audio-player-v2/releases); Go на устройстве не требуется. Запустите команду на Keenetic или Linux устройстве — установщик предложит выбрать последний релиз или ввести тег версии:

```bash
curl -fsSL https://raw.githubusercontent.com/phenomenonRT/keenetic-audio-player-v2/main/install-from-release.sh -o /tmp/audio-player-install.sh && sh /tmp/audio-player-install.sh
```

На Keenetic с Entware установщик автоматически обнаруживает `/opt/etc/init.d/rc.unslung` и добавляет `S99audio-player` в `/opt/etc/init.d`. `rc.unslung` будет запускать плеер при старте Entware; `sudo` не нужен. Для ручного управления используйте `/opt/etc/init.d/S99audio-player start|stop|restart`.

Для установки конкретного релиза без запроса, например `v1.0.0`:

```bash
curl -fsSL https://raw.githubusercontent.com/phenomenonRT/keenetic-audio-player-v2/main/install-from-release.sh -o /tmp/audio-player-install.sh && AUDIO_PLAYER_VERSION=v1.0.0 sh /tmp/audio-player-install.sh
```

Опубликуйте тег командой `git tag v1.0.0` и отправьте его в GitHub командой `git push origin v1.0.0`. GitHub Actions соберёт бинарники и создаст Release автоматически.

Поддерживаются также ARMv6, PowerPC 64-bit LE, RISC-V 64-bit и MIPS (включая MIPS 24KEc: mipsel soft-float). Для MIPS с FPU можно перед установкой задать `AUDIO_PLAYER_MIPS_FLOAT=hardfloat` в окружении.


### На Linux системе (Ubuntu, Debian, CentOS)

Запускайте установщик от root или через `sudo`:

```bash
chmod +x install.sh
sudo ./install.sh

# Выберите вариант установки:
# 1) /opt/audio-player (рекомендуется)
# 2) systemd сервис (автоматический запуск)
```

### На ПК (macOS/Linux)

```bash
chmod +x install.sh
./install.sh

# Выберите папку в домашней директории
```

## 📦 Структура проекта после установки

```
/папка_установки/
├── audio-player           # Скомпилированное приложение
├── start.sh              # Скрипт запуска
├── playlist.json         # Сохранённый плейлист
├── media/                # Папка с аудио файлами
│   ├── song1.mp3
│   ├── song2.wav
│   └── ...
└── logs/                 # Логи приложения
```

## 🎨 Веб-интерфейс

### Особенности дизайна
- 🌈 Красивый градиент (фиолетовый → синий)
- 📱 Полностью адаптивный для всех устройств
- ⚡ Быстрая загрузка и отклик
- 🎯 Интуитивный интерфейс
- ✨ Гладкие анимации

### Функции интерфейса

#### Загрузка файлов
- Перетащите файлы в зону (drag-drop)
- Или нажмите на зону для выбора
- Поддерживаемые форматы: MP3, WAV, FLAC, M4A
- Файлы автоматически сохраняются и добавляются в плейлист

#### Управление плейлистом
- ✏️ Редактирование названий треков
- 🗑️ Удаление треков
- ▶️ Быстрый запуск из плейлиста
- 📊 Просмотр информации

#### Управление воспроизведением
- ▶️ Запуск трека одним кликом
- ⏹️ Остановка воспроизведения
- 📱 Индикатор текущего трека
- 🎵 Информация о количестве треков

## 🔧 API endpoints

### Получить плейлист
```bash
GET /api/playlist

# Ответ
{
  "items": [
    {
      "id": "track_1234567890",
      "name": "My Song",
      "filename": "my-song.mp3",
      "path": "/opt/audio-player/media/123_my-song.mp3",
      "added": 1624123456
    }
  ]
}
```

### Добавить трек
```bash
POST /api/add-track
Content-Type: multipart/form-data

audio: [binary file]
name: "Track Name" (опционально)

# Ответ
{
  "status": "success",
  "id": "track_1234567890",
  "name": "Track Name"
}
```

### Воспроизвести трек
```bash
GET /api/play?id=track_1234567890

# Ответ
{
  "status": "playing",
  "track": "track_1234567890"
}
```

### Остановить воспроизведение
```bash
GET /api/stop

# Ответ
{
  "status": "stopped"
}
```

### Удалить трек
```bash
GET /api/remove-track?id=track_1234567890

# Ответ
{
  "status": "deleted"
}
```

### Обновить название трека
```bash
GET /api/update-track?id=track_1234567890&name=New%20Name

# Ответ
{
  "status": "updated"
}
```

## ⚙️ Конфигурация

### Структура playlist.json

```json
{
  "items": [
    {
      "id": "track_1624123456789",
      "name": "Song Title",
      "filename": "1624123456789_song.mp3",
      "path": "/opt/audio-player/media/1624123456789_song.mp3",
      "added": 1624123456
    }
  ]
}
```

### Изменение параметров

Отредактируйте исходный код (`keenetic-audio-player-v2.go`):

```go
const (
    RELATIVE_MEDIA_DIR = "media"    // Название папки с музыкой
    RELATIVE_CONFIG    = "playlist.json" // Название файла плейлиста
    PORT               = ":8181"    // Порт сервера
)
```

Затем пересоберите:
```bash
GOOS=linux GOARCH=arm GOARM=7 go build -o audio-player keenetic-audio-player-v2.go
```

## 🖥️ Управление из командной строки

### Запуск приложения
```bash
# Вариант 1: Прямой запуск
/opt/audio-player/audio-player

# Вариант 2: Через скрипт
/opt/audio-player/start.sh

# Вариант 3: Systemd (если установлен)
systemctl start audio-player
```

### Просмотр статуса
```bash
# Systemd
systemctl status audio-player

# Процесс
ps aux | grep audio-player

# Логи
tail -f /opt/audio-player/logs/audio-player.log
```

### Остановка
```bash
# Systemd
systemctl stop audio-player

# Процесс
pkill -f audio-player

# На роутере
killall audio-player
```

### Перезагрузка
```bash
systemctl restart audio-player
```

## 🔌 Примеры использования

### JavaScript (из веб-страницы)

```javascript
// Загрузить плейлист
fetch('/api/playlist')
  .then(r => r.json())
  .then(data => console.log(data.items));

// Воспроизвести трек
fetch('/api/play?id=track_123')
  .then(r => r.json());

// Остановить
fetch('/api/stop');
```

### curl и API

```bash
# Получить плейлист
curl http://localhost:8181/api/playlist | jq

# Загрузить файл
curl -F "audio=@song.mp3" -F "name=My Song" \
  http://localhost:8181/api/add-track

# Воспроизвести
curl "http://localhost:8181/api/play?id=track_123"

# Остановить
curl http://localhost:8181/api/stop
```

## 🐛 Решение проблем

### Проблема: "Плеер не найден на системе"

**Решение:**
```bash
# На Keenetic
opkg update
opkg install ffmpeg

# На Ubuntu/Debian
sudo apt update
sudo apt install ffmpeg

# На CentOS/RHEL
sudo yum install ffmpeg

# На Arch
sudo pacman -S ffmpeg
```

### Проблема: Приложение не запускается

**Проверить:**
```bash
# 1. Права доступа
ls -la /opt/audio-player/audio-player

# 2. Логи
cat /opt/audio-player/logs/audio-player.log

# 3. Процесс
ps aux | grep audio-player

# 4. Порт
netstat -tulpn | grep 8181
```

### Проблема: Не удаётся загрузить файлы

**Проверить:**
```bash
# 1. Права на папку
ls -la /opt/audio-player/media

# 2. Свободное место
df -h /opt/audio-player

# 3. Максимальный размер файла (100 МБ в коде)
```

### Проблема: Плейлист не сохраняется

**Проверить:**
```bash
# 1. Существует ли файл
ls -la /opt/audio-player/playlist.json

# 2. Права на запись
touch /opt/audio-player/playlist.json
```

## 🔐 Безопасность

- ✅ Валидация типов файлов (по расширению)
- ✅ Ограничение размера файла (100 МБ)
- ✅ Очистка имён файлов (добавляется timestamp)
- ✅ Защита от directory traversal
- ⚠️ Приложение работает локально в сети

### Для публичного доступа:
- Используйте обратный прокси (nginx, Apache)
- Установите SSL сертификат
- Добавьте аутентификацию
- Используйте firewall

## 📊 Требования

### Минимальные
- Linux ядро 2.6+
- 10 МБ свободного места
- 512 МБ RAM
- Go 1.16+ (только для компиляции)

### Для оптимальной работы
- 50+ МБ свободного места
- 1+ ГБ RAM
- Установленный ffmpeg

## 🛠️ Компиляция для разных систем

```bash
# ARM7 (новые Keenetic)
GOOS=linux GOARCH=arm GOARM=7 go build -o audio-player keenetic-audio-player-v2.go

# ARM5 (старые Keenetic)
GOOS=linux GOARCH=arm GOARM=5 go build -o audio-player keenetic-audio-player-v2.go

# ARM64 (современные системы)
GOOS=linux GOARCH=arm64 go build -o audio-player keenetic-audio-player-v2.go

# x86_64 (ПК/серверы)
GOOS=linux GOARCH=amd64 go build -o audio-player keenetic-audio-player-v2.go

# macOS ARM64
GOOS=darwin GOARCH=arm64 go build -o audio-player keenetic-audio-player-v2.go

# macOS x86_64
GOOS=darwin GOARCH=amd64 go build -o audio-player keenetic-audio-player-v2.go
```

## 📝 Лицензия

Свободное использование и модификация для личных целей.

## 🎯 Дальнейшие улучшения

Возможные добавления:
- 🎼 Создание плейлистов
- 🔊 Регулировка громкости
- ⏱️ Таймер сна
- 🎛️ Эквалайзер
- 🔄 Повтор и перемешивание
- 📊 Статистика прослушиваний
- 🎨 Темы оформления

## 📞 Поддержка

Если возникли проблемы:
1. Проверьте логи приложения
2. Убедитесь что установлены все зависимости
3. Проверьте наличие свободного места на диске
4. Перезагрузитесь
5. Переустановите приложение

Удачи! 🎵
