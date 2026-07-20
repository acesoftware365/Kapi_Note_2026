# Kapi Note — Registro de respaldo y recuperación

Fecha: 20 de julio de 2026

Versión preservada: `5.0.108+123`

Repositorio: `acesoftware365/Kapi_Note_2026`

Rama: `main`

## Qué ocurrió

Durante la recuperación del contexto de una tarea anterior, Codex intentó leer de una sola vez un historial de conversación muy extenso. La aplicación Codex se cerró inesperadamente durante esa lectura.

El cierre afectó la interfaz de Codex, no el proyecto Flutter. Los archivos locales de Kapi Note permanecieron en `/Users/juanpolanco/StudioProjects/dominoes_note2025` y fueron revisados después del incidente.

## Estado recuperado

- El proyecto abre en el simulador iPhone 16e.
- Se revisaron Home, Notes, la confirmación de Reset, Settings, Game Mode, Simple Lobby y Block contra CPU.
- La versión mostrada por la app es `5.0.108+123`.
- La suite automatizada completó 67 pruebas correctamente.
- El análisis estático reportó una sola advertencia no fatal: `_buildSecondaryButton` no está siendo utilizado en `lib/screens/home_screen.dart`.
- AdMob devolvió `No ad to show` durante la prueba del simulador. Esto indica falta de inventario de anuncio y no un cierre de la app.

## Cambios preservados de la tanda más reciente

- Confirmación antes de reiniciar los puntos de Notes.
- Acceso a Kapi Shop y personalización durante partidas.
- Mensaje principal actualizado en Home.
- Cambios en Block CPU, Block Online y Teams 2 vs 2.
- Audio, configuración de juego, perfiles, cuenta y recuperación.
- Kapi Shop, artículos cosméticos y recursos asociados.
- Simple Lobby, amigos, matchmaking y transición de rival encontrado.
- Pruebas automatizadas y validadores de reglas y layout.

## Contenido del respaldo

El respaldo Git incluye el código fuente, pruebas, recursos necesarios, configuraciones de plataforma y documentación. APKs históricos, cachés de compilación, capturas y archivos temporales de validación se conservan localmente, pero se excluyen de Git porque no son necesarios para reconstruir la aplicación.

## Recuperación futura

Si el directorio local se daña, clonar el repositorio y ejecutar `flutter pub get` restaura el proyecto respaldado. Antes de publicar una versión de producción todavía se deben repetir las pruebas visuales y online exigidas en `lib/memoria_para_codex.md`.
