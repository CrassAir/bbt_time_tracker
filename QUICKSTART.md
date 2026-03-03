# Краткая инструкция по запуску

## Быстрый старт

```bash
# 1. Перейти в директорию проекта
cd C:\Users\Nikitir\Desktop\Projects\qwen_time_tracker

# 2. Установить зависимости
flutter pub get

# 3. Сгенерировать ObjectBox код
flutter pub run build_runner build --delete-conflicting-outputs

# 4. Запустить приложение
flutter run -d windows
```

## Сборка релизной версии

```bash
flutter build windows --release
```

Собранный exe-файл будет находиться в:
```
build/windows/x64/runner/Release/qwen_time_tracker.exe
```

## Настройка после запуска

### Telegram бот
1. Открыть **Settings** (шестерёнка в sidebar)
2. Ввести **Telegram Bot Token** (получить у @BotFather)
3. Добавить **Allowed User IDs** (ваш Telegram ID)
4. Нажать **Save**

### Qwen CLI (опционально)
1. Открыть **Settings**
2. Указать путь к **Qwen CLI executable**
3. Указать **Working Directory**
4. Нажать **Save**

## Управление приложением

### Горячие клавиши
- **Start Day** — начать рабочий день (11:00 авто-старт)
- **Stop Day** — завершить рабочий день
- **Add Task** — добавить новую задачу
- **Start/Pause** — запустить/пауза таймера
- **Complete** — завершить задачу

### Telegram команды
- `/start` — запустить бота
- `/stop` — остановить бота
- `/status` — статус Qwen сессии
- `/chat` — отправить сообщение в Qwen

## Структура хранения данных

Данные ObjectBox хранятся в:
```
C:\Users\Nikitir\AppData\Local\qwen_time_tracker\
```

Файлы:
- `data.mdb` — база данных
- `lock.mdb` — файл блокировки

## Экспорт данных

### Excel отчёт
1. На Dashboard нажать кнопку **Excel**
2. Файл сохранится в папке Downloads
3. Автоматически откроется в Excel

### Формат отчёта
| Status | Name | Created | Start | End | Estimate | Duration Left | Branch | URL |
|--------|------|---------|-------|-----|----------|---------------|--------|-----|

## Решение проблем

### Приложение не запускается
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Таймеры не сохраняются
Проверить наличие файла `data.mdb` в директории приложения

### Звук не воспроизводится
Проверить наличие файлов:
- `assets/mp3/good_morning_vietnam.mp3`
- `assets/mp3/japanese_attention.mp3`

### Бот не отвечает
1. Проверить токен в Settings
2. Проверить Allowed User IDs
3. Перезапустить бота (Stop → Start)

## Обновление

```bash
git pull
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run -d windows
```
