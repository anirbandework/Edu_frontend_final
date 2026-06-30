#!/usr/bin/env bash
# Vercel build: install the Flutter SDK (Vercel images don't ship it), then build web.
# Set API_BASE_URL in the Vercel project's Environment Variables to your Railway backend
# URL, e.g. https://eduassist-backend.up.railway.app  (NO trailing slash).
set -euo pipefail

FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "Installing Flutter ($FLUTTER_CHANNEL)…"
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_CHANNEL" --depth 1 "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --version
flutter config --enable-web
flutter pub get

if [ -z "${API_BASE_URL:-}" ]; then
  echo "ERROR: API_BASE_URL env var is not set (point it at the Railway backend)." >&2
  exit 1
fi

echo "Building web against API_BASE_URL=$API_BASE_URL"
flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL"
