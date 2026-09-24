# LocalFlow

LocalFlow is a private Mac dictation app based on [FreeFlow](https://github.com/zachlatta/freeflow). It records speech, transcribes it with a local Whisper model, and pastes the transcript into the active app. It has no cloud AI provider, API key setup, or second language model. Thanks to the FreeFlow contributors for the original app.

## Quick start

1. Install [whisper.cpp](https://formulae.brew.sh/formula/whisper.cpp): `brew install whisper.cpp`. LocalFlow needs its `whisper-cli` executable.
2. Build with `make` and open `build/LocalFlow Dev.app`.
3. Choose a dictation mode during setup. LocalFlow downloads **only that mode's Whisper model**. Grant microphone and Accessibility permissions, then try dictation.

An internet connection is needed for the selected model download. Transcription then runs on this Mac. Choosing another mode downloads its model only when selected; previously downloaded models remain available for reuse. Downloads come from Hugging Face and are checked against the SHA-1 values published by whisper.cpp.

## Dictation modes

| Mode | Speech model | Download size | Recommended Mac |
| --- | --- | --- | --- |
| Normal | Whisper small | 466 MiB | MacBook Air M5, 16 GB unified memory |
| Heavy | Whisper large-v3-turbo | 1.5 GiB | MacBook Pro M5 Pro, 24 GB unified memory |
| Extra Heavy | Whisper large-v3 | 2.9 GiB | MacBook Pro M5 Max, 48 GB unified memory |

These Mac configurations are comfortable recommendations, not minimum requirements. Turbo favors speed; large-v3 favors accuracy and uses more memory. Model sizes are from [whisper.cpp](https://github.com/ggml-org/whisper.cpp/blob/master/models/README.md). Mac configurations are listed in Apple's [MacBook Air](https://www.apple.com/macbook-air/specs/) and [MacBook Pro](https://www.apple.com/macbook-pro/specs/) specifications.

## Privacy and storage

Audio is passed to a local `whisper-cli` process. There is no cloud AI API path for dictation. Model downloads contact Hugging Face; the app may also contact GitHub for repository and update information. Run Log can keep recent audio and transcripts on this Mac according to its settings.

Models are stored in `~/Library/Application Support/LocalFlow/Models`. If a download fails, use **Retry** in Local Models settings. The bundle identifier remains the original one so existing Mac permissions and settings are preserved.

## License

[MIT](LICENSE).
