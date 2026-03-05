# Контекст getvideo skill для Claude

## Обзор

Claude Code skill для полного pipeline: скачивание видео → метаданные → транскрибация → AI-анализ. Не содержит кода — это промпт-инструкция, которую Claude Code исполняет пошагово.

## Расположение

| Что | Путь |
|-----|------|
| Skill definition | `~/.claude/skills/getvideo/SKILL.md` |
| Данные | `~/getvideo/` |
| Документация | `~/.claude/skills/getvideo/README.md`, `CLAUDE.md` |

## Стек инструментов

| Инструмент | Назначение |
|------------|-----------|
| yt-dlp | Скачивание видео + метаданные (--dump-json) |
| ffmpeg | Извлечение аудиодорожки (copy codec, без перекодирования) |
| mlx-whisper | Транскрибация на Apple Silicon (модель: mlx-community/whisper-turbo) |
| Claude subagent | AI-анализ транскрипта (Task, subagent_type: general-purpose) |

## Архитектура

**Тип:** Claude Code skill (промпт-инструкция, не код)

**Паттерн:** Линейный pipeline с опциональными фазами и resume

```
Phase 0: RESUME DETECTION (если путь к папке)
    ↓
Phase 1: SETUP (URL → metadata → folder)
    ↓
Phase 2: DOWNLOAD (yt-dlp → video.mp4)
    ↓
Phase 3: ABOUT (metadata → about.md)
    ↓
Phase 4: TRANSCRIBE (опционально)
    4a: ffmpeg → audio.m4a
    4b: mlx_whisper → audio.txt
    4c: audio.txt → transcript_source.md
    4d: AI analysis → transcript_output.md
    4f: cleanup audio?
    ↓
Final: отчёт пользователю
```

## Resume Mode

Ключевая функция: определение состояния папки по наличию файлов и продолжение с нужной фазы.

**Триггер:** аргумент содержит `/` или `~/getvideo/` или начинается с "resume"

**Матрица состояний:**

| Есть | Нет | Продолжить с |
|------|-----|-------------|
| `transcript_output.md` | — | Всё готово |
| `transcript_source.md` | `transcript_output.md` | AI-анализ (4d) |
| `audio.txt` | `transcript_source.md` | Сохранение транскрипта (4c) |
| `audio.m4a` | `audio.txt` | Whisper (4b) |
| `video.mp4` + `about.md` | `audio.m4a` | Вопрос о транскрибации |
| `video.mp4` | `about.md` | about.md (Phase 3) |

**Метаданные при resume** берутся из `about.md`:
- Title — первый `# heading`
- Source URL — значение из `| Source |`
- Channel — значение из `| Channel |`
- Duration — значение из `| Duration |`

## Формат файлов

### about.md

```markdown
# Video Title

| Field    | Value             |
|----------|-------------------|
| Source   | https://...       |
| Channel  | channel_name      |
| Date     | YYYY-MM-DD        |
| Duration | MM:SS             |
| Views    | number            |
| Likes    | number            |

## Description
...

## Chapters
- 00:00 — ...

## Tags
tag1, tag2, ...
```

### transcript_source.md

```markdown
# Transcript: Video Title

**Source:** URL
**Model:** mlx-whisper turbo
**Language:** detected_language

---

Full transcript text...
```

### transcript_output.md

```markdown
## TLDR
2-3 sentences

## Основные идеи
1. ...

## Инсайты
- ...

## Что стоит попробовать (TODO)
1. ...
```

## Ключевые решения

### Почему mlx-whisper, а не OpenAI API?

Локальная транскрибация на Apple Silicon: бесплатно, приватно, без лимитов. Модель whisper-turbo — оптимальный баланс скорости и качества.

### Почему audio.m4a copy codec?

`ffmpeg -vn -acodec copy` — извлечение аудио без перекодирования. Мгновенно, без потери качества.

### Почему AI-анализ через subagent?

Транскрипты длинных видео (30+ мин) могут быть 40K+ токенов. Subagent изолирует этот контекст от основной сессии.

### Почему транслитерация в именах папок?

Кириллица в путях создаёт проблемы в терминале и некоторых инструментах. Транслитерация + lowercase + hyphens — универсально безопасно.

## Известные ограничения

- mlx-whisper timeout: для видео > 60 мин может не хватить 10-минутного таймаута (используется 600000ms)
- yt-dlp иногда падает на YouTube из-за обновлений JS-защиты — нужно обновлять: `brew upgrade yt-dlp`
- Нет поддержки плейлистов — только отдельные видео
- AI-анализ всегда на русском языке (захардкожен в промпте)

## Расширение функционала

### Как добавить новый источник видео

yt-dlp поддерживает 1000+ сайтов из коробки. Skill не фильтрует по домену — любой URL, который распознает yt-dlp, будет работать. Folder naming берёт `webpage_url_domain` из metadata.

### Как изменить модель whisper

В SKILL.md, Phase 4b: заменить `mlx-community/whisper-turbo` на другую модель из Hub. Например `mlx-community/whisper-large-v3` для лучшего качества (медленнее).

### Как изменить формат анализа

В SKILL.md, Phase 4d: изменить промпт для Task subagent. Секции TLDR/Идеи/Инсайты/TODO можно добавлять/удалять.
