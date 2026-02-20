# claude-skill-getvideo

Скилл для [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — скачивание видео, извлечение метаданных и транскрибация через OpenAI Whisper.

**macOS** | **Linux** | **MIT License**

> [English version](README.md)

## Что делает

`/getvideo` скачивает видео с YouTube (и любой платформы, поддерживаемой yt-dlp), создаёт структурированную папку с метаданными, а при желании — транскрибирует аудио через Whisper и генерирует AI-анализ.

**Пример результата:**

```
============================================================
VIDEO DOWNLOADED SUCCESSFULLY
============================================================
Title:      How I Turned Claude Into a Design Tool
Channel:    IndyDevDan
Duration:   14:32
Folder:     ~/getvideo/20260219-youtube.com-how-i-turned-claude-into-design-tool/

Files:
  video.mp4              — 245MB
  about.md               — метаданные и описание
  transcript_source.md   — полный транскрипт (whisper turbo)
  transcript_output.md   — AI-анализ (TLDR, инсайты, TODO)
============================================================
```

## Зависимости

| Инструмент | Обязателен | Назначение | Установка |
|------------|-----------|------------|-----------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | да | AI-ассистент, запускающий скилл | `npm install -g @anthropic-ai/claude-code` |
| [Homebrew](https://brew.sh) | да (macOS) | Пакетный менеджер | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | да | Загрузка видео | `brew install yt-dlp` или `pip install yt-dlp` |
| [ffmpeg](https://ffmpeg.org) | да | Извлечение аудио | `brew install ffmpeg` или `apt install ffmpeg` |
| [Python 3.8+](https://python.org) | для транскрибации | Среда выполнения Whisper | `brew install python@3.12` или `apt install python3` |
| [whisper](https://github.com/openai/whisper) | для транскрибации | Распознавание речи | `pip3 install openai-whisper` |

## Быстрая установка

Клонируйте репозиторий и запустите установщик:

```bash
git clone https://github.com/khrupov/claude-skill-getvideo.git
cd claude-skill-getvideo
chmod +x setup.sh
./setup.sh
```

Установщик:
1. Проверит каждую зависимость и предложит установить недостающие
2. Исправит SSL-сертификаты Python на macOS (нужно для загрузки моделей Whisper)
3. Создаст симлинк `~/.claude/skills/getvideo` → репозиторий

## Ручная установка

Если предпочитаете установить вручную:

**1. Установите зависимости:**

```bash
# macOS
brew install yt-dlp ffmpeg python@3.12
pip3 install openai-whisper

# Linux (Debian/Ubuntu)
sudo apt update && sudo apt install -y ffmpeg python3 python3-pip
pip3 install yt-dlp openai-whisper
```

**2. Исправьте SSL-сертификаты (только macOS):**

При первом запуске Whisper скачивает модель. На macOS Python может не иметь SSL-сертификатов:

```bash
# Вариант А: Запустить установщик сертификатов
/Applications/Python\ 3.12/Install\ Certificates.command

# Вариант Б: Через certifi
pip3 install certifi
export SSL_CERT_FILE=$(python3 -c "import certifi; print(certifi.where())")
```

**3. Настройте скилл:**

```bash
# Создайте директорию для скиллов
mkdir -p ~/.claude/skills

# Создайте симлинк
ln -s /path/to/claude-skill-getvideo/skills/getvideo ~/.claude/skills/getvideo
```

## Использование

В Claude Code введите:

```
/getvideo https://www.youtube.com/watch?v=VIDEO_ID
```

Или просто `/getvideo` — Claude запросит URL.

### Порядок работы

1. **Подготовка** — валидация URL, получение метаданных через yt-dlp
2. **Загрузка** — скачивание видео в лучшем доступном качестве
3. **About** — создание `about.md` с метаданными, описанием, главами, тегами
4. **Транскрибация** (опционально) — Claude спросит, нужна ли:
   - Извлечение аудио через ffmpeg
   - Транскрибация через Whisper (модель turbo по умолчанию)
   - AI-анализ: TLDR, ключевые идеи, инсайты, практические TODO

## Структура выходных файлов

Все файлы сохраняются в `~/getvideo/YYYYMMDD-source-title/`:

```
~/getvideo/20260219-youtube.com-how-i-turned-claude-into-design-tool/
├── video.mp4              # Скачанное видео
├── about.md               # Метаданные, описание, главы
├── transcript_source.md   # Сырой транскрипт (если запрошен)
└── transcript_output.md   # AI-анализ (если запрошен)
```

## Модели Whisper

При первой транскрибации Whisper скачивает модель. Доступные размеры:

| Модель | Размер | Скорость | Качество |
|--------|--------|----------|----------|
| base | ~145 МБ | Быстрая | Базовая точность |
| small | ~460 МБ | Средняя | Хорошо для чёткой речи |
| medium | ~1.5 ГБ | Медленная | Высокая точность |
| turbo | ~800 МБ | Быстрая | Лучшее соотношение скорость/качество (по умолчанию) |

Скилл использует `turbo` по умолчанию.

## Решение проблем

### Ошибка SSL-сертификата при запуске Whisper

```
urllib.error.URLError: <urlopen error [SSL: CERTIFICATE_VERIFY_FAILED]>
```

Решение (macOS):
```bash
/Applications/Python\ 3.12/Install\ Certificates.command
# или
pip3 install certifi && export SSL_CERT_FILE=$(python3 -c "import certifi; print(certifi.where())")
```

### «Video unavailable» или ошибки загрузки

YouTube регулярно меняет внутренние API. Обновите yt-dlp:
```bash
yt-dlp -U
# или
brew upgrade yt-dlp
# или
pip3 install -U yt-dlp
```

### Whisper не хватает памяти

Для длинных видео (>1 часа) модели turbo/medium требуют много RAM. Используйте модель поменьше:
- Попросите Claude использовать `--model base` при транскрибации

### ffmpeg не найден

```bash
# macOS
brew install ffmpeg

# Linux
sudo apt install ffmpeg
```

## Поддерживаемые платформы

Любая платформа, поддерживаемая [yt-dlp](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md):

- YouTube
- Vimeo
- Twitter/X
- Reddit
- Twitch
- И [1800+ других сайтов](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md)

## Лицензия

MIT — см. [LICENSE](LICENSE).
