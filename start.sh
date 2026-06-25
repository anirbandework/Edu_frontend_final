#!/usr/bin/env bash
#
# EduAssist FRONTEND launcher
# ---------------------------------------------------------------------------
# One command to run the Flutter app against the local backend:
#   1. puts Flutter (Homebrew) on PATH
#   2. fetches packages (flutter pub get)
#   3. runs the app
#
# Usage:
#   ./start.sh            # run on Chrome (web)  [default]
#   ./start.sh macos      # run as a macOS desktop app
#   ./start.sh <deviceId> # any id from `flutter devices`
#
# NOTE: start the backend first (edu_backend/start.sh). The app talks to
#       http://localhost:8000 (configured in lib/core/constants/app_constants.dart).
# ---------------------------------------------------------------------------

FRONTEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$FRONTEND_DIR" || exit 1

# Make sure Flutter is reachable. Prefer the local SDK already on this machine
# (Flutter 3.35.4 lives at the path below); fall back to Homebrew if present.
FLUTTER_SDK="/Users/anirbande/Desktop/ddddd/flutter/flutter"
export PATH="/opt/homebrew/bin:$PATH"
[ -x "$FLUTTER_SDK/bin/flutter" ] && export PATH="$FLUTTER_SDK/bin:$PATH"

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: 'flutter' not found."
  echo "       Looked for SDK at: $FLUTTER_SDK/bin  (and Homebrew)."
  echo "       Install via:  brew install --cask flutter"
  exit 1
fi

DEVICE="${1:-chrome}"   # default target: chrome (web)

echo "==> $(flutter --version | head -1)"
echo "==> Fetching packages (flutter pub get)..."
flutter pub get

echo "==> Backend should be running at http://localhost:8000"
echo "==> Launching app on device: $DEVICE"
exec flutter run -d "$DEVICE"
