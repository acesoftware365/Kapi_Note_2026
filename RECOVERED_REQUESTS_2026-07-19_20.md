# Kapi Note — Solicitudes recuperadas del 19 y 20 de julio de 2026

Este registro fue reconstruido sin abrir el chat que provoca el cierre de Codex. Las fuentes usadas fueron `lib/memoria_para_codex.md`, el código preservado en Git, las pruebas automatizadas y la versión actual `5.0.108+123`.

## Solicitudes recuperadas y comprobadas

1. **Cuenta Kapi protege monedas y ranking — 5.0.98+113**
   - La cuenta debe comunicar que protege Kapi Coins y ranking.
   - Al recuperar o sincronizar una cuenta se conserva el código estable, el `publicId` y el documento de ranking.
   - Estado: **implementado**. Los mensajes de registro y recuperación mencionan explícitamente ambos elementos y el servicio de cuenta sincroniza la identidad.

2. **Pantalla Kapi Note Pro con el tema visual de Kapi — 5.0.100+115**
   - Tema oscuro, rojo y dorado.
   - Conservar compras mensual/anual, restauración, opciones legales, continuar gratis y gestión de suscripción.
   - Sustituir mensajes técnicos de productos no disponibles por un aviso entendible.
   - Estado: **implementado** en `premium_screen.dart`.

3. **Paneles de fichas en Kapi Shop — 5.0.101+116**
   - Nueva categoría Paneles / Trays.
   - Opciones: clásico, medianoche, caoba, caribe y real.
   - Cambiar solamente el panel inferior de la mano y conservar el contraste de las fichas.
   - Aplicar a Block CPU, Block Online y Teams 2 vs 2.
   - Estado: **implementado y cubierto por pruebas**. Los cinco paneles están en el servicio cosmético y el panel adaptable está conectado a los tres juegos; Teams usa la misma pantalla para CPU y online.

4. **Personalización durante una partida — 5.0.102+117**
   - Quitar `Personalize game` de Game Settings.
   - Añadir un botón de paleta junto a Settings.
   - Abrir la misma Kapi Shop sin abandonar la partida.
   - Disponible en Block y Teams, CPU y online.
   - Estado: **implementado**. Los botones existen en Block CPU, Block Online y la pantalla compartida por Teams CPU/online.

5. **Nuevo mensaje principal de Home — 5.0.103+118**
   - No promocionar solamente personalización.
   - Comunicar juego online, juego contra CPU, Notes y cuatro juegos de dominó en un mismo lugar.
   - Estado: **implementado** en `home_screen.dart`.

6. **Marcador Notes con tema Kapi — 5.0.104+119**
   - Conservar nombres, sumar/restar, bono, totales, Reset y Settings.
   - Usar fondo navy, barra vino, paneles oscuros, Team A azul, Team B rojo y totales dorados.
   - Estado: **implementado** en `game_screen.dart` y comprobado visualmente en el simulador.

7. **Confirmación antes de reiniciar Notes — 5.0.105+120**
   - Reset debe pedir confirmación.
   - Cancel conserva la partida y Reset elimina los puntos.
   - El reinicio automático al terminar una partida no cambia.
   - Estado: **implementado y comprobado visualmente** en el simulador iPhone 16e.

8. **Home sin rótulo duplicado — 5.0.106+121**
   - Eliminar `Online · vs CPU · Notes · 4 games` porque repetía el mensaje principal.
   - Conservar descripción, botones y navegación.
   - Estado: **implementado**. El rótulo ya no aparece y las acciones principales permanecen.

9. **Selector de modos con estilo Kapi — 5.0.107+122**
   - Tarjetas compactas.
   - Priorizar Block y Teams 2 vs 2.
   - Mantener All Fives y Draw / Pool deshabilitados con gris y candado.
   - Sustituir flechas laterales por un check de selección.
   - No cambiar la navegación ni la lógica.
   - Estado: **implementado** en `start_game_screen.dart` y comprobado visualmente.

10. **Actualización visual del Block Lobby — 5.0.108+123**
    - Renovar solamente la presentación: fondo rojo/azul oscuro, estado de conexión, VS y botones verde/gris.
    - Conservar Find a player, Invite a friend y Play against CPU.
    - Estado: **implementado** en `simple_lobby_screen.dart` y comprobado visualmente.

11. **Eliminar el selector duplicado de Teams 2 vs 2 — recuperado por capturas**
    - No mostrar `Choose play mode` con `Play vs CPU` y `Online` antes del lobby.
    - Abrir directamente el lobby de Teams porque esa pantalla ya contiene ambas decisiones.
    - Conservar las opciones CPU y online dentro del lobby.
    - Estado: **recuperado e implementado** en `5.0.109+124`.

## Verificación disponible

- La versión actual es `5.0.108+123`.
- Las 67 pruebas automatizadas aprobaron antes del respaldo.
- La app abrió en iPhone 16e y se recorrieron Home, Notes, confirmación de Reset, Settings, Game Mode, Simple Lobby y Block CPU.
- `flutter analyze` tiene una advertencia no fatal: `_buildSecondaryButton` no está utilizado en Home.

## Huecos que no pueden reconstruirse literalmente

- No existe una entrada separada para `5.0.99+114`; el historial de versiones salta de `5.0.98+113` a `5.0.100+115`.
- Este archivo recupera la intención y el resultado registrados, no la redacción literal del chat.
- Una solicitud que no haya producido código, prueba o anotación podría no aparecer aquí.

## Regla de continuidad

Antes de repetir trabajo, comparar cualquier solicitud recordada por el usuario con esta lista y con el código actual. No eliminar ni reemplazar funciones aprobadas durante la recuperación.
