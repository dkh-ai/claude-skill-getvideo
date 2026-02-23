# ADR-001: Использовать mlx-whisper вместо openai-whisper
## Статус: accepted
## Контекст
openai-whisper падает с SSL-ошибкой на macOS Python 3.12 при попытке скачать модели. Ошибка воспроизводится стабильно. Пользователь уже имеет установленный mlx-whisper с закэшированной моделью turbo.
## Решение
Заменить все вызовы `whisper` на `mlx_whisper` в SKILL.md. Использовать модель `mlx-community/whisper-turbo`. Обновить документацию.
## Альтернативы
1. **Починить SSL** (Install Certificates.command / certifi / brew python) — хрупкое решение, ломается при обновлениях Python
2. **Оставить openai-whisper с fallback на mlx-whisper** — усложняет SKILL.md, два пути кода
3. **Использовать faster-whisper** — тоже установлен, но не использует Apple Silicon GPU
## Последствия
- Скилл работает только на Apple Silicon (M1+) — это ОК, целевая платформа пользователя
- setup.sh нужно обновить (пока устанавливает openai-whisper)
- Модели кэшируются в ~/.cache/huggingface/hub/
## Дата: 2026-02-23
