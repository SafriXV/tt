#!/usr/bin/env bash
# Build the Lynx bundle with Nix, embed it in the Android host, and assemble
# a release APK. Run from anywhere: ./scripts/build-apk.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

echo "==> Building Haskell -> Lynx bundle with Nix"
nix build .#bundle --accept-flake-config

echo "==> Embedding bundle in Android assets"
mkdir -p android/app/src/main/assets
cp result/main.lynx.bundle android/app/src/main/assets/main.lynx.bundle

echo "==> Assembling signed release APK"
nix develop .#android --command bash -c 'cd android && gradle assembleRelease'

mkdir -p dist
cp android/app/build/outputs/apk/release/app-release.apk dist/timetrack.apk
echo "==> Done: dist/timetrack.apk"
