# getvideo — Download & Analyze Video

Claude Code skill для скачивания видео с YouTube и других платформ, транскрибации через mlx-whisper и AI-анализа содержания.

## Возможности

- Скачивание видео в лучшем качестве (yt-dlp)
- Структурированная папка с метаданными (`about.md`)
- Транскрибация на Apple Silicon (mlx-whisper turbo)
- AI-анализ: TLDR, основные идеи, инсайты, TODO
- **Resume mode** — продолжение обработки прерванного процесса

## Требования

- macOS с Apple Silicon (для mlx-whisper)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) — `brew install yt-dlp`
- [ffmpeg](https://ffmpeg.org/) — `brew install ffmpeg`
- [mlx-whisper](https://github.com/ml-explore/mlx-examples) — `pip3 install mlx-whisper`

## Установка

Skill уже установлен: `~/.claude/skills/getvideo/SKILL.md`

## Использование

### Скачать новое видео

```
/getvideo https://www.youtube.com/watch?v=XXXXX
```

### Продолжить обработку

```
/getvideo resume ~/getvideo/20260115-youtube.com-video-title
```

### Основной процесс

1. Получение метаданных (yt-dlp --dump-json)
2. Скачивание видео → `video.mp4`
3. Запись метаданных → `about.md`
4. (опционально) Извлечение аудио → `audio.m4a`
5. (опционально) Транскрибация → `transcript_source.md`
6. (опционально) AI-анализ → `transcript_output.md`

## Структура данных

```
~/getvideo/
├── 20260115-youtube.com-video-title/
│   ├── video.mp4              # видео
│   ├── audio.m4a              # аудио (опционально)
│   ├── audio.txt              # сырой whisper output
│   ├── about.md               # метаданные видео
│   ├── transcript_source.md   # транскрипт с заголовком
│   └── transcript_output.md   # AI-анализ
└── ...
```

### Именование папок

`YYYYMMDD-source-sanitized_title`

- `YYYYMMDD` — дата загрузки на платформу
- `source` — домен (youtube.com, vimeo.com)
- `sanitized_title` — транслитерация, lowercase, max 60 символов

## Статистика коллекции

- 9 видео в коллекции
- 2.2 GiB общий размер
- 7 из 9 полностью обработаны (с транскриптом и анализом)
