# claude-skill-getvideo

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill for downloading videos, extracting metadata, and optionally transcribing with OpenAI Whisper.

**macOS** | **Linux** | **MIT License**

> [Версия на русском](README_RU.md)

## What It Does

`/getvideo` downloads a video from YouTube (or any platform supported by yt-dlp), creates a structured folder with metadata, and optionally transcribes the audio using Whisper with AI-powered analysis.

**Output example:**

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
  about.md               — metadata and description
  transcript_source.md   — full transcript (whisper turbo)
  transcript_output.md   — AI analysis (TLDR, insights, TODOs)
============================================================
```

## Prerequisites

| Tool | Required | Purpose | Install |
|------|----------|---------|---------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | yes | AI assistant that runs the skill | `npm install -g @anthropic-ai/claude-code` |
| [Homebrew](https://brew.sh) | yes (macOS) | Package manager | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | yes | Video downloader | `brew install yt-dlp` or `pip install yt-dlp` |
| [ffmpeg](https://ffmpeg.org) | yes | Audio extraction | `brew install ffmpeg` or `apt install ffmpeg` |
| [Python 3.8+](https://python.org) | for transcription | Whisper runtime | `brew install python@3.12` or `apt install python3` |
| [whisper](https://github.com/openai/whisper) | for transcription | Speech-to-text | `pip3 install openai-whisper` |

## Quick Setup

Clone the repo and run the installer:

```bash
git clone https://github.com/khrupov/claude-skill-getvideo.git
cd claude-skill-getvideo
chmod +x setup.sh
./setup.sh
```

The installer will:
1. Check each dependency and offer to install missing ones
2. Fix Python SSL certificates on macOS (required for Whisper model downloads)
3. Create a symlink from `~/.claude/skills/getvideo` to the repo

## Manual Setup

If you prefer to install manually:

**1. Install dependencies:**

```bash
# macOS
brew install yt-dlp ffmpeg python@3.12
pip3 install openai-whisper

# Linux (Debian/Ubuntu)
sudo apt update && sudo apt install -y ffmpeg python3 python3-pip
pip3 install yt-dlp openai-whisper
```

**2. Fix SSL certificates (macOS only):**

Whisper needs to download models on first use. On macOS, Python may lack SSL certificates:

```bash
# Option A: Run the certificate installer
/Applications/Python\ 3.12/Install\ Certificates.command

# Option B: Use certifi
pip3 install certifi
export SSL_CERT_FILE=$(python3 -c "import certifi; print(certifi.where())")
```

**3. Set up the skill:**

```bash
# Create the skills directory
mkdir -p ~/.claude/skills

# Create symlink
ln -s /path/to/claude-skill-getvideo/skills/getvideo ~/.claude/skills/getvideo
```

## Usage

In Claude Code, type:

```
/getvideo https://www.youtube.com/watch?v=VIDEO_ID
```

Or just type `/getvideo` and Claude will ask for the URL.

### Workflow

1. **Setup** — validates the URL, fetches video metadata via yt-dlp
2. **Download** — downloads the video in best available quality
3. **About** — creates `about.md` with metadata, description, chapters, tags
4. **Transcribe** (optional) — Claude asks if you want transcription:
   - Extracts audio with ffmpeg
   - Transcribes with Whisper (turbo model by default)
   - Generates AI analysis: TLDR, key ideas, insights, actionable TODOs

## Output Structure

All files are saved to `~/getvideo/YYYYMMDD-source-title/`:

```
~/getvideo/20260219-youtube.com-how-i-turned-claude-into-design-tool/
├── video.mp4              # Downloaded video
├── about.md               # Metadata, description, chapters
├── transcript_source.md   # Raw transcript (if transcribed)
└── transcript_output.md   # AI analysis (if transcribed)
```

## Whisper Models

On first transcription, Whisper downloads a model. Available sizes:

| Model | Size | Speed | Quality |
|-------|------|-------|---------|
| base | ~145 MB | Fast | Basic accuracy |
| small | ~460 MB | Moderate | Good for clear speech |
| medium | ~1.5 GB | Slow | High accuracy |
| turbo | ~800 MB | Fast | Best speed/quality ratio (default) |

The skill uses `turbo` by default.

## Troubleshooting

### SSL certificate error when running Whisper

```
urllib.error.URLError: <urlopen error [SSL: CERTIFICATE_VERIFY_FAILED]>
```

Fix (macOS):
```bash
/Applications/Python\ 3.12/Install\ Certificates.command
# or
pip3 install certifi && export SSL_CERT_FILE=$(python3 -c "import certifi; print(certifi.where())")
```

### "Video unavailable" or download errors

YouTube frequently changes its internals. Update yt-dlp:
```bash
yt-dlp -U
# or
brew upgrade yt-dlp
# or
pip3 install -U yt-dlp
```

### Whisper runs out of memory

For long videos (>1 hour), the turbo/medium models may require significant RAM. Use a smaller model:
- Ask Claude to use `--model base` during transcription

### ffmpeg not found

```bash
# macOS
brew install ffmpeg

# Linux
sudo apt install ffmpeg
```

## Supported Platforms

Any platform supported by [yt-dlp](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md), including:

- YouTube
- Vimeo
- Twitter/X
- Reddit
- Twitch
- And [1800+ other sites](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md)

## License

MIT — see [LICENSE](LICENSE).
