#!/usr/bin/env bash
set -euo pipefail

# Build a self-contained universal whisper-cli from the reviewed upstream tag.
# Verify the commit so a moved tag cannot silently change a release build.
readonly whisper_tag=v1.9.4
readonly whisper_commit=927cfce34f31707e17f2bff35c349632fb9e2c3a
readonly output=${1:?usage: build-whisper-cli.sh OUTPUT_PATH}
readonly build_root=$(mktemp -d "${TMPDIR:-/tmp}/privateflow-whisper.XXXXXX")
trap 'rm -rf "$build_root"' EXIT

if [[ -n "${WHISPER_CPP_SOURCE_DIR:-}" ]]; then
  source_dir=$WHISPER_CPP_SOURCE_DIR
else
  source_dir=$build_root/source
  git clone --depth 1 --branch "$whisper_tag" \
    https://github.com/ggml-org/whisper.cpp.git "$source_dir"
fi

if [[ $(git -C "$source_dir" rev-parse HEAD) != "$whisper_commit" ]]; then
  echo "whisper.cpp source does not match the pinned $whisper_tag commit." >&2
  exit 1
fi

for arch in arm64 x86_64; do
  "${CMAKE_BIN:-cmake}" -S "$source_dir" -B "$build_root/$arch" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="$arch" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
    -DBUILD_SHARED_LIBS=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_EXAMPLES=ON \
    -DGGML_METAL=ON \
    -DGGML_METAL_EMBED_LIBRARY=ON \
    -DGGML_NATIVE=OFF
  "${CMAKE_BIN:-cmake}" --build "$build_root/$arch" \
    --target whisper-cli --config Release -j 4
done

mkdir -p "$(dirname "$output")"
lipo -create -output "$output" \
  "$build_root/arm64/bin/whisper-cli" \
  "$build_root/x86_64/bin/whisper-cli"
lipo "$output" -verify_arch arm64 x86_64
chmod 755 "$output"
