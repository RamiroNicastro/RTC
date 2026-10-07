# Exportar a Android (Fase 0, paso 4)

Esta configuración se hace **una sola vez** en tu PC. Conviene tenerla lista antes del Hito T.

1. **Instalar el JDK 17** (por ejemplo, Eclipse Temurin 17).
2. **Instalar Android Studio** y, desde el *SDK Manager*, instalar:
   - Android SDK Platform-Tools
   - Android SDK Build-Tools
   - Android SDK Platform (la versión que pida Godot 4.7)
   - Command-line Tools
3. En Godot, ir a **Editor → Editor Settings → Export → Android** y completar:
   - `Java SDK Path`: la carpeta del JDK 17;
   - `Android SDK Path`: normalmente `C:\Users\<usuario>\AppData\Local\Android\Sdk`.
4. **Bajar las plantillas de exportación** desde **Editor → Manage Export Templates → Download and Install** (tienen que ser de la versión 4.7.2).
5. Ir a **Project → Export → Add… → Android**. La plantilla trae una *debug keystore* que alcanza para probar. Revisar que esté activado:
   - `Screen → Immersive Mode`: activado.
6. En el celular:
   - activar las **Opciones de desarrollador** y la **Depuración USB**;
   - conectarlo por USB;
   - en Godot, usar el botón de **Remote Debug / Deploy** (ícono de Android arriba a la derecha).

**Objetivo de la Fase 0:** que la sandbox abra en el celular en horizontal. Todavía no hay controles táctiles; esos llegan en el Hito T.
