#!/usr/bin/env bash
# Build web sur Vercel : le SDK Flutter n'est pas préinstallé sur son image
# de build, on télécharge donc la version pinnée (celle utilisée en local,
# voir `flutter --version`) avant de construire — voir `vercel.json`, dont
# le `buildCommand` doit rester sous 256 caractères, d'où ce script séparé.
set -euo pipefail

FLUTTER_VERSION="3.44.8"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

curl -fsSLo flutter.tar.xz "$FLUTTER_URL"
tar xf flutter.tar.xz
export PATH="$PATH:$(pwd)/flutter/bin"

# Le build Vercel tourne en root ; le SDK Flutter est un dépôt git dont le
# propriétaire (l'utilisateur ayant extrait l'archive) diffère alors de root
# aux yeux de git, qui refuse par défaut d'opérer dessus ("detected dubious
# ownership") — `flutter` lui-même invoque `git` en interne (ex : résolution
# de version), d'où l'échec sans cette exception explicite.
git config --global --add safe.directory "$(pwd)/flutter"

flutter config --no-analytics --enable-web
flutter pub get
flutter build web --release
