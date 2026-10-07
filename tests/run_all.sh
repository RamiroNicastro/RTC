#!/usr/bin/env bash
# Corre todas las pruebas automáticas del combate (Git Bash). Uso: bash tests/run_all.sh
GODOT="${GODOT:-$HOME/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import > /dev/null 2>&1
status=0
for t in tests/test_*.gd; do
	for w in 1280 1600; do
		[ "$t" != "tests/test_camera.gd" ] && [ "$w" = "1600" ] && continue
		result=$(VIEW_W=$w "$GODOT" --headless --path . -s "res://$t" 2>&1 | grep -E "RESULTADO|SCRIPT ERROR" -A3)
		echo "$t (ancho $w): $result"
		echo "$result" | grep -q "RESULTADO: OK" || status=1
	done
done
exit $status
