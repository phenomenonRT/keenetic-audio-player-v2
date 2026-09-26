# 🚀 Быстрый старт Audio Player v2.0

## ⚡ За 5 минут до запуска

### Шаг 1: Подготовка (на ПК)
```bash
# Скачайте файлы проекта и перейдите в папку
cd ~/audio-player
ls -la
# Должны быть:
# - keenetic-audio-player-v2.go
# - install.sh
# - README-v2.md
```

### Шаг 2: Запуск инсталлятора
```bash
chmod +x install.sh
./install.sh
```

### Шаг 3: Выбор параметров
```
Следуйте меню инсталлятора:
1. Выберите архитектуру (ARM7 для большинства Keenetic)
2. Выберите путь установки (/mnt/sda1/audio-player для роутера)
3. Выберите способ автозапуска (crontab для Keenetic)
4. Приложение скомпилируется и установится
5. Будет предложено запустить его
```

### Шаг 4: Открыть в браузере
```
http://localhost:8080    (если на этом же ПК)
http://192.168.1.1:8080  (если на роутере)
```

### Шаг 5: Добавить музыку
```
1. Откройте веб-интерфейс
2. Перетащите MP3/WAV файлы в зону загрузки
3. Они появятся в плейлисте
4. Нажмите "Играть" для воспроизведения
```

**Готово! 🎉**

---

## 📋 Сценарии установки

### Сценарий 1: Роутер Keenetic

```bash
# На ПК
./install.sh

# Выбрать:
# 1) ARM7 (для большинства моделей)
# 2) /mnt/sda1/audio-player
# 3) crontab

# Откройте: http://192.168.1.1:8080
```

### Сценарий 2: Ubuntu/Debian сервер

```bash
# Требует sudo
sudo ./install.sh

# Выбрать:
# 1) ARM/x86/x64 (в зависимости от сервера)
# 2) /opt/audio-player
# 3) systemd сервис

# Команды управления:
systemctl start audio-player
systemctl status audio-player
```

### Сценарий 3: Персональный ПК (Linux)

```bash
./install.sh

# Выбрать:
# 1) x86_64 или ARM64
# 2) ~/audio-player (домашняя папка)
# 3) Crontab или без автозапуска

# Откройте: http://localhost:8080
```

### Сценарий 4: NAS или другой Linux

```bash
./install.sh

# Выбрать нужные параметры по типу вашего устройства
# Обычно /mnt или /data для хранилища
```

---

## 🎵 Основные операции

### Запуск / Остановка

```bash
# Используя скрипт управления (если установлен)
./audio-player.sh start     # Запустить
./audio-player.sh stop      # Остановить
./audio-player.sh restart   # Перезагрузить
./audio-player.sh status    # Статус

# Прямой запуск
/opt/audio-player/audio-player

# Systemd (если используется)
systemctl start audio-player
systemctl stop audio-player
```

### Просмотр логов

```bash
# Последние 20 строк
./audio-player.sh logs

# В реальном времени
./audio-player.sh logs-follow

# Или напрямую
tail -f /opt/audio-player/logs/audio-player.log
```

### Управление музыкой

```bash
# Скопировать файл
./audio-player.sh upload ~/Music/song.mp3

# Список всех треков
./audio-player.sh list-tracks

# Или через браузер - просто перетащите файл
```

### Информация о системе

```bash
./audio-player.sh info
./audio-player.sh status
```

---

## 🌐 Веб-интерфейс

### Загрузка файлов

**Способ 1: Drag-Drop**
```
1. Откройте http://localhost:8080
2. Найдите блок "Добавить аудио"
3. Перетащите файлы в зону
4. Они автоматически добавятся в плейлист
```

**Способ 2: Клик**
```
1. Нажмите на зону загрузки
2. Выберите файлы через диалог
3. Подтвердите выбор
```

### Управление плейлистом

```
Для каждого трека доступны кнопки:
▶️ Играть    - запустить воспроизведение
🗑️ Удалить  - удалить из плейлиста и диска

Глобальные кнопки:
⏹️ Остановить - остановить воспроизведение
```

### Информация

```
Справа показывается:
- Количество треков в плейлисте
- Текущий воспроизводимый трек
- Дата добавления каждого трека
```

---

## 🔧 API примеры

### cURL команды

```bash
# Получить плейлист
curl http://localhost:8080/api/playlist | jq

# Загрузить файл
curl -F "audio=@song.mp3" -F "name=My Song" \
  http://localhost:8080/api/add-track

# Воспроизвести трек (ID из плейлиста)
curl "http://localhost:8080/api/play?id=track_1234567890"

# Остановить
curl http://localhost:8080/api/stop

# Удалить трек
curl "http://localhost:8080/api/remove-track?id=track_1234567890"

# Обновить название
curl "http://localhost:8080/api/update-track?id=track_1234567890&name=New%20Name"
```

### JavaScript

```javascript
// Загрузить и отправить
const formData = new FormData();
formData.append('audio', fileInput.files[0]);
formData.append('name', 'My Song');

fetch('/api/add-track', {
    method: 'POST',
    body: formData
}).then(r => r.json()).then(data => {
    console.log('Трек добавлен:', data.id);
});

// Воспроизвести
fetch('/api/play?id=track_123')
    .then(r => r.json())
    .then(data => console.log('Воспроизведение:', data.status));

// Получить плейлист
fetch('/api/playlist')
    .then(r => r.json())
    .then(data => console.log('Всего треков:', data.items.length));
```

### Python

```python
import requests
import json

# Загрузить файл
files = {'audio': open('song.mp3', 'rb')}
data = {'name': 'My Song'}
response = requests.post('http://localhost:8080/api/add-track', 
                        files=files, data=data)
print(response.json())

# Получить плейлист
response = requests.get('http://localhost:8080/api/playlist')
tracks = response.json()['items']
print(f'Всего треков: {len(tracks)}')

# Воспроизвести
response = requests.get('http://localhost:8080/api/play?id=track_123')
print(response.json())
```

---

## 📁 Структура файлов после установки

```
/opt/audio-player/              # Папка установки
├── audio-player                # Исполняемый файл (~4-5 МБ)
├── start.sh                     # Скрипт быстрого запуска
├── playlist.json                # Сохранённый плейлист
├── logs/
│   └── audio-player.log         # Логи приложения
└── media/                       # Аудио файлы
    ├── song1.mp3
    ├── song2.wav
    └── ...
```

---

## 🐛 Частые проблемы и решения

### Проблема 1: "Плеер не найден"

```bash
# Решение: установить ffmpeg
# На Ubuntu/Debian
sudo apt install ffmpeg

# На Keenetic
opkg install ffmpeg

# На CentOS
sudo yum install ffmpeg
```

### Проблема 2: Приложение не стартует

```bash
# Проверьте логи
tail -f /opt/audio-player/logs/audio-player.log

# Проверьте права
ls -la /opt/audio-player/audio-player

# Проверьте порт
netstat -tulpn | grep 8080
```

### Проблема 3: Не могу загрузить файлы

```bash
# Проверьте права на папку медиа
ls -la /opt/audio-player/media

# Добавьте прав если нужно
chmod 777 /opt/audio-player/media

# Проверьте свободное место
df -h /opt/audio-player
```

### Проблема 4: Плейлист не сохраняется

```bash
# Проверьте файл конфига
cat /opt/audio-player/playlist.json

# Проверьте права
chmod 666 /opt/audio-player/playlist.json

# Пересоздайте конфиг
echo '{"items":[]}' > /opt/audio-player/playlist.json
```

### Проблема 5: Не вижу интерфейс

```bash
# Проверьте что приложение запущено
ps aux | grep audio-player

# Проверьте доступность порта
curl http://localhost:8080

# Перезагрузите браузер
# Очистите кэш браузера (Ctrl+Shift+Delete)
```

---

## 🔄 Автоматические обновления

Если хотите обновить приложение:

```bash
# 1. Скачайте новую версию исходного кода
# 2. Остановите приложение
./audio-player.sh stop

# 3. Пересоберите
GOOS=linux GOARCH=arm GOARM=7 go build -o audio-player keenetic-audio-player-v2.go

# 4. Скопируйте новый файл
cp audio-player /opt/audio-player/

# 5. Запустите
./audio-player.sh start
```

---

## 📊 Примеры использования

### Пример 1: Музыка в офисе

```
1. Установите на NAS/сервер
2. Загрузите плейлист через веб-интерфейс
3. Откройте на смартфоне http://IP:8080
4. Управляйте с мобильного устройства
```

### Пример 2: Система объявлений на Keenetic

```
1. Установите на роутер
2. Добавьте MP3 файлы (объявления)
3. Вызывайте воспроизведение через API
4. Система проиграет объявление через динамики роутера
```

### Пример 3: Медиа-центр на ПК

```
1. Установите на домашнем сервере
2. Загрузите всю музыкотеку
3. Открывайте с любого устройства в сети
4. Слушайте через встроенный плеер
```

### Пример 4: Интеграция со сценариями

```bash
# Скрипт, который воспроизводит звук каждый час
#!/bin/bash
while true; do
    sleep 3600
    curl "http://localhost:8080/api/play?id=bell"
done
```

---

## 💡 Советы профессионалов

### Для Keenetic

1. **Используйте USB накопитель** в пути `/mnt/sda1/audio-player`
2. **Включите автозапуск** через crontab
3. **Установите ffmpeg** для лучшего качества звука
4. **Проверяйте свободное место** на USB

### Для Linux сервера

1. **Используйте systemd** для автоматического управления
2. **Настройте logrotate** для управления логами
3. **Используйте nginx** как обратный прокси
4. **Добавьте SSL** для безопасного доступа

### Для ПК

1. **Создайте ярлык** для быстрого запуска
2. **Используйте localhost:8080** в закладках браузера
3. **Настройте запуск** при загрузке системы

---

## 🎯 Что дальше?

- ✅ Прочитайте полную документацию в README-v2.md
- ✅ Изучите API endpoints для интеграции
- ✅ Экспериментируйте с различными форматами файлов
- ✅ Создавайте собственные скрипты управления

**Наслаждайтесь музыкой! 🎵**


## Установка готовой сборки с GitHub

Установщик загружает бинарник для Linux с последнего GitHub Release; Go на устройстве не требуется. Сначала опубликуйте релиз тегом вида v1.0.0, затем запустите:

```bash
curl -fsSL https://raw.githubusercontent.com/phenomenonRT/keenetic-audio-player-v2/main/install.sh -o install.sh
bash install.sh
```

Опубликуйте тег командой `git tag v1.0.0` и отправьте его в GitHub командой `git push origin v1.0.0`. GitHub Actions соберёт бинарники и создаст Release автоматически.

Поддерживаются также ARMv6, PowerPC 64-bit LE, RISC-V 64-bit и MIPS (включая MIPS 24KEc: mipsel soft-float). Для MIPS с FPU можно перед установкой задать `AUDIO_PLAYER_MIPS_FLOAT=hardfloat` в окружении.
