#!/usr/bin/env bash
# ============================================================================
# BLOPS Pocket - Script de compilación local para macOS (ARM64 iOS)
# Genera el ejecutable nativo del motor Treyarch y empaqueta el .ipa sin firma.
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== [1/5] Ejecutando tests unitarios de zonas y assets ==="
cd "${ROOT_DIR}"
node --test tools/zonescan.test.mjs tools/zoneassets.test.mjs tools/zrawfile.test.mjs tools/zsizeof.test.mjs tools/zassetsize.test.mjs tools/zxmodel.test.mjs tools/zgfxworld.test.mjs

echo "=== [2/5] Configurando y compilando Motor C++ (CMake iOS ARM64) ==="
cmake -B "${ROOT_DIR}/engine_build" -S "${ROOT_DIR}/engine_source" \
  -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0

xcodebuild \
  -project "${ROOT_DIR}/engine_build/BO1Zombies.xcodeproj" \
  -scheme BO1Zombies \
  -sdk iphoneos \
  -configuration Release \
  -derivedDataPath "${ROOT_DIR}/engine_build/build" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

echo "=== [3/5] Generando proyecto Xcode para el Launcher ==="
if ! command -v xcodegen &> /dev/null; then
  echo "Instalando xcodegen vía Homebrew..."
  brew install xcodegen
fi

cd "${ROOT_DIR}/launcher"
xcodegen generate

echo "=== [4/5] Compilando BLOPSPocket App sin firma ==="
xcodebuild \
  -project "${ROOT_DIR}/launcher/BLOPSPocket.xcodeproj" \
  -scheme BLOPSPocket \
  -sdk iphoneos \
  -configuration Release \
  -derivedDataPath "${ROOT_DIR}/launcher/build" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

echo "=== [5/5] Empaquetando archivo .ipa ==="
OUTPUT_DIR="${ROOT_DIR}/launcher/build/Build/Products/Release-iphoneos"
cd "${OUTPUT_DIR}"
rm -rf Payload BLOPSPocket.ipa
mkdir -p Payload
cp -R BLOPSPocket.app Payload/
zip -r BLOPSPocket.ipa Payload

echo "============================================================================"
echo "✅ IPA generada con éxito:"
echo "${OUTPUT_DIR}/BLOPSPocket.ipa"
echo "Listo para instalar con TrollStore, AltStore o SideStore."
echo "============================================================================"
