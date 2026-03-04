# Qwen Time Tracker — Контекст для Qwen Code

**Приложение:** Windows, Flutter + Qwen Code CLI + Telegram Bot

---

## 🚀 CLI команды

```bash
# Проекты
qwen_time_tracker.exe add-project "Name" "C:\Path"
qwen_time_tracker.exe activate-project "Name"
qwen_time_tracker.exe list-projects

# Задачи
qwen_time_tracker.exe add-task "Name" --estimate HH:MM --project "Proj" --description "..."
qwen_time_tracker.exe list-tasks --status active|completed|all
qwen_time_tracker.exe start-timer <id|name>
qwen_time_tracker.exe stop-timer <id|name>
qwen_time_tracker.exe delete-task <id|name>

# Рабочий день
qwen_time_tracker.exe start-day
qwen_time_tracker.exe stop-day
qwen_time_tracker.exe status

# Экспорт
qwen_time_tracker.exe export-excel --from YYYY-MM-DD --to YYYY-MM-DD
```

---

## 📱 Telegram Bot

**Команды:**
- `/model` — переключить модель (local/cloud)
- `/model local` — локальная Ollama
- `/model cloud` — облачная Qwen
- `/model stop` — остановить модель
- `/tasks` — список задач
- `/starttask <id>` — запустить таймер
- `/stoptask <id>` — остановить таймер
- `/addtask <name>` — добавить задачу
- `/export` — экспорт Excel

---

## 📦 Модели данных

**Timer:** id, number, name, estimate, durationLeft, isRunning, project  
**Project:** id, name, workingDirectory, sessionId, isActive  
**WorkDay:** startWorkDateTime, endWorkDateTime, freeTime

---

## ⚙️ Конфигурация

**Путь:** `C:\Users\Nikitir\.qwen\settings.json`

**Модели:**
- Локальная: `qwen2.5-coder:7b-instruct-q4_K_M` (Ollama)
- Облачная: `coder-model` (Qwen OAuth)

**Переключение:** Через `switchModel(modelId)` → сброс сессии → новая модель

---

## 📝 Форматирование Telegram

✅ Можно: emoji, `- списки`, простой текст  
❌ Нельзя: `**жирный**`, `*курсив*`, рамки

**Пример:**
```
📋 Задачи (2):
• #1 Fix bug ⏱ 1h 30m
• #2 Add feature ⏱ 2h
```
