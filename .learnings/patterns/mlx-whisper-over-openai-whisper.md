### Паттерн: mlx-whisper вместо openai-whisper на Apple Silicon
- **Что:** На macOS с Apple Silicon использовать `mlx_whisper` (пакет `mlx-whisper`) вместо `whisper` (пакет `openai-whisper`). CLI почти совместим, но: флаги через дефис, модели указываются как HF repo (`mlx-community/whisper-turbo`), авто-определение языка по умолчанию
- **Почему:** openai-whisper ломается из-за SSL на macOS Python 3.12. mlx-whisper нативно использует MLX framework (Apple Silicon GPU), быстрее и стабильнее
- **Обнаружен:** 2026-02-23
