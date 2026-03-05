---
name: getvideo
description: "Use when downloading video from YouTube or other platforms, creating structured folder with metadata, optionally transcribing with mlx-whisper and analyzing content"
---

# getvideo — Download & Analyze Video

## Overview

Download video via yt-dlp, create structured folder with metadata (`about.md`), optionally transcribe with mlx-whisper turbo and produce AI analysis (TLDR, insights, TODOs).

Supports **resume mode** — continue processing from where it stopped (e.g. transcribe a previously downloaded video).

**Requires:** yt-dlp, ffmpeg, mlx-whisper (for transcription on Apple Silicon)

## Invocation

```
/getvideo [URL]                    # full pipeline from scratch
/getvideo resume [folder_path]     # resume from existing folder
```

If URL not provided as argument, ask via AskUserQuestion.

## Implementation Protocol

```dot
digraph getvideo {
  rankdir=TB;
  node [shape=box];

  input [label="Argument type?" shape=diamond];
  resume [label="RESUME:\nDetect state from folder"];
  ask [label="AskUserQuestion:\nVideo URL"];
  validate [label="Validate URL\nGet metadata via yt-dlp --dump-json"];
  mkdir [label="Create folder:\n~/getvideo/YYYYMMDD-source-title/"];
  download [label="Download video\nyt-dlp → video.mp4"];
  about [label="Write about.md\n(metadata, description, chapters)"];
  summary [label="Show summary to user"];
  ask_transcribe [label="AskUserQuestion:\nTranscribe?" shape=diamond];
  extract [label="ffmpeg: extract audio.m4a"];
  whisper [label="mlx_whisper turbo → transcript"];
  save_transcript [label="Write transcript_source.md"];
  analyze [label="Task subagent:\nAI analysis → transcript_output.md"];
  ask_delete [label="AskUserQuestion:\nDelete audio?" shape=diamond];
  delete_audio [label="rm audio.m4a"];
  final [label="Show final report"];

  input -> resume [label="folder path or 'resume'"];
  input -> ask [label="no argument"];
  input -> validate [label="URL"];
  ask -> validate;
  resume -> ask_transcribe [label="has video+about,\nno transcript"];
  resume -> whisper [label="has audio.m4a,\nno transcript"];
  resume -> save_transcript [label="has audio.txt,\nno transcript_source.md"];
  resume -> analyze [label="has transcript_source.md,\nno transcript_output.md"];
  resume -> final [label="everything done"];
  validate -> mkdir -> download -> about -> summary -> ask_transcribe;
  ask_transcribe -> extract [label="yes"];
  ask_transcribe -> final [label="no"];
  extract -> whisper -> save_transcript -> analyze -> ask_delete;
  ask_delete -> delete_audio [label="yes"];
  ask_delete -> final [label="no"];
  delete_audio -> final;
}
```

### Phase 0: RESUME DETECTION

Triggered when argument is a folder path (contains `/` or `~/getvideo/`) or starts with "resume".

1. Resolve folder path (expand `~`, accept both full path and folder name under `~/getvideo/`)
2. Verify folder exists, HALT if not
3. Read `about.md` to extract metadata:
   - **Title** — first `# heading` line
   - **Source URL** — value from `| Source |` row
   - **Channel** — value from `| Channel |` row
   - **Duration** — value from `| Duration |` row
4. List existing files and determine state:

   | Has file | Missing file | Resume from |
   |----------|-------------|-------------|
   | `transcript_output.md` | — | Already complete. Show final report |
   | `transcript_source.md` | `transcript_output.md` | Phase 4d: AI analysis |
   | `audio.txt` | `transcript_source.md` | Phase 4c: Save transcript |
   | `audio.m4a` | `audio.txt` | Phase 4b: Whisper transcription |
   | `video.mp4` + `about.md` | `audio.m4a` | Phase 4: Ask about transcription |
   | `video.mp4` | `about.md` | Phase 3: Write about.md (needs URL from yt-dlp or user) |

5. Show user: folder path, detected title, current state, what will happen next
6. Jump to the appropriate phase

### Phase 1: SETUP

1. If no URL argument — ask via AskUserQuestion (header: "Video URL")
2. Validate URL contains a video platform domain
3. Create `~/getvideo/` if it doesn't exist
4. Get metadata:
   ```bash
   yt-dlp --dump-json "<URL>" 2>/dev/null
   ```
   Extract: `title`, `upload_date`, `channel`, `duration_string`, `view_count`, `like_count`, `description`, `chapters`, `webpage_url_domain`, `tags`
5. Build folder name: `YYYYMMDD-source-sanitized_title`
   - source = domain without www (youtube.com, vimeo.com, etc.)
   - title = transliterate, remove special chars, spaces→hyphens, lowercase, max 60 chars
   - Example: `20260219-youtube.com-how-i-turned-claude-into-design-tool`
6. Create folder `~/getvideo/<folder>/`
7. If folder already exists — AskUserQuestion: overwrite or add suffix

### Phase 2: DOWNLOAD

1. Download video:
   ```bash
   yt-dlp -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" \
     -o "$HOME/getvideo/<folder>/video.mp4" "<URL>"
   ```
2. Show download progress to user
3. Confirm downloaded file size: `ls -lh ~/getvideo/<folder>/video.mp4`

### Phase 3: ABOUT

1. Write `about.md` using Write tool:

   ```markdown
   # <Video Title>

   | Field    | Value             |
   |----------|-------------------|
   | Source   | <URL>             |
   | Channel  | <channel>         |
   | Date     | <YYYY-MM-DD>      |
   | Duration | <duration>        |
   | Views    | <views>           |
   | Likes    | <likes>           |

   ## Description

   <video description>

   ## Chapters

   - 00:00 — Intro
   - 01:30 — ...
   (if chapters available)

   ## Tags

   <comma-separated tags>
   ```

2. Show user summary: title, channel, duration, folder path

### Phase 4: TRANSCRIBE (optional)

1. Ask user via AskUserQuestion:
   - question: "Нужна транскрибация видео?"
   - header: "Transcribe"
   - options:
     - "Да" — "Извлечь аудио → mlx-whisper turbo → анализ (займёт время)"
     - "Нет" — "Только видео и about.md"

2. If "Да":

   **a) Extract audio:**
   ```bash
   ffmpeg -i "$HOME/getvideo/<folder>/video.mp4" -vn -acodec copy \
     "$HOME/getvideo/<folder>/audio.m4a"
   ```

   **b) Transcribe with mlx-whisper:**
   ```bash
   mlx_whisper "$HOME/getvideo/<folder>/audio.m4a" \
     --model mlx-community/whisper-turbo \
     --output-dir "$HOME/getvideo/<folder>/" \
     --output-format txt
   ```
   Use timeout: 600000ms for long videos.
   Note: mlx_whisper auto-detects language. No `--language` flag needed.

   **c) Save transcript** — read mlx_whisper output `.txt`, write as `transcript_source.md`:
   ```markdown
   # Transcript: <Video Title>

   **Source:** <URL>
   **Model:** mlx-whisper turbo
   **Language:** <detected language>

   ---

   <full transcript text>
   ```

   **d) AI analysis** — launch Task (subagent_type: general-purpose) with prompt:
   ```
   Проанализируй транскрипт видео "<title>" (канал: <channel>).

   Напиши анализ на РУССКОМ ЯЗЫКЕ в следующем формате:

   ## TLDR
   2-3 предложения: о чём видео и для кого.

   ## Основные идеи
   Пронумерованный список (5-10 пунктов) — ключевые мысли из видео.

   ## Инсайты
   Что нового/неочевидного можно вынести. Что автор подчёркивает.

   ## Что стоит попробовать (TODO)
   Конкретные actionable items: что можно применить на практике,
   со ссылками на инструменты/технологии из видео и кратким "зачем".

   Транскрипт:
   <transcript text>
   ```

   **e) Write result** to `transcript_output.md` using Write tool.

   **f) Ask about audio cleanup** via AskUserQuestion:
   - question: "Удалить аудио-файл после транскрибации?"
   - options: "Да (экономия места)" / "Нет (оставить)"

### Final Output

```
============================================================
VIDEO DOWNLOADED SUCCESSFULLY
============================================================
Title:      <title>
Channel:    <channel>
Duration:   <duration>
Folder:     ~/getvideo/<folder>/

Files:
  video.mp4              — <size>
  about.md               — описание и метаданные
  transcript_source.md   — транскрипт (если запрошен)
  transcript_output.md   — анализ (если запрошен)
============================================================
```

## Error Handling

| Error | Action |
|-------|--------|
| URL not recognized by yt-dlp | HALT, show error, suggest checking URL |
| Video unavailable/private | HALT, show reason from yt-dlp |
| ffmpeg not installed | HALT: `brew install ffmpeg` |
| mlx_whisper not installed | HALT: `pip3 install mlx-whisper` |
| mlx_whisper timeout (>10 min) | Warn user, suggest smaller model |
| Folder already exists | Ask: overwrite or add suffix |
| Resume: folder not found | HALT, show path, suggest ls ~/getvideo/ |
| Resume: no about.md | Ask user for video URL to fetch metadata |
