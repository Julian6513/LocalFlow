# LocalFlow

<p align="center">
  <img src="Resources/AppIcon-Source.png" width="128" height="128" alt="LocalFlow icon">
</p>

LocalFlow is a local Mac dictation app based on [FreeFlow](https://github.com/zachlatta/freeflow). It records speech, transcribes it with a local Whisper model, and pastes the transcript into the active app. It has no cloud AI provider, API key setup, or second language model. Thanks to the FreeFlow contributors for the original app.

## Quick start

1. Install [whisper.cpp](https://formulae.brew.sh/formula/whisper.cpp): `brew install whisper.cpp`. LocalFlow needs its `whisper-cli` executable.
2. Build with `make` and open `build/LocalFlow Dev.app`.
3. Choose a dictation mode during setup. LocalFlow downloads **only that mode's Whisper model** and shows when it is ready.
4. Grant microphone and Accessibility permissions. Hold `Fn` to talk, then release it to transcribe and paste into the active app.

An internet connection is needed for the selected model download. Transcription then runs on this Mac. Choosing another mode downloads its model only when selected; previously downloaded models remain available for reuse. Downloads come from Hugging Face and are checked against the SHA-1 values published by whisper.cpp.

## Dictation modes

| Mode | Speech model | Download size | Recommended Mac |
| --- | --- | --- | --- |
| Normal | Whisper small | 466 MiB | M1 MacBook Air, 8 GB unified memory |
| Heavy | Whisper large-v3-turbo | 1.5 GiB | M1 MacBook Air, 8 GB unified memory |
| Extra Heavy | Whisper large-v3 | 2.9 GiB | M1 Pro MacBook Pro, 16 GB unified memory |

These are example Macs for comfortable use, not minimum requirements or measured latency guarantees. Normal and Heavy share the same recommendation because Turbo is optimized for speed; a reported [whisper.cpp run](https://github.com/ggml-org/whisper.cpp/discussions/2645) used large-v3-turbo on an 8 GB M1 Mac. [whisper.cpp](https://github.com/ggml-org/whisper.cpp/blob/master/README.md#memory-usage) lists about 852 MB of memory for small and 3.9 GB for large. We recommend 16 GB for Extra Heavy to leave room for macOS and other apps, not because its model needs 16 GB. The [M1 MacBook Air](https://support.apple.com/en-ie/111883) and [M1 Pro MacBook Pro](https://support.apple.com/en-bh/111902) configurations are documented by Apple. If buying a new Mac, the [base M5 MacBook Air with 16 GB](https://www.apple.com/macbook-air/specs/) is a reasonable choice for all three modes based on these memory figures; no M5 Pro or Max is needed just for dictation.

## Privacy and storage

Audio is passed to a local `whisper-cli` process. There is no cloud AI API path for dictation. Model downloads contact Hugging Face; the app may also contact GitHub for repository and update information. Run Log can keep recent audio and transcripts on this Mac according to its settings.

Models are stored in `~/Library/Application Support/LocalFlow/Models`. If a download fails, use **Retry** in Local Models settings. macOS may ask for microphone and Accessibility access again when a locally signed app is replaced.

## License

[MIT](LICENSE).
