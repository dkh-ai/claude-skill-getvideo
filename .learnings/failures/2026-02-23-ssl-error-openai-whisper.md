# Failure: SSL error при загрузке модели openai-whisper на macOS
## Дата: 2026-02-23
## Что произошло
При вызове `whisper --model turbo` Python 3.12 на macOS падает с `ssl.SSLCertVerificationError` — не может скачать модель turbo с серверов OpenAI.
## Причина
Python 3.12, установленный через python.org installer на macOS, не имеет корректных SSL-сертификатов. `Install Certificates.command` и certifi не всегда решают проблему.
## Как починил
Заменил openai-whisper на mlx-whisper (`mlx_whisper`), который использует HuggingFace Hub для загрузки моделей и не зависит от urllib SSL.
## Как предотвратить
- Использовать mlx-whisper на Apple Silicon вместо openai-whisper
- Если нужен openai-whisper: установить Python через brew (`brew install python`) вместо python.org
## Связанные файлы
- skills/getvideo/SKILL.md (Phase 4: Transcribe)
- setup.sh (install_whisper function)
