# Guantes de Barrio (nombre provisorio)

RPG de carrera de boxeo 2D para Android, hecho en **Godot 4.7.2** con **GDScript**. Las peleas las jugás vos.
Hoy está el **prototipo de combate**:
- un Modo Arcade de 6 rivales con puntaje y récords;
- una práctica con debug;
- IA con tres estilos;
- controles táctiles.

- **Plan aprobado (congelado):** [docs/PLAN_FINAL_V2.1.md](docs/PLAN_FINAL_V2.1.md)
- **Reglas para trabajar con IA, estado actual y decisiones:** [CLAUDE.md](CLAUDE.md). **Leerlo antes de tocar código.**
- **Traspaso detallado (cómo seguir):** [docs/HANDOFF.md](docs/HANDOFF.md)
- **Convenciones:** [docs/CONVENCIONES.md](docs/CONVENCIONES.md)
- **Exportar a Android:** [docs/ANDROID.md](docs/ANDROID.md)

## Jugar
- **Windows:** doble clic en `jugar.bat` (abre el juego sin el editor). Si Godot no está en `Descargas`, editá la ruta dentro del archivo.
- **Editor:** abrí la carpeta con Godot 4.7.2 y apretá F5.

| Acción | Teclado | Táctil |
|---|---|---|
| Moverse | ← → / A D | ◀ ▶ |
| Jab | J | JAB |
| Fuerte (mantener = cargar) | K | FUERTE |
| Golpe al cuerpo | mantener S / ↓ + golpe | deslizar hacia abajo sobre JAB o FUERTE |
| Guardia | L (mantener) | GUARDIA |
| Esquive | Espacio | ESQUIVE |
| Pausa | Esc / P | ⏸ |

## Pruebas automáticas
```bash
bash tests/run_all.sh          # todas tienen que dar "RESULTADO: OK"
```
- Por defecto usa Godot en `~/Downloads/...`. Para otra ruta, usá `GODOT=/ruta/a/godot bash tests/run_all.sh`.
- En Linux o en la nube, `bash tools/install_godot_linux.sh` descarga Godot 4.7.2 e imprime la ruta.
- **Balance:** `godot --headless --path . -s res://tests/balance_report.gd` corre 20 peleas de IA contra IA.
