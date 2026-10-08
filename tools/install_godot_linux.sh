#!/usr/bin/env bash
# Descarga Godot 4.7.2 para Linux (para correr las pruebas en una sesión en la nube o en Linux).
# Uso:  bash tools/install_godot_linux.sh   → imprime la ruta; después:  GODOT=<ruta> bash tests/run_all.sh
set -e
VERSION="4.7.2-stable"
DEST="${HOME}/godot-${VERSION}"
BIN="${DEST}/Godot_v${VERSION}_linux.x86_64"
if [ ! -x "$BIN" ]; then
	mkdir -p "$DEST"
	curl -L -o "$DEST/godot.zip" "https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_linux.x86_64.zip"
	unzip -o "$DEST/godot.zip" -d "$DEST" >/dev/null
	chmod +x "$BIN"
fi
echo "$BIN"
