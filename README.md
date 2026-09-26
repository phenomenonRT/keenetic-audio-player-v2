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
# Откройте с компьютера или телефона: http://192.168.1.1:8181
```
## Установка готовой сборки с GitHub

Установщик загружает бинарник для Linux со [страницы GitHub Releases](https://github.com/phenomenonRT/keenetic-audio-player-v2/releases); Go на устройстве не требуется. Запустите команду на Keenetic или Linux устройстве — установщик предложит выбрать последний релиз или ввести тег версии:

```bash
curl -fsSL https://raw.githubusercontent.com/phenomenonRT/keenetic-audio-player-v2/main/install-from-release.sh -o /tmp/audio-player-install.sh && sh /tmp/audio-player-install.sh
```

На Keenetic с Entware установщик автоматически обнаруживает `/opt/etc/init.d/rc.unslung` и добавляет `S99audio-player` в `/opt/etc/init.d`. `rc.unslung` будет запускать плеер при старте Entware; `sudo` не нужен. Для ручного управления используйте `/opt/etc/init.d/S99audio-player start|stop|restart`.

Чтобы удалить приложение вместе с настройками, музыкой и логами, в root-консоли роутера запустите:

```sh
/opt/audio-player/uninstall.sh
```

Деинсталлятор остановит Entware-автозапуск и попросит подтвердить удаление вводом `yes`. Удаление системных файлов выполняется без `sudo` из root-консоли. Для уже установленной старой версии, где деинсталлятора ещё нет, скачайте его так:

```sh
curl -fsSL https://raw.githubusercontent.com/phenomenonRT/keenetic-audio-player-v2/main/uninstall.sh -o /tmp/audio-player-uninstall.sh && sh /tmp/audio-player-uninstall.sh
```

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

## 🌐 Настройка сети (интерфейс, IP домашней сети, localhost)

Установщик поддерживает интерактивный режим, в котором можно выбрать сетевой интерфейс и режим привязки сервера:

```bash
./install.sh -i
# или через готовую сборку с GitHub:
curl -fsSL https://raw.githubusercontent.com/phenomenonRT/keenetic-audio-player-v2/main/install-from-release.sh -o /tmp/audio-player-install.sh && sh /tmp/audio-player-install.sh -i
```

В интерактивном режиме будет предложено:
1. **Интерфейс домашней сети** — `auto` (автоопределение `br0` на Keenetic / `br-lan` на OpenWrt / интерфейса маршрута по умолчанию), либо конкретный интерфейс из списка, либо ввод вручную.
2. **Порт веб-интерфейса** (по умолчанию `8181`).
3. **Режим привязки (BIND_ADDR)**:
   - `0.0.0.0` — слушать сразу на всех интерфейсах: домашняя сеть и `localhost` одним слушателем (по умолчанию, рекомендуется).
   - `auto` — слушать только на IP выбранного выше интерфейса домашней сети; при этом `127.0.0.1`/`localhost` **всё равно поднимается отдельным слушателем и остаётся доступен всегда**, независимо от выбранного интерфейса.

То же самое можно задать без интерактивного режима, через параметры командной строки или переменные окружения:

```bash
./install.sh --interface br0 --port 8181 --bind auto
# эквивалентно:
AUDIO_PLAYER_INTERFACE=br0 AUDIO_PLAYER_PORT=8181 AUDIO_PLAYER_BIND=auto ./install.sh
```

Выбор сохраняется в `audio-player.conf` внутри папки установки и подхватывается при каждом запуске (через `start.sh`, `audio-player.sh start`, автозапуск Entware/systemd/cron) — то есть интерфейс и IP домашней сети определяются заново при каждом старте приложения, а не жёстко прошиты один раз при установке. Изменить их позже можно, отредактировав `audio-player.conf` и перезапустив (`audio-player.sh restart`):

```
NETWORK_INTERFACE="auto"   # auto, br0, br-lan, eth0, ...
PORT="8181"
BIND_ADDR="0.0.0.0"        # 0.0.0.0 | auto | <конкретный IP> | 127.0.0.1
```

Локальный доступ через `http://127.0.0.1:8181` и `http://localhost:8181` гарантированно работает при любом из этих режимов (кроме случая, когда `BIND_ADDR=127.0.0.1` явно выбран для полного отключения доступа из домашней сети). Итоговый определённый IP домашней сети и все адреса, на которых слушает сервер, выводятся при каждом запуске в лог: `logs/audio-player.log` (или `audio-player.sh status`).

## 📦 Структура проекта после установки

```
/папка_установки/
├── audio-player           # Скомпилированное приложение
├── audio-player.conf      # Настройки сети: интерфейс, порт, режим привязки
├── start.sh               # Скрипт запуска (подхватывает audio-player.conf)
├── playlist.json          # Сохранённый плейлист
├── media/                 # Папка с аудио файлами
│   ├── song1.mp3
│   ├── song2.wav
│   └── ...
└── logs/                  # Логи приложения
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

### Сетевые настройки (audio-player.conf)

См. раздел [🌐 Настройка сети](#-настройка-сети-интерфейс-ip-домашней-сети-localhost) выше — `NETWORK_INTERFACE`, `PORT` и `BIND_ADDR` задаются при установке и хранятся в `audio-player.conf`, откуда их подхватывают `start.sh`, `audio-player.sh` и все варианты автозапуска при каждом старте.

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

### Изменение параметров по умолчанию

Отредактируйте исходный код (`keenetic-audio-player-v2-enhanced.go`):

```go
const (
    RELATIVE_MEDIA_DIR = "media"         // Название папки с музыкой
    RELATIVE_CONFIG    = "playlist.json" // Название файла плейлиста
    DEFAULT_PORT       = "8181"          // Порт по умолчанию, если PORT не задан
    DEFAULT_BIND_ADDR  = "0.0.0.0"       // Режим привязки по умолчанию
    DEFAULT_INTERFACE  = "auto"          // Интерфейс по умолчанию
)
```

Затем пересоберите:
```bash
GOOS=linux GOARCH=arm GOARM=7 go build -o audio-player keenetic-audio-player-v2-enhanced.go
```

## 🖥️ Управление из командной строки

### Запуск приложения
```bash
# Вариант 1: Прямой запуск (без audio-player.conf, настройки по умолчанию)
/opt/audio-player/audio-player

# Вариант 2: Через скрипт (подхватывает audio-player.conf)
/opt/audio-player/start.sh

# Вариант 3: Через менеджер (тоже подхватывает audio-player.conf)
/opt/audio-player/audio-player.sh start

# Вариант 4: Systemd (если установлен)
systemctl start audio-player
```

### Просмотр статуса
```bash
# Через менеджер (покажет также текущие сетевые настройки)
/opt/audio-player/audio-player.sh status

# Systemd
systemctl status audio-player

# Процесс
ps aux | grep audio-player

# Логи (показывают выбранный интерфейс и итоговые IP/порты при старте)
tail -f /opt/audio-player/logs/audio-player.log
```

### Остановка
```bash
# Через менеджер
/opt/audio-player/audio-player.sh stop

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
# или
/opt/audio-player/audio-player.sh restart
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
# Замените адрес на IP своего роутера
PLAYER_URL=http://192.168.1.1:8181

# Получить плейлист
curl "$PLAYER_URL/api/playlist" | jq

# Загрузить файл
curl -F "audio=@song.mp3" -F "name=My Song" \
  "$PLAYER_URL/api/add-track"

# Воспроизвести
curl "$PLAYER_URL/api/play?id=track_123"

# Остановить
curl "$PLAYER_URL/api/stop"
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

### Проблема: Не получается открыть по IP домашней сети, хотя localhost работает

**Проверить:**
```bash
# 1. Какой интерфейс/IP реально определился при старте
cat /opt/audio-player/logs/audio-player.log

# 2. Текущие настройки
cat /opt/audio-player/audio-player.conf

# 3. Если BIND_ADDR=127.0.0.1, доступ из домашней сети отключён специально —
#    поменяйте на 0.0.0.0 или auto и перезапустите:
/opt/audio-player/audio-player.sh restart
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
GOOS=linux GOARCH=arm GOARM=7 go build -o audio-player keenetic-audio-player-v2-enhanced.go

# ARM5 (старые Keenetic)
GOOS=linux GOARCH=arm GOARM=5 go build -o audio-player keenetic-audio-player-v2-enhanced.go

# ARM64 (современные системы)
GOOS=linux GOARCH=arm64 go build -o audio-player keenetic-audio-player-v2-enhanced.go

# x86_64 (ПК/серверы)
GOOS=linux GOARCH=amd64 go build -o audio-player keenetic-audio-player-v2-enhanced.go

# macOS ARM64
GOOS=darwin GOARCH=arm64 go build -o audio-player keenetic-audio-player-v2-enhanced.go

# macOS x86_64
GOOS=darwin GOARCH=amd64 go build -o audio-player keenetic-audio-player-v2-enhanced.go
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
