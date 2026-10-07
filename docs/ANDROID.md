# Exportar a Android

## Lo que ya está listo en el proyecto
- `export_presets.cfg` con un preset **"Android"**: APK de debug para arm64, modo inmersivo, horizontal, y sin las carpetas `tests/` ni `docs/`.
- En las preferencias de Godot ya figuran la *debug keystore* y la ruta del SDK (`C:\Users\C509134\AppData\Local\Android\Sdk`).

## Lo que falta instalar en esta PC (revisado el 07/10/2026)

| Qué | Estado | Cómo resolverlo |
|---|---|---|
| **JDK 17** | Solo está instalado Java 8, y no sirve | Instalar *Eclipse Temurin 17* (adoptium.net). En una terminal: `winget install EclipseAdoptium.Temurin.17.JDK` |
| **Android SDK** | La carpeta configurada no existe | Instalar **Android Studio**. Abrirlo una vez → *More Actions → SDK Manager*: instalar *Android SDK Platform-Tools*, *Build-Tools*, *Command-line Tools (latest)* y una *SDK Platform* reciente |
| **Plantillas de exportación 4.7.2** | No están | En Godot: **Editor → Manage Export Templates → Download and Install** |

## Pasos en Godot (una vez instalado lo anterior)
1. **Editor → Editor Settings → Export → Android**:
   - `Java SDK Path`: la carpeta del JDK 17 (por ejemplo, `C:\Program Files\Eclipse Adoptium\jdk-17...`);
   - `Android SDK Path`: dejar `C:\Users\C509134\AppData\Local\Android\Sdk`.
2. **Project → Export…** → elegir **Android**. Si no aparece ningún error en rojo abajo, ya está todo bien configurado.
3. En el celular:
   - **Ajustes → Acerca del teléfono** → tocar 7 veces *Número de compilación* para activar las opciones de desarrollador;
   - en **Opciones de desarrollador**, activar *Depuración USB*.
4. Conectar el celular por USB y aceptar el permiso que aparece en pantalla.
5. En Godot, arriba a la derecha, tocar el ícono de **Android** (*Remote Deploy*). El juego se instala y se abre en el celular.

**Alternativa sin cable:** desde *Project → Export → Export Project* se genera `build/boxeo-rpg-debug.apk`. Pasalo al celular e instalalo, aceptando "instalar apps de origen desconocido".

## Qué probar en el Hito T
- Mover (◀ ▶), JAB, FUERTE y GUARDIA (mantener). Mantené la guardia con un dedo y pegá con otro.
- Arriba hay botones para **cambiar el modo del rival**, ver el **debug** y **reiniciar**.
- **Preguntas que tiene que responder la prueba:**
  - ¿Los botones tienen buen tamaño y quedan cómodos para los pulgares?
  - ¿Responden rápido?
  - ¿Te tapan algo importante de la pelea?
  - ¿Te equivocás de botón seguido?
