# claude-skill-getvideo — Технический контекст

## Обзор

Claude Code скилл для скачивания видео с любых платформ (YouTube, Vimeo, Twitter и др.), создания структурированной папки с метаданными и опциональной транскрибации через mlx-whisper с AI-анализом.

Это **не приложение**, а скилл для Claude Code — набор инструкций в формате SKILL.md, которые Claude выполняет при вызове `/getvideo`.

## Стек технологий

**Тип:** Claude Code Skill (markdown-инструкции + bash-утилиты)

**Внешние зависимости:**

| Инструмент | Назначение | Критичность |
|------------|-----------|-------------|
| yt-dlp | Загрузка видео, получение метаданных (`--dump-json`) | обязателен |
| ffmpeg | Извлечение аудио из видео (m4a) | обязателен |
| mlx-whisper | Транскрибация аудио (модель turbo, Apple Silicon) | опционален |
| python3 | Среда для mlx-whisper | опционален |

**Установщик:** `setup.sh` — bash-скрипт, ~320 строк

## Архитектура

**Тип проекта:** не код, а «skill-as-a-package» — репозиторий поставляет SKILL.md + setup.sh.

```
claude-skill-getvideo/
├── skills/getvideo/
│   └── SKILL.md           # Инструкции для Claude (единственный функциональный файл)
├── setup.sh               # Установщик зависимостей + symlink
├── README.md              # English документация
├── README_RU.md           # Русская документация
├── LICENSE                # MIT
└── .gitignore             # Исключает медиафайлы
```

**Механизм работы:**
1. `setup.sh` создаёт symlink: `~/.claude/skills/getvideo` → `<repo>/skills/getvideo`
2. Claude Code обнаруживает скилл по YAML frontmatter в SKILL.md
3. При вызове `/getvideo` Claude читает SKILL.md и выполняет инструкции
4. Claude использует bash-команды (yt-dlp, ffmpeg, mlx_whisper) через Bash tool
5. Результаты сохраняются в `~/getvideo/YYYYMMDD-source-title/`

## Ключевые компоненты

### SKILL.md (`skills/getvideo/SKILL.md`)

Основной файл скилла. Содержит:

- **YAML frontmatter** — имя и описание для автообнаружения Claude Code
- **Graphviz диаграмму** — визуальный flow выполнения
- **4 фазы** — SETUP → DOWNLOAD → ABOUT → TRANSCRIBE
- **Таблицу обработки ошибок** — 6 сценариев с действиями
- **Шаблоны файлов** — about.md, transcript_source.md, transcript_output.md

Фазы выполнения:
1. **SETUP** — валидация URL, получение метаданных через `yt-dlp --dump-json`, создание папки
2. **DOWNLOAD** — загрузка видео через yt-dlp в формате mp4
3. **ABOUT** — генерация about.md с метаданными, описанием, главами, тегами
4. **TRANSCRIBE** (опционально) — ffmpeg → mlx-whisper → AI-анализ через Task subagent

### setup.sh

Интерактивный установщик. Ключевые функции:

- `detect_os()` — определение macOS/Linux
- `has()` — проверка наличия команды
- `confirm()` — интерактивное подтверждение (y/N)
- `install_brew/ytdlp/ffmpeg/python/whisper()` — установка зависимостей (whisper → mlx-whisper)
- `fix_ssl_macos()` — исправление SSL-сертификатов Python на macOS
- `setup_symlink()` — создание/обновление symlink в `~/.claude/skills/`
- `print_summary()` — итоговый отчёт с верификацией

Особенности:
- Поддерживает apt, dnf, pacman на Linux
- Не устанавливает без подтверждения пользователя
- Корректно обрабатывает существующие symlink/директории
- SSL fix: пробует `Install Certificates.command`, fallback на certifi

## Выходные файлы скилла

При выполнении `/getvideo` создаётся:

```
~/getvideo/YYYYMMDD-source-title/
├── video.mp4              # Скачанное видео
├── about.md               # Метаданные (таблица + описание + главы + теги)
├── audio.m4a              # Временный аудио (удаляется по запросу)
├── transcript_source.md   # Сырой транскрипт mlx-whisper
└── transcript_output.md   # AI-анализ: TLDR, идеи, инсайты, TODO
```

Формат имени папки: `YYYYMMDD-domain-sanitized-title` (max 60 символов в title).

## Конфигурация

Скилл не имеет конфигурационных файлов. Все параметры зашиты в SKILL.md:

| Параметр | Значение | Где задано |
|----------|----------|------------|
| Выходная директория | `~/getvideo/` | SKILL.md, Phase 1 |
| Формат видео | `bestvideo[ext=mp4]+bestaudio[ext=m4a]/best` | SKILL.md, Phase 2 |
| Модель mlx-whisper | `mlx-community/whisper-turbo` | SKILL.md, Phase 4 |
| Таймаут mlx-whisper | 600000ms (10 мин) | SKILL.md, Phase 4 |
| Язык транскрибации | `auto` | SKILL.md, Phase 4 |
| Язык AI-анализа | Русский | SKILL.md, Phase 4 prompt |

## Расширение функционала

### Как изменить модель mlx-whisper

В `skills/getvideo/SKILL.md`, Phase 4, секция "Transcribe with mlx-whisper":
- Заменить `--model mlx-community/whisper-turbo` на другую модель из mlx-community

### Как изменить язык AI-анализа

В `skills/getvideo/SKILL.md`, Phase 4, секция "AI analysis":
- Изменить prompt для Task subagent (сейчас: "Напиши анализ на РУССКОМ ЯЗЫКЕ")

### Как добавить поддержку новой ОС

В `setup.sh`:
1. Добавить case в `detect_os()`
2. Добавить ветку в каждую `install_*()` функцию

### Как добавить новый формат вывода

В `skills/getvideo/SKILL.md`:
1. Добавить новую фазу или расширить Phase 3 (ABOUT)
2. Описать шаблон нового файла
3. Добавить в Final Output

## Известные ограничения

- **Apple Silicon only** — mlx-whisper работает только на Apple Silicon (M1+)
- **yt-dlp устаревание** — YouTube часто ломает API, требуется `yt-dlp -U`
- **mlx-whisper RAM** — модели turbo требуют значительного объёма RAM для длинных видео
- **Язык анализа** — AI-анализ жёстко задан на русском в prompt
- **Нет Windows** — setup.sh поддерживает только macOS и Linux

## Ключевые решения

### Почему скилл, а не CLI-приложение?

Скилл работает внутри Claude Code, что даёт:
- AI-генерацию about.md с осмысленным форматированием
- Интерактивность через AskUserQuestion (транскрибация? удалить аудио?)
- AI-анализ транскрипта через Task subagent — невозможно в обычном CLI

### Почему symlink вместо копирования?

Symlink позволяет обновлять скилл через `git pull` без повторной установки.

### Почему mlx-whisper вместо openai-whisper?

openai-whisper требует загрузку моделей через urllib, что ломается из-за SSL на macOS. mlx-whisper использует HuggingFace Hub, работает нативно на Apple Silicon через MLX framework, быстрее и стабильнее.

### Почему turbo модель по умолчанию?

Лучшее соотношение скорости и качества. Base слишком неточна, medium слишком медленна.
