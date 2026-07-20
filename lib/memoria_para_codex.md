# Memoria para Codex

## Teams Online inicia la búsqueda desde su tarjeta (2026-07-20)

- En el lobby de Teams 2 vs 2, tocar `Buscar partida online` inicia inmediatamente el matchmaking.
- Se eliminó el botón adicional `Find players`, porque obligaba a confirmar dos veces la misma decisión.
- La búsqueda conserva su espera de hasta 30 segundos y completa los asientos vacíos con CPU.
- Versión técnica: `5.0.110+125`.

## Teams 2 vs 2 sin selector duplicado (2026-07-20)

- Al continuar con Teams 2 vs 2 ya no se abre el panel intermedio `Choose play mode` con `Play vs CPU` y `Online`.
- El flujo abre directamente el lobby de Teams, que ya contiene las opciones para jugar con CPU o buscar jugadores online.
- No se eliminaron las opciones de juego; solamente se retiró la pregunta duplicada anterior al lobby.
- Solicitud recuperada mediante las capturas de pantalla del usuario.
- Versión técnica: `5.0.109+124`.

## Respaldo después de cierre inesperado de Codex (2026-07-20)

- Codex se cerró al intentar cargar de una sola vez el historial extenso de una tarea anterior.
- El cierre afectó la interfaz de Codex, no los archivos del proyecto Flutter; el código local permaneció intacto.
- Se creó `BACKUP_LOG_2026-07-20.md` con el incidente, el estado recuperado y las instrucciones de recuperación.
- La versión preservada en esta tanda es `5.0.108+123`.
- Antes del respaldo, 67 pruebas automatizadas aprobaron. `flutter analyze` solo indicó que `_buildSecondaryButton` no está usado en Home.
- El respaldo debe incluir código, pruebas, recursos y configuración, pero no APKs históricos, cachés, capturas ni carpetas temporales de validación.

## Confirmacion al reiniciar Notes (2026-07-20)

- El boton **Reset** de Notes ahora pide confirmacion antes de borrar los puntos de ambos equipos.
- **Cancel** conserva la partida; **Reset** borra los puntos. El reinicio automatico al terminar una partida no cambia.
- Version tecnica de esta tanda: 5.0.105+120.

## Personalizar durante una partida (2026-07-20)

- Personalize game ya no aparece dentro de Game Settings.
- Durante la partida hay un boton independiente de paleta inmediatamente a la izquierda de Settings.
- El boton abre directamente la misma Kapi Shop sin salir de la partida, para comprar, seleccionar o equipar mesas, centros de mesa, fichas, avatares y banderas.
- Disponible en Block y Teams, contra CPU y online, sin crear un selector duplicado.
- Version tecnica de esta tanda: 5.0.102+117.

## Mensaje principal de inicio (2026-07-20)

- El texto de inicio ya no promociona "Personalizar".
- Ahora comunica claramente las cuatro propuestas principales: jugar online, jugar contra CPU, usar Notes y acceder a 4 juegos de dominó desde un mismo lugar.
- Version tecnica de esta tanda: 5.0.103+118.

## Ciclo de validacion obligatorio - 2026-07-12

Antes de declarar un build listo, se deben repetir partidas completas y comprobar:

- La cadena logica y la cadena visible usan exactamente las mismas puntas abiertas.
- Una ficha con blanco (`0`) se puede jugar cuando una punta visible/logica es blanca.
- Cada ficha nueva entra solamente por una de las dos puntas, nunca por el centro.
- Los valores conectados coinciden (2 con 2, 4 con 4, blanco con blanco, etc.).
- Los dobles mantienen la orientacion transversal correcta y no provocan el giro de la cadena.
- En un tranque gana la mano con menos puntos; si empatan, gana quien hizo la ultima jugada.
- Los puntos otorgados en un tranque son la suma de los puntos de TODAS las fichas restantes de ambos jugadores.
- En la primera ronda abre el doble mas alto. En rondas posteriores, el ganador anterior elige su ficha de salida.
- Los dos clientes online muestran la misma revision, tablero, manos, turno, ronda y puntuacion.
- Un jugador dentro de una sala no puede ser emparejado con una tercera persona.
- Salir de la sala libera a ambos jugadores y el rival recibe el aviso sin quedar atrapado.
- Al terminar una partida online aparece la tarjeta de resultado, fichas restantes, confeti y opciones `Play Again` / `Return to Lobby`.
- `Play Again` solo comienza cuando ambos aceptan; si el rival no acepta, se vuelve al lobby.
- Revisar telefonos pequenos y grandes en iOS y Android sin cortes, solapes ni botones sobre las fichas.

No confiar solo en el codigo o en una captura: jugar, observar cada movimiento, corregir y repetir.

Fecha de trabajo: 2026-06-07

Este documento resume los cambios realizados hoy en el proyecto Kapi Note para que Codex pueda recuperar rapido el contexto en futuras sesiones.

## Kapi Note v2.0 / etapa juego beta

Fecha de corte: 2026-07-07

Actualizacion 2026-07-10:

- El modo que antes se veia como `Classic beta` ahora debe llamarse **Block beta**.
- Para referencia visual/reglas, Block corresponde a `Block Dominoes`: no hay pozo/draw; si el jugador no tiene jugada valida, pasa.
- Cada modo de domino debe vivir en su propio folder separado para no danar otros modos:
  - `lib/screens/block_dominoes/` para Block.
  - Draw/Pool debe mantenerse separado cuando se implemente.
  - All Fives debe mantenerse separado cuando se implemente.
- Antes de jugar cualquier modo, el jugador debe crear el profile obligatoriamente la primera vez.
- Despues de creado el profile, si el usuario quiere cambiarlo, se mantiene la regla acordada: cambio por reward ad o Pro.
- En la pantalla de elegir modo debe existir un boton pequeno/largo `How to play Block` que abra una ayuda verde estilo Block Dominoes explicando las reglas del modo.
- La pantalla de elegir modo no debe decir `Choose Game Mode`; debe decir `Game Mode` / `Modo de juego`, sin el label pequeno `Game mode`.
- Los modos visibles en esa pantalla deben ser `All Fives`, `Draw / Pool` y `Block beta`.
- El boton de ayuda debe cambiar dinamicamente segun el modo seleccionado: `How to play All Fives`, `How to play Draw / Pool` o `How to play Block`.
- `Draw / Pool` y `All Fives` se muestran como proximamente por ahora; `Block beta` es el modo funcional.
- El profile no debe usar `JP` como valor demo por defecto. Si no existe profile guardado, debe abrirse un modal obligatorio para entrar 2 iniciales, pais e icono antes de jugar.
- Version tecnica actualizada para esta tanda: `5.0.36+50`.

- El usuario decidio empezar a llamar esta nueva etapa **Version 2 del app** porque agrega el juego de domino dentro de Kapi Note.
- Para tiendas, no bajar el numero tecnico de `pubspec.yaml` a `2.0.0` si ya existe una version `5.x` subida; Apple/Google pueden rechazar versiones menores. Usar `v2.0` como nombre interno, tag de Git o nombre de etapa.
- Version tecnica actual del build: `5.0.36+50`.
- Tag recomendado de Git para esta copia: `v2.0-game-beta`.
- Esta etapa incluye:
  - pantalla `Start Game`;
  - perfil con iniciales, pais, avatar e ID/hashtag;
  - ranking visual;
  - lobby/amigos/invitaciones;
  - Classic beta contra CPU;
  - base de Online Classic con Firestore;
  - boton visible para ir y volver entre juego y apuntes/notas;
  - mano del jugador ordenada para mostrar primero fichas jugables;
  - boton `Paso` solo cuando no hay jugada valida, dentro de la barra de mensaje.
  - boton `Hide/Ocultar` removido del juego classic; la mano del jugador queda visible y la barra de mensaje queda justo arriba de las fichas.
  - juego Classic muestra ronda/meta en el centro superior de la mesa, usa meta beta de 30 puntos, termina el juego al llegar a la meta y muestra la version debajo del banner/anuncio inferior, no debajo del titulo `Classic beta`.
  - flujo de juego confirmado: pantalla principal -> Choose Game Mode -> Lobby & Friends -> game board. El boton Continue de Choose Game Mode no debe saltar directo al tablero; primero debe pasar por el lobby.
  - regla de tranque: si la ronda se bloquea y ambos jugadores tienen la misma cantidad de puntos en fichas, gana quien hizo la ultima jugada que causo el tranque.
  - regla de salida Classic: en la primera ronda de un juego nuevo sale quien tenga el doble mas alto; si no hay dobles, sale la mejor ficha disponible. Despues de que ya se jugo una ronda con la misma persona, la proxima ronda la abre quien gano la ronda anterior.
  - mano del jugador: las fichas deben mantener el alto actual, pero ser mas anchas para que se vea completa la ficha aunque se pase un poco del centro.
  - al terminar el juego completo, la tarjeta de ganador debe mostrar una animacion de confeti cayendo detras del anuncio para que se sienta como cierre de partida.

## Repositorio

- Proyecto local: `/Users/juanpolanco/Documents/Working App/dominoes_note2025`
- Repositorio GitHub: `https://github.com/acesoftware365/Kapi_Note_2026`
- Branch principal: `main`
- Ultimo commit subido hoy: `2456a42` con mensaje `Improve adaptive ads and tablet layout`

## Version de la app

El usuario indico que la ultima version subida a App Store y Google Play fue `5.0.2+3`.

Se preparo la siguiente version como:

- `version: 5.0.3+8` en `pubspec.yaml`
- Se uso `+8` porque Android tenia `versionCode = 7` hardcodeado. Para evitar rechazo en Google Play, el siguiente `versionCode` debe ser mayor que 7.
- Android ahora usa:
  - `versionCode = flutter.versionCode`
  - `versionName = flutter.versionName`
- iOS Runner quedo con:
  - `MARKETING_VERSION = 5.0.3`
  - `CURRENT_PROJECT_VERSION = 8`

## AdMob

Problema original:

- Match Rate bajo, aproximadamente 12%.
- Se sospechaba uso de banners fijos `AdSize.banner` y mala gestion de carga.

Cambios realizados:

- Se creo el widget reusable `lib/widgets/anchored_adaptive_banner_ad.dart`.
- El widget usa `google_mobile_ads`.
- Calcula el ancho de pantalla con `MediaQuery`.
- Solicita el tamano optimo usando `AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width)`.
- Solo muestra `AdWidget` despues de `onAdLoaded`.
- En `onAdFailedToLoad`, libera el anuncio, no deja espacio vacio y permite reintento futuro.
- Hace `dispose()` del `BannerAd`.

Pantallas migradas a banners adaptativos:

- `lib/screens/home_screen.dart`
- `lib/screens/settings_screen.dart`
- `lib/screens/game_screen.dart`

## Home Screen

Se ajusto `lib/screens/home_screen.dart`.

Cambios:

- Se centro el texto y contenido del Home.
- Se limito el ancho del contenido en tablet para que no se vea demasiado estirado.
- Se agrego deteccion de tablet con breakpoint `screenWidth >= 600`.
- En tablet se agrandaron:
  - Titulo
  - Descripcion
  - Boton principal
  - Botones secundarios
  - Iconos
  - Padding y separacion
- Se agregaron iconos a los botones del Home:
  - Iniciar: `Icons.play_arrow_rounded`
  - Settings: `Icons.settings_rounded`
  - Privacy: `Icons.privacy_tip_rounded`
- Se cambiaron usos de `withOpacity` en Home por `withValues(alpha: ...)`.
- `flutter analyze lib/screens/home_screen.dart` quedo sin issues.

## Game Screen

Se ajusto `lib/screens/game_screen.dart`.

Cambios:

- En tablet se agrandaron los textos de equipos y totales.
- En tablet se agrandaron los botones de:
  - Minus / remove
  - Add
  - Bonificacion
- Los botones pasaron de `FloatingActionButton.small` a `FloatingActionButton` dentro de `SizedBox` responsivo.
- Tamano aproximado:
  - Telefono: `46x46`
  - Tablet: `72x72`
  - Iconos en tablet: `38`
- Se mantiene el multiplicador existente `scoreFontSizeScale`.
- Se cambio `withOpacity(0.9)` en la tarjeta por `withValues(alpha: 0.9)`.

Notas del analyzer:

- Quedan infos viejas en `game_screen.dart`:
  - `print` en codigo de produccion.
  - Uso de `BuildContext` despues de async gap.
- No estan relacionadas con los cambios de tablet.

## Settings Screen

Se ajusto `lib/screens/settings_screen.dart`.

Cambios:

- Se agrego un boton arriba a la izquierda en el AppBar para ir a Home.
- Icono: `Icons.home_rounded`
- Navegacion:
  - `Navigator.pushReplacementNamed(context, '/home')`
- Se mantuvo el boton de Game arriba a la derecha.
- `flutter analyze lib/screens/settings_screen.dart` paso sin issues.

## About Screen

Se ajusto `lib/screens/about_screen.dart`.

Cambios:

- Se quito la version hardcodeada vieja `Version: 4.0.0+0`.
- Ahora usa `package_info_plus` para mostrar la version real:
  - `${version}+${buildNumber}`

## App Store Metadata

Descripcion EN:

Kapi Note is a simple, fast way to keep domino scores. Create two teams, add points, and track totals as you play.

Features:
- Quick score entry
- Auto-save your game
- Adjustable score size
- Clean, focused design

Perfect for casual games, family matches, and tournaments.

Descripcion ES:

Kapi Note es una forma simple y rapida de llevar la puntuacion del domino. Crea dos equipos, agrega puntos y sigue los totales mientras juegas.

Funciones:
- Entrada rapida de puntos
- Guardado automatico de la partida
- Tamano de puntuacion ajustable
- Diseno limpio y enfocado

Perfecta para partidas casuales, juegos familiares y torneos.

What's New EN:

- Improved tablet layout with larger buttons and text
- Added adaptive banner support
- Improved home and game screen readability
- Minor UI improvements and stability updates

Novedades ES:

- Mejor diseno para tabletas con botones y texto mas grandes
- Soporte para banners adaptativos
- Mejor lectura en las pantallas de inicio y juego
- Mejoras menores de interfaz y estabilidad

Keywords cortos:

`domino,score,scorer,points,game,teams,tournament,tracker,dominó,marcador,puntos,juego,equipos,torneo`

## Verificaciones realizadas

Comandos usados durante el trabajo:

- `dart format`
- `flutter analyze lib/screens/home_screen.dart`
- `flutter analyze lib/screens/settings_screen.dart`
- `flutter analyze lib/screens/home_screen.dart lib/screens/game_screen.dart`
- `git commit`
- `git push`

## Pendientes sugeridos

- Revisar y limpiar los `print` restantes en `game_screen.dart`.
- Revisar el uso de `BuildContext` despues de operaciones async en `game_screen.dart`.
- Considerar configurar UMP/consentimiento, app-ads.txt y mediacion si el Match Rate de AdMob sigue bajo.

## Start Game / Nuevo juego

Pantalla nueva agregada en `lib/screens/start_game_screen.dart`.

Reglas y decisiones acordadas:

- El boton `Start Game` del Home abre la pantalla nueva de preparacion del juego.
- El boton `Open Notes` / `Abrir apuntes` mantiene el flujo viejo de anotacion.
- La pantalla nueva mantiene el mismo estilo visual del Home: fondo, colores rojo/azul, panel oscuro y botones redondeados.
- El usuario solo escribe iniciales de 2 letras.
- El nombre completo no debe mostrarse al otro jugador.
- La identidad publica del jugador debe verse como iniciales + pais + codigo, ejemplo: `ID: JP.US.59AA`.
- El codigo unico lo genera automaticamente la app; el usuario no lo escribe.
- Formato del sufijo automatico: 2 numeros + 2 letras (`59AA`).
- Cantidad teorica de sufijos posibles por combinacion de iniciales/pais: 67,600.
- El ID completo se muestra como texto informativo en la esquina superior izquierda, ejemplo: `ID: JP.US.59AA`.
- El codigo no debe parecer un campo editable ni una tarjeta principal; es informacion que la app asigna.
- Hay un boton para generar/refrescar otro codigo.
- La pantalla principal solo muestra el ID completo arriba; las iniciales y pais se editan desde el boton `Crear perfil`.
- El ID incluye pais. La app intenta usar el pais del dispositivo si esta soportado y tambien permite cambiar el pais manualmente desde `Crear perfil`.
- La pantalla tiene selector de modo:
  - `Classic` / clasico: paso sin pozo.
  - `Draw / Pool` / control con pozo: tomar fichas del pozo.
- La pantalla incluye boton de `Settings`.
- Se agrego boton `Ranking` en la pantalla de preparacion.
- El boton `Ranking` abre su propia pantalla: `lib/screens/ranking_screen.dart`.
- El boton y la pantalla deben decir claramente que es ranking de puntos/jugadores, no solo `Ranking`.
- La pantalla de ranking debe verse completa y separada del formulario de preparacion.
- El ranking debe tener una tarjeta fija arriba con `Tu posicion` para que el jugador siempre sepa donde esta aunque su fila este mucho mas abajo.
- La fila del jugador actual debe destacarse visualmente dentro de la lista.
- La pantalla tiene boton para saltar directamente a la posicion del jugador en la lista.
- El ranking debe evolucionar luego hacia puntos/rangos reales, pero por ahora queda como preview visual con datos de ejemplo.
- El ID publico debe verse centrado arriba, entre el boton de volver y el boton de settings, como texto compacto: `ID: JP.US.59AA`.
- El ID no debe verse como tarjeta grande ni como campo editable en la pantalla principal.
- La pantalla `Crear perfil` debe permitir escoger:
  - Iniciales de 2 letras.
  - Icono/avatar del jugador (persona, mujer, robot, arcoiris, juego, estrella, etc.).
  - Pais desde una lista legible con formato `US - United States`, `DR - Dominican Republic`, etc.; no usar chips pequenos para paises.
- En la pantalla principal de preparacion solo debe aparecer el ID completo arriba y el boton `Crear perfil` para editar iniciales, pais e icono.
- El perfil/ID del jugador se guarda localmente con `SharedPreferences`:
  - iniciales
  - pais
  - icono/avatar
  - codigo asignado por la app
- Si el usuario borra la app, el guardado local se pierde. Para recuperar el ID despues de borrar la app o cambiar de telefono, se debe hacer una segunda fase con Firebase/Auth o una cuenta/identidad estable.
- Cambiar el perfil tiene una oportunidad gratis para usuarios Free. Luego, otro cambio requiere:
  - ver un rewarded ad, o
  - tener Pro activo.
- El editor de perfil no debe aplicar cambios reales hasta tocar `Save Profile` / `Guardar perfil`.

## Juegos CPU en Flutter

- `Classic` y `Draw / Pool` deben abrir pantallas/rutas separadas desde `Start Game`.
- Ambos modos usan el perfil guardado: avatar/icono, iniciales y el ID corto en la mesa.
- Por ahora se juega contra CPU; la version online queda para una fase posterior.
- El CPU debe esperar antes de jugar para que se sienta que esta pensando.

## Lobby online / amigos / juego entre dispositivos

Fecha de trabajo: 2026-07-07

- Se activo Firestore para el proyecto Firebase `kapi-dominos`.
- Se creo la base Firestore `(default)` en `nam5`.
- Se agrego `firestore.rules` y se desplegaron reglas para el prototipo.
- Importante: las reglas actuales estan abiertas para probar lobby/amigos/juego online. Antes de produccion hay que cambiar a reglas seguras con Firebase Auth, Cloud Functions o validacion server-side para evitar trampas.
- El hashtag del jugador usa 6 caracteres y no permite `0` ni `O` para evitar confusion visual.
- El usuario puede cambiar iniciales, pais e icono/avatar, pero el hashtag/codigo se genera una sola vez y no debe cambiarse porque es la llave del jugador para puntos, ranking y amigos.
- Se corrigio la configuracion iOS de Firebase para usar el app id correcto de `com.liisgo.kapi.note`.
- Se agrego pantalla/ruta online `DominoOnlineGameScreen` en `lib/screens/domino_online_game_screen.dart`.
- Se agrego ruta `/domino-online` en `lib/main.dart`.
- El lobby ahora puede:
  - Registrar presencia online.
  - Resolver friend request por hashtag.
  - Aceptar/rechazar friend request.
  - Crear invitacion de juego.
  - Aceptar invitacion de juego.
  - Entrar a una partida online classic usando el mismo `gameId`.
- Verificacion realizada:
  - iPhone 16e envio friend request al iPhone 17 Pro Max y fue aceptado.
  - iPhone 16e invito al iPhone 17 Pro Max a una partida online y el 17 acepto.
  - Se jugo una ficha desde iPhone 16e y se sincronizo en iPhone 17.
  - Se jugo una ficha desde iPhone 17 y se sincronizo en iPhone 16e.
  - Android Pixel 9 Pro XL abrio la app, genero ID `JP.US.LJU3TX`, entro al lobby y aparecio online.
  - Android envio friend request al iPhone 16e y el 16e lo recibio y acepto.
  - iPhone 16e invito al Android a una partida online y Android acepto.
  - Se jugo una ficha desde iPhone 16e y Android recibio la mesa/turno.
  - Se jugo una ficha desde Android y el iPhone 16e recibio la mesa/turno.
  - El boton `Notes` desde la partida online abre la pantalla de apuntes.
  - La pantalla de apuntes muestra `Back to game` y vuelve a la partida online sin perder el estado.
- La primera ficha de la ronda debe marcarse en verde.
- Los dobles se distinguen visualmente.
- La mesa debe acomodar la cadena completa como un grupo centrado y escalarla junta si hace falta; no mover/clamp cada ficha individual porque eso separa la cadena.
- La primera ficha queda como ancla visual; las fichas nuevas solo pueden crecer desde las puntas abiertas, nunca insertarse en el medio.
- La mano del jugador debe vivir abajo, con boton `Ocultar/Ver` pegado a la mano; al ocultar debe verse al menos parte de las fichas y no debe tapar la mesa.
- Los controles de la mesa (`Opciones`, `Pasar`, `Pozo/Pool`) deben quedar en una columna derecha o espacio reservado para no tapar las fichas jugadas.
- La barra de mensaje debe aparecer cuando hay una accion y esconderse sola despues de unos segundos; durante `CPU pensando` debe quedarse visible.
- El perfil del jugador activo debe iluminarse. Cuando no sea turno del jugador, sus fichas deben verse apagadas; cuando sea su turno, solo las fichas validas deben resaltar.
- El CPU debe mostrar una etiqueta tipo `Unranked` / `No clasificatorio`, no Bronze ni otros rangos competitivos.
- El boton `Opciones` del juego debe incluir una forma clara de ir a la pantalla de notas/apuntes para anotar sin perder la partida.
- La pantalla de notas/apuntes debe tener un boton claro para regresar al juego activo y seguir jugando.
- El usuario debe poder alternar entre juego y notas: jugar, anotar, volver al juego, y continuar la misma partida.
- En juego contra CPU, el estado `CPU pensando` se maneja localmente en la misma partida.
- En juego online/futuro contra otra persona, el estado de turno debe comunicarse al otro jugador: si alguien esta pensando o jugando, la otra persona debe verlo para saber que esta esperando una jugada.
- En modo `Classic`, el jugador solo puede pasar cuando no tiene ficha valida.
- En modo `Draw / Pool`, el jugador solo puede tomar del pozo cuando no tiene ficha valida.
- Si el jugador tiene una ficha que coincide con una punta abierta, no debe poder robar/pasar.

## Futuro modo online / lobby / amigos

Idea acordada para implementar despues de estabilizar el juego contra CPU:

- Desde el boton `Opciones` o `Acciones` debe existir una entrada para crear un lobby.
- El jugador debe poder enviar `friend request` usando el ID publico del otro jugador.
- La otra persona debe poder aceptar, borrar o ignorar la solicitud.
- Cuando acepta, esa persona se agrega a la lista de amigos.
- En el lobby se debe poder ver la lista de amigos.
- El lobby debe indicar cuales amigos estan online.
- Si un amigo se conecta, el sistema puede mostrar una notificacion.
- Desde el lobby se debe poder invitar a un amigo online a jugar.
- La fase online debe usar el perfil publico del jugador:
  - avatar/icono elegido
  - iniciales de 2 letras
  - ID publico
  - pais
  - ranking/rango cuando aplique
- No mostrar nombres completos al otro jugador; solo iniciales + ID publico.
- Mantener separado el juego online del juego contra CPU para no romper la logica local.

Plan tecnico pendiente para hacerlo real:

- Agregar backend antes de intentar sincronizar dos emuladores:
  - Firebase Auth anonimo o login ligero para identidad estable.
  - Cloud Firestore para perfiles, amigos, solicitudes, presencia, lobbies y partidas.
  - Firebase Cloud Functions para validar jugadas importantes si hace falta.
- Reglas anti-trampa:
  - El cliente no debe decidir resultados oficiales por si solo.
  - Guardar estado de partida con turnos, puntas abiertas, fichas jugadas y version de estado.
  - Cada jugada debe validar que:
    - es el turno del jugador correcto.
    - la ficha pertenece a su mano.
    - la ficha coincide con una punta abierta.
    - no se inserta en el medio de la cadena.
    - no se repite una ficha ya jugada.
  - Usar transacciones/updates atomicos para evitar doble jugada o estados fuera de orden.
  - No guardar la mano del oponente visible para el otro jugador; separar datos privados por jugador.
  - Registrar historial de jugadas para auditoria y replay.
  - Presencia online con timestamps/heartbeat para saber quien esta online.
- Flujo de lobby:
  - Enviar solicitud por ID publico.
  - Aceptar/rechazar/borrar solicitud.
  - Lista de amigos con estado online/offline.
  - Crear lobby e invitar amigos online.
  - Notificacion cuando un amigo se conecta o invita a jugar.
  - Mantener Classic online separado de Draw/Pool online.
- Prioridad actual:
  - Terminar y verificar Classic contra CPU.
  - No trabajar Draw/Pool hasta que Classic este estable.
  - El boton `Opciones` del juego Classic debe tener `Seguir apuntes`, `Ranking` y `Lobby`.

## Lobby Firestore implementado parcialmente

- El lobby ya no debe ser solo mock local.
- Se agrego `cloud_firestore` para conectar dos instalaciones/emuladores.
- Colecciones usadas:
  - `kapi_lobby_profiles`: perfil publico y presencia online/offline.
  - `kapi_friend_requests`: solicitudes pendientes/aceptadas/rechazadas.
  - `kapi_friendships`: amistades aceptadas entre dos IDs publicos.
  - `kapi_game_invites`: invitaciones a jugar Classic pendientes.
- La presencia usa heartbeat cada 25 segundos y se considera online si el ultimo `updatedAt` tiene menos de 90 segundos.
- El lobby actual permite:
  - publicar el perfil publico del jugador.
  - enviar friend request por ID publico.
  - aceptar o rechazar solicitudes.
  - ver amigos online/offline.
  - enviar invitacion a un amigo online.
- Pendiente:
  - Crear pantalla de partida online real.
  - Sincronizar manos, turnos, mesa, mensajes y resultado.
  - Agregar reglas Firestore y/o Cloud Functions para evitar trampas antes de usar online en produccion.

## Actualizacion lobby y reglas Classic 2026-07-07

- Mantener Flutter en portrait; no forzar landscape.
- Para amigos, usar hashtag corto `#A1B2C3` con 6 caracteres alfanumericos. Hay 36^6 = 2,176,782,336 combinaciones teoricas, pero produccion debe verificar disponibilidad para evitar duplicados.
- El lobby debe aceptar tanto el hashtag corto como el ID publico completo `JP.US.A1B2C3`.
- Debe existir una forma de compartir por texto/WhatsApp el hashtag y el ID publico para que otro jugador pueda enviar friend request.
- En Classic, las fichas solo se colocan en puntas abiertas. La UI no debe insertar fichas en el medio.
- En Classic, el giro visual debe empezar mas temprano, despues de 3 fichas en un tramo, pero nunca usando una ficha doble como la pieza que inicia el giro. El doble se coloca normal y la proxima ficha regular decide el cambio de direccion.
- Al trancarse o terminar una ronda, mostrar visualmente las fichas restantes del CPU/oponente y del jugador.
- El boton para ir a Apuntes/Notas debe ser muy visible porque es el flujo principal: jugar, anotar, volver al juego.
- La opcion de tamano de fichas debe cambiar solo las fichas jugadas en la mesa, no las fichas de la mano del jugador.

## Codigo hashtag sin caracteres confusos

- Desde 2026-07-07 los codigos cortos de lobby usan 6 caracteres pero excluyen `0` y `O` para evitar confusion visual entre cero y letra O.
- Alfabeto permitido: `ABCDEFGHIJKLMNPQRSTUVWXYZ123456789`.
- Combinaciones posibles: 34^6 = 1,544,804,416.
- Si un perfil viejo tiene un codigo con `0` u `O`, el loader debe generar y guardar un codigo nuevo valido.
- El hashtag/codigo corto del jugador se genera una sola vez y no debe ser editable ni regenerable desde el editor de perfil. El usuario puede cambiar iniciales, pais e icono/nombre visible, pero el codigo corto se mantiene fijo para que sus amigos puedan encontrarlo.
- El hashtag/codigo corto fijo es la llave que graba todos los puntos, ranking y estadisticas del jugador. No usar iniciales, nombre, pais ni `publicId` como llave principal porque esos datos pueden cambiar; usarlos solo como metadata visible.

## Verificacion online 2026-07-07

- En la pantalla online no se debe decidir "quien soy" solamente comparando el perfil local, porque dos telefonos pueden terminar leyendo el lado equivocado si el perfil/cache coincide o si el invitado entro desde una invitacion.
- La ruta `/domino-online` debe recibir siempre `gameId` y `playerId` explicito desde el lobby al crear o aceptar una invitacion.
- Al jugar o pasar, las transacciones de Firestore deben usar ese `playerId` explicito para validar turno, mano y jugada. Si no se usa, puede ocurrir el error donde ambos telefonos muestran "Waiting for friend..." aunque una ficha ya fue jugada.
- En telefono pequeno tipo A51, Classic/Online debe ocultar datos secundarios cuando haga falta: no mostrar rangos largos, IDs completos ni texto extra dentro del tablero si eso quita espacio a las fichas.

## Verificacion Flutter Classic/Online 2026-07-07 tarde

- Mantener Flutter en portrait. No volver a cambiar Classic a landscape sin permiso explicito.
- Classic beta en Android pequeno debe compactar tarjetas de jugador/CPU, ocultar datos secundarios y dejar espacio real para las fichas.
- Se verifico visualmente en Android que Classic permite varias jugadas con CPU, mantiene el delay de 3 segundos, muestra `CPU thinking...`, activa `Pass` solo cuando no hay jugada valida y las fichas probadas se colocan en puntas abiertas.
- Se verifico que la pantalla de apuntes mantiene boton visible para regresar al juego; el back superior regreso correctamente al Classic.
- Online se corrigio para usar `playerId` explicito de la ruta y normalizar IDs en mayusculas. Esto evita que dos telefonos lean lados distintos y se queden en `Waiting for friend...` despues de la primera ficha.
- Pendiente antes de llamar online estable: probar una partida completa en dos dispositivos reales/emuladores al mismo tiempo, confirmar que el turno cambia en ambos lados y que no se repite el estado `Waiting for friend...`.

## Visual de ranking y perfiles 2026-07-07

- El rango del jugador debe sentirse visible en su perfil: avatar, marco, chip y tarjeta deben compartir el mismo color de liga.
- Bronze usa tonos bronce; Silver usa tonos plateados; Gold usa dorado; Platinum usa azul claro/brillo premium.
- CPU y perfiles `Unranked`/`No clasificatorio` no deben recibir marco de liga especial ni parecer clasificados.
- El panel de ranking debe usar la misma paleta visual que las tarjetas del juego para que el usuario entienda que es el mismo sistema.
- No inventar ranking contra CPU: el ranking real debe ser para partidas contra amigos/online.

## Lobby / Party social 1 vs 1

- Cuando el usuario presiona `Jugar`, no debe caer directo al tablero si va a jugar online. Primero debe entrar a una pantalla tipo Lobby/Party.
- El lobby debe sentirse como preparacion de partida 1 vs 1:
  - Tarjeta principal del jugador al centro o en zona destacada: avatar, iniciales, ranking, pais, ID/hashtag.
  - Un solo espacio de rival con boton `+` porque domino es 1 vs 1, no un party de 5 personas.
  - Al tocar `+`, abrir lista de amigos online para invitar.
  - Si el amigo acepta, ambos entran a la partida online.
  - Boton principal claro: `Encontrar partida`, para buscar otro jugador disponible.
  - Boton secundario: `Jugar contra CPU`, como fallback cuando no hay jugador real.
  - Panel de amigos/solicitudes/invitaciones limpio, inspirado en League of Legends: secciones separadas, estado online/offline, acciones visibles pero sin saturar.
  - El panel social debe usar tabs, buscador y secciones plegables tipo lista de juego: `Online`, `General`, `Invitaciones`, `Solicitudes` y `Anadir`.
- Flujo ideal:
  1. `Start Game`.
  2. Pantalla Lobby/Party.
  3. Elegir `Invitar amigo`, `Encontrar partida` o `Jugar contra CPU`.
  4. Cuando hay rival, entrar al tablero.
- Primero puede implementarse como mock funcional con datos simulados o datos actuales, y luego conectar completamente con Firebase para invitar, aceptar, matchmaking y presencia online.

## All Fives how-to y errores rojos 2026-07-10

- El modo `All Fives` debe tener su propia ayuda explicando:
  - Suma de puntas abiertas y puntos cuando el total es multiplo de 5.
  - Pozo/boneyard: si el jugador esta bloqueado, toma fichas hasta encontrar una jugable.
  - Spinner: el primer doble puede conectar por cuatro lados.
  - Final de ronda: se cuentan las fichas restantes y se suman al rival correspondiente.
- Los chequeos internos de debug para mazo, enlaces y alineacion no deben romper la app con una pantalla roja. Si detectan algo, deben dejar aviso interno y permitir que la app siga visible para poder corregir sin bloquear al usuario.

## Draw e iconos de modos 2026-07-10

- Draw mantiene cuatro paginas de ayuda separadas: objetivo, tomar del pozo, dobles y puntos al final.
- Los iconos de modos deben ser blancos y distintos: `5` para All Fives, pozo para Draw y bloqueo para Block.
- Los modos que vienen pronto mantienen su icono principal y muestran un candado pequeno como estado; no reemplazar todos los iconos con el mismo candado.

## Ranking consistente entre dispositivos 2026-07-10

- Todos los dispositivos deben ordenar el ranking igual: puntos descendentes, victorias descendentes, derrotas ascendentes e ID publico alfabetico como desempate final.
- Un perfil nuevo debe registrarse en la tabla compartida aunque tenga cero puntos. No mantenerlo solamente como una fila local, porque cada telefono terminaria viendo una lista diferente.

## Tabs del ranking por modo 2026-07-10

- El ranking debe mostrar tabs arriba en este orden: `Block`, `Draw`, `All Fives`.
- Block aparece seleccionado primero.
- Cada modo mantiene su propia vista y no mezcla jugadores de otros modos.
- Si un modo no tiene partidas registradas, mostrar un estado vacio claro.

## Ranking: anuncio y modos futuros 2026-07-10

- La pantalla Player Ranking debe mostrar un banner adaptable al pie, usando los IDs existentes de iOS y Android y ocultandose para Pro.
- Draw y All Fives todavia no estan disponibles. Al tocar sus tabs, mostrar un aviso y mantener Block seleccionado.

## Paleta de ayuda de los modos 2026-07-10

- Las ventanas `How to play` de Block, Draw y All Fives no deben usar el verde brillante del ejemplo externo.
- Deben integrarse con Kapi Note usando marco borgona oscuro, panel interior carbon azulado, texto blanco y acentos dorados.
- Los tres modos comparten esta presentacion para mantener consistencia visual.

## Rango consistente en lobby y ranking 2026-07-10

- El lobby no debe usar `Bronze` como valor predeterminado cuando falta el campo `rank` del perfil social.
- El rango de cada amigo se calcula desde `kapi_player_points.totalPoints`, la misma fuente usada por Player Ranking.
- Umbrales compartidos: Iron 0-99, Bronze 100-249, Silver 250-499, Gold 500-899 y Platinum desde 900.

## Comparacion de lobby actual y lobby simple 2026-07-10

- La version actual del lobby queda preservada en `/lobby`.
- El flujo oficial usa `/simple-lobby`; la seleccion entre lobby antiguo y nuevo fue eliminada.
- Durante esta etapa de verificacion, todas las pantallas muestran un identificador visible `Screen XX` para indicar exactamente cual se esta corrigiendo. El flujo principal es Screen 01 Home, Screen 02 Game Mode, Screen 03 Simple Lobby, Screen 04 Friends, Screen 05 Block CPU, Screen 06 Block Online y Screen 07 Notes. Settings, Profile, Ranking, Pro, Legal, About y pantallas auxiliares tambien tienen numeros propios.
- Screen 08 Settings abre pantallas separadas: Screen 15 Terms & Privacy y Screen 16 About. Ambas usan un boton Back visible para regresar a Settings.
- Screen 09 Game Settings usa el tema visual de Kapi Note y tiene controles independientes para el tamano de las fichas jugadas en la mesa y las fichas de la mano que el usuario toca. Ambos valores se guardan localmente y se aplican en CPU y online.
- Screen 15 incluye Terms & Conditions, Privacy Policy, Game Terms y Game Privacy para perfiles, IDs publicos, amigos, lobby, matchmaking, ranking, Firebase, anuncios y compras. Screen 16 usa el tema visual de Kapi Note y explica Notes, Block beta, CPU/online, perfil/ranking y los modos futuros.
- Screen 09 Game Settings y Screen 10 Note Settings comparten el mismo tema fijo de Kapi Note: encabezado rojo, fondo rojo a azul oscuro, tarjetas oscuras, texto claro y acentos dorados.
- Al continuar desde Game Mode se muestran temporalmente ambas opciones para compararlas.
- El lobby simple prioriza tres decisiones grandes: buscar jugador, invitar amigo o jugar contra CPU.
- No eliminar el lobby actual hasta que el usuario apruebe el nuevo flujo completo.
## Lobby Block online (2026-07-10)

- El ID que se comparte o se escribe para invitar es solo el codigo final de 6 caracteres, por ejemplo `TGHIDU`.
- `Find a player` usa una cola real de Firebase y conecta dos jugadores que esten buscando al mismo tiempo a una sola partida.
- Las invitaciones directas permiten elegir un amigo online o escribir su codigo de 6 caracteres.
- La lista de amigos se muestra en una pantalla separada, dividida entre Online y Offline.
- Las tarjetas del lobby muestran iniciales, pais y marco visual segun el ranking.
- El lobby nuevo conserva anuncio adaptable y muestra la version debajo del anuncio.
- El lobby anterior se mantiene separado como respaldo; los cambios nuevos viven en `screens/simple_lobby` y el servicio de emparejamiento en `services/block_matchmaking_service.dart`.

## Audio y partida Block online (2026-07-10)

- El audio del juego vive separado en `assets/music_for_game` y `assets/sfx_for_game`; no usar rutas escritas a mano fuera de `AudioAssets`.
- Musica y efectos tienen controles y volumen independientes, persistidos localmente. La pantalla `Audio Test` en Settings permite probar los 25 archivos.
- El AppBar de la partida online dice `Block` e incluye `Notes`, `Amigos` y `Settings`. La instruccion mas reciente del 2026-07-18 vuelve a incluir el boton de amigos; no eliminarlo sin aprobacion del usuario.
- En Block Online, las tarjetas superiores muestran el avatar equipado de cada jugador. La sala guarda `avatarKey` tanto para el anfitrion como para el invitado; no sustituirlo por iniciales salvo que no exista un avatar valido.
- `Pass` solo aparece dentro de la barra de notificacion cuando el jugador realmente no tiene jugada valida.
- La partida Block online acumula puntos por rondas hasta 100. Debe mostrar ronda, meta y puntuacion de ambos jugadores.
- Al terminar una ronda, mostrar ganador, puntos obtenidos y total. El ganador inicia la siguiente ronda.
- En un tranque con igual cantidad de puntos, gana quien produjo el tranque.
- La geometria del tablero debe validar dos cosas distintas: los valores logicos de cada punta deben coincidir y los rectangulos dibujados deben tocarse/alinearse. Nunca corregir solo la imagen ignorando la regla `punta == punta`.
- Las fichas nuevas deben entrar con animacion corta y sonido; invalidar una ficha debe dar feedback sin cambiar el estado.
- Al salir de una partida terminada, el selector nunca debe mostrar `Resume Game`. Resume solo aparece mientras la partida sigue activa.

## Menu y alcance del audio (2026-07-10)

- La musica y los efectos solo se reproducen dentro de partidas Block contra CPU u online. Home y Notes deben permanecer silenciosos.
- `/settings` es un menu simple con dos destinos: `Game Settings` y `Note Settings`.
- `Game Settings` controla mute y volumen de musica/efectos. `Note Settings` conserva idioma, tema, puntuacion y tamanos.
- El menu rapido dentro del juego debe permitir apagar musica y efectos sin abandonar la partida.
- Splash siempre abre Home aunque existan puntos guardados en Notes. Los puntos se conservan, pero nunca deben saltarse la pantalla principal.

## Estructura visual de Settings 2026-07-10

- `/settings` usa el estilo visual del juego: fondo borgona y azul oscuro, paneles carbon, texto blanco y acentos dorados.
- Los dos destinos principales aparecen primero: `Game Settings` y `Note Settings`.
- Debajo viven una sola vez las opciones de suscripcion, Terms & Privacy, About, anuncio adaptable y pie con version/contacto.
- `Note Settings` queda dedicado solamente a idioma, tema, puntuacion, bonus y tamanos; no duplicar alli cuenta, legal, anuncio ni pie.
- Las tres pantallas de configuracion (`Settings`, `Game Settings` y `Note Settings`) incluyen banner adaptable al final del contenido, sin cubrir controles.

## Exclusividad de salas Block online 2026-07-10

- Cada jugador solo puede pertenecer a una sala activa. La sesion guarda `state: inGame` y `activeGameId`.
- `Find a player` solo puede tomar jugadores con cola `searching` y sin una sesion ocupada.
- Crear una sala reserva a ambos jugadores atomicamente; si cualquiera ya esta en otra sala, la creacion se rechaza.
- El menu del tablero y el boton del sistema ofrecen `Leave room` con confirmacion.
- Salir marca la partida como abandonada, avisa al rival y libera a ambos para buscar otra sala.
- Una partida terminada libera las sesiones al pulsar Finish. No liberar una sesion si ya pertenece a otro `gameId`.
## Settings y tamano de fichas 2026-07-10

- Settings principal conserva Administrar/cancelar suscripcion, Terms & Privacy, About, anuncio y datos de LIISGO.
- Game Settings incluye un control persistente de 90% a 130% para el tamano de las fichas ya jugadas.
- El control afecta las fichas de la mesa contra CPU y online, pero no cambia el tamano de la mano del jugador.
- Version implementada: 5.0.51+65.
## Vista previa y actualizacion en vivo 2026-07-10

- Game Settings muestra una ficha de ejemplo que crece o disminuye con el slider.
- Los juegos abiertos reciben el nuevo tamano inmediatamente; no requieren reiniciar la partida.
- Version implementada: 5.0.52+66.
## Rival encontrado en lobby 2026-07-10

- Find a player reemplaza el espacio con signo + por la tarjeta del rival encontrado.
- Las iniciales aparecen una sola vez dentro del avatar; debajo se muestra el pais y el rango.
- Hay una espera visible de 3 segundos antes de abrir la partida.
- El lobby mantiene un solo ad banner en la parte inferior.
- Version implementada: 5.0.53+67.
## Musica Android al primer intento 2026-07-10

- La musica configura explicitamente el canal multimedia y audio focus en Android.
- Si Android no entra en estado playing al primer intento, el reproductor reinicia automaticamente una vez.
- Ya no debe ser necesario apagar y encender el interruptor de musica.
- Version implementada: 5.0.54+68.
## Menu consistente CPU y online 2026-07-10

- La partida contra CPU usa el mismo diseno corto del menu online.
- Ambos menus muestran audio, Game Settings y Note Settings en el mismo orden.
- Online conserva Salir de la sala; CPU usa Terminar partida con confirmacion.
- Version implementada: 5.0.55+69.
## Screen 02 - Game Mode responsive

- El boton Continue debe permanecer visible encima del ad banner, incluso en telefonos pequenos.
- El contenido superior puede desplazarse, pero Continue no depende del scroll.
- Los modos usan filas compactas: icono a la izquierda, nombre y estado a la derecha.
- Points Ranking va junto al titulo para ahorrar altura.
## Screen 05 - Player hand width

- La bandeja inferior de fichas del jugador debe usar todo el ancho disponible de la mesa, de esquina a esquina.
- No limitar la bandeja a una columna centrada ni agregar margenes laterales innecesarios.
## Screen 06 - Block Online

- Trabajar Screen 06 separada de Screen 05.
- Debe mostrar ad banner.
- La mano del jugador debe usar fichas grandes y aprovechar el ancho disponible.
- Las tarjetas de ambos jugadores muestran pais, nivel de ranking y puntuacion de la partida.
- La meta de Block Online es 30 puntos.
## Screen 07 / Screen 19 / Screen 06 navigation

- Screen 19 debe regresar a la misma instancia de Screen 07 al reiniciar Notes.
- Screen 07 conserva que fue abierta desde Screen 06 para que Game vuelva directamente a la sala activa.
- No crear una nueva Screen 07 desde Celebration porque pierde el origen online.

## Block scoring

- Al terminar una ronda se suman los puntos impresos en las fichas restantes, no la cantidad de fichas.
- En un tranque, gana la mano con menos puntos y recibe la suma de TODOS los puntos que quedan en ambas manos. Ejemplo: 8 + 5 = 13 puntos para el ganador.
## Online match presentation

- Al encontrar rival, mostrar una transicion VS con ambos perfiles, pais, ranking, sonido y choque electrico antes de Screen 06.
- La transicion dura aproximadamente 4 segundos; no mantener esperas duplicadas largas en el lobby.
- Cuando una partida online 1 vs 1 llega a la meta, mostrar confeti y sonido de celebracion.
- En una ronda bloqueada gana quien tenga menos puntos en sus fichas; recibe la suma combinada de ambas manos restantes.
- Cuando Online llega a la meta, el confeti siempre va acompanado por una tarjeta final con felicitacion, marcador, fichas restantes y regreso al lobby.
- El audio de Match Found debe inicializarse antes de sonar y usar tres momentos claros: jugador encontrado, impacto VS y partida lista.
- Las fichas ocultas del rival van debajo de su perfil, dentro de una bandeja discreta del tema, sin tapar texto.
- La confirmacion para salir de la sala usa el tema oscuro, dorado y rojo de Kapi Note.
- El listener de Find a Player debe cancelarse en cuanto se abre una sala.
- La ruta VS permanece activa debajo de Screen 06 y solo termina cuando el tablero realmente cierra; no usar pushReplacement porque puede completar el flujo del lobby demasiado pronto.
- Toda sala abandonada guarda abandonmentReason para distinguir salida confirmada, invitacion rechazada o errores futuros.
- Una pantalla atrasada nunca puede abandonar otra sala: `leaveGame` confirma que la sesion sigue `inGame` y que `activeGameId` coincide exactamente con la sala solicitada.
- Verificacion de 5.0.68+82: analisis limpio, siete pruebas aprobadas y dos perfiles distintos llegaron al mismo Screen 06 sin el falso mensaje "The other player left the room".
- Version posterior preparada: 5.0.69+83 para abrir una linea nueva en App Store Connect y evitar el tren cerrado 5.0.5. El archive valida como 5.0.69 (83); la exportacion queda pendiente de restaurar/crear el certificado Apple Distribution en Xcode.
- Al salir de una sala online, la app debe cancelar la busqueda anterior, liberar la sesion y esperar confirmacion del servidor antes de regresar al lobby. Una busqueda nueva usa un `searchToken` unico; listeners y cancelaciones anteriores no pueden afectar otra busqueda o sala.
- El codigo/hashtag de seis caracteres es permanente y nunca debe cambiar al editar iniciales, pais o avatar. SharedPreferences conserva el codigo mientras la app siga instalada. Para recuperarlo automaticamente despues de desinstalar en iOS y Android se necesita vincular el perfil a una cuenta autenticada (Apple/Google); no confiar solo en almacenamiento local ni en un identificador del dispositivo.
- Version 5.0.71+85 agrega la base de recuperacion del perfil con Firebase Authentication. Settings incluye `Proteger o recuperar perfil`; Apple/Google conservan el mismo codigo de seis caracteres en `kapi_player_accounts/{uid}`. Si la cuenta ya tiene perfil, se recupera ese perfil; si no, se protege el perfil local. El correo nunca se muestra a otros jugadores. Apple/Google deben activarse tambien en Firebase Console y Apple Developer/Google Cloud antes de produccion.
- Version 5.0.70+84 incluye la proteccion contra carreras al salir de una sala y volver a usar Find a Player.

## Recuperacion permanente del ID con cuenta (2026-07-11)

- Firebase Authentication tiene Google y Apple habilitados para `kapi-dominos`.
- Apple Developer tiene `Sign In with Apple` habilitado en el App ID publicado `com.liisgo.kapinote`.
- Android de produccion usa Firebase App ID `1:374261583168:android:8abb77eec508797af4fea5` para `com.liisgo.kapi.note`.
- Firebase Android conserva las huellas SHA-1 y SHA-256 de desarrollo y produccion; no volver a usar el registro antiguo `com.example.dominoes_note2025` para Kapi Note.
- iOS usa Firebase App ID `1:374261583168:ios:187954f7e739dc92f4fea5`, bundle `com.liisgo.kapinote` y el URL scheme de Google incluido en `Info.plist`.
- El perfil se guarda por UID en `kapi_player_accounts/{uid}`. Al reinstalar, entrar con la misma cuenta recupera el ID publico, pais, avatar y progreso asociados.
- El usuario puede proteger el perfil desde Settings o recuperar uno existente durante la creacion inicial. El correo de Apple/Google nunca se publica en el lobby.
- Verificacion final: `flutter analyze`, todas las pruebas, APK release y build iOS Simulator completados correctamente en 5.0.71+85.
- 2026-07-12: Block contra CPU y Block online 1 vs 1 usan una meta fija de 100 puntos. Las partidas online nuevas guardan `targetScore: 100` y las partidas activas tambien se muestran y completan con meta 100.
- 2026-07-12: Screen 03 Simple Lobby limita su contenido a 460 puntos de ancho para conservar proporciones similares entre teléfonos. En pantallas menores de 370 puntos de ancho o 760 de alto activa espaciado, títulos y botones compactos sin reducir el área táctil esencial.
- 2026-07-12: Los selectores Left/Right de Block CPU y Block Online deben mantener Cancel, Left y Right en una sola línea usando ajuste interno del texto. El selector online usa rojo de Kapi Note en vez de púrpura.
- 2026-07-12: El diálogo Leave room usa fondo oscuro, borde dorado y texto blanco de alto contraste; no debe depender de los colores de texto del tema general.
## Revancha online al terminar la partida (2026-07-12)

- La pantalla final de Block 1 vs 1 ofrece `Play Again` y `Return to Lobby`.
- La revancha solo comienza cuando ambos jugadores la aceptan.
- Mientras falta el rival se muestra `Waiting for opponent...`.
- Si el rival ya la pidio se muestra `Opponent wants a rematch`.
- Si uno vuelve al lobby, o no hay respuesta en 15 segundos, se cierra la sala para ambos y se liberan los dos jugadores.
- Una revancha conserva la misma sala y perfiles, pero reinicia marcador, ronda y fichas con meta de 100 puntos.
- 2026-07-12: Screen 03 Simple Lobby usa el layout compacto en todos los iPhone para mantener perfiles, encabezado y botones consistentes entre iPhone 16e y 17 Pro Max. Android conserva su layout actual.
- 2026-07-12: Version 5.0.75+89 corrige el bloqueo al guardar el primer perfil: Firebase Analytics requiere que `is_premium` sea numero o texto, por lo que se envia como 1/0 y nunca como booleano.
# Verificacion 2026-07-12

- Version 5.0.76+90: Find a Player vuelve a revisar la cola durante 30 segundos. Esto evita que dos jugadores que empiezan a buscar casi simultaneamente queden esperando para siempre por haber perdido el primer snapshot.
- Una app que se cierra o vuelve al lobby durante una sala activa debe reanudar esa misma Screen 06 automaticamente. Nunca debe dejar al jugador en Screen 03 con una sesion `inGame` invisible.
- Si la sesion local apunta a una partida `matchOver`, abandonada o inexistente, Screen 03 libera la sesion antes de permitir una busqueda nueva.
- Prueba intensiva 5.0.77+91: dos Android completaron dos partidas online consecutivas hasta 100 puntos, incluyendo 13 rondas en la revancha, pases, tranques, puntuacion combinada, confeti, fichas restantes y resultado identico en ambos dispositivos.
- En una prueba posterior desde Screen 03, ambos Android completaron otra partida sincronizada, pero un cliente registro una excepcion Firestore `failed-precondition` durante el cambio de ronda. El juego termino, pero este error se considera una regresion real: las escrituras online deben capturar y registrar fallos, y la automatizacion solo permite que el ganador avance la ronda para evitar dos transacciones simultaneas.
- No aprobar un build online si aparece `KAPI_ONLINE_ERROR`, `Unhandled Exception`, `FATAL EXCEPTION` o una divergencia de revision entre clientes. Repetir la partida completa despues de cada correccion.

# Regla permanente de conservacion de funciones (2026-07-15)

- No eliminar, ocultar, reemplazar ni desactivar una funcion, control, animacion, mensaje, sonido, pantalla o elemento visual que ya haya sido aprobado por el usuario.
- Antes de cualquier eliminacion hay que decir exactamente que elemento se propone eliminar, en que pantalla esta, por que se propone y esperar aprobacion explicita del usuario.
- Una auditoria, refactorizacion, correccion responsive o limpieza no autoriza borrar funciones existentes.
- Al corregir una pantalla se debe preservar todo lo ya aprobado: Notes, Settings, perfil/mensajes, audio, anuncios, version, animaciones, reglas y navegacion.
- Si una funcion parece duplicada o conflictiva, mantenerla y reportar el conflicto; no decidir su eliminacion automaticamente.

# Inventario actual Teams 2 vs 2 (2026-07-15)

- Existen dos modos separados: `Teams 2 vs 2 CPU` y `Teams 2 vs 2 Online`.
- El modo online busca hasta 30 segundos. Si no se completan cuatro humanos, llena los asientos libres con CPU y comienza. El jugador puede salir de la sala mientras espera.
- Cuando cuatro humanos llegan, los cuatro comparten la misma partida, revision, turnos, fichas, resultados y marcador en Firestore.
- En Teams online nunca se muestra ni se permite Reset. Reset se conserva solamente en Teams CPU.
- La primera mano abre con doble seis. En manos posteriores abre el dominador anterior con cualquier ficha.
- El tablero usa el camino adaptable aprobado, conserva uniones validas, evita solapamientos y reorganiza el recorrido para mantener las fichas lo mas grandes posible.
- Las fichas dobles se presentan atravesadas respecto a la linea. La orientacion inicial depende de si abre nuestro equipo o el rival.
- Cuando una ficha regular puede jugarse por ambos extremos equivalentes, se usa automaticamente el extremo derecho/inferior. Cuando los extremos representan elecciones distintas, se muestra el selector rojo/azul y ambos extremos parpadean con el color correspondiente.
- El boton Pass solo aparece durante el turno humano cuando no existe ninguna ficha jugable.
- Cada pase muestra una notificacion visible para todos: You/Partner/CPU L/CPU R pasa. Tambien reproduce el sonido de turno configurado.
- El pase redondo vale 10 solamente cuando un jugador coloca una ficha, los otros tres pasan y ese mismo jugador vuelve a colocar otra ficha. Recibir el turno no es suficiente. Cuatro pases que trancan la mano nunca reciben esos 10 puntos.
- En Teams 2 vs 2, quien tranca se compara solamente con el jugador que juega inmediatamente después. Gana quien tenga menos puntos entre esos dos y su equipo recibe la suma de todos los puntos que quedan en las cuatro manos. Los otros dos jugadores no deciden el tranque.
- Capicua y chuchazo otorgan 25 puntos adicionales a la suma normal de fichas restantes.
- La pantalla de resultado muestra ganador, perdedor/equipos, puntos, perfiles, niveles, fichas restantes, marcador, confeti, View final/blocked hand y Play again.
- El resultado y la mano final se pueden revisar antes de comenzar la siguiente mano.
- Los paneles de Partner, CPU L y CPU R muestran cuantas fichas conservan y resaltan a quien le toca. Los paneles inactivos bajan su intensidad.
- El perfil del jugador abre Quick messages tanto en CPU como online. Mensajes actuales: Well played, Thanks, Good luck, Good game, Wow, Oops, Hahaha y On fire, cada uno con emoji.
- En CPU el mensaje se muestra localmente; en online se publica en la partida y los cuatro clientes lo reciben como aviso temporal con nombre, emoji y texto.
- Teams conserva Notes, Settings, Rules, audio, banner adaptable, version visible y bloqueo de suspension de pantalla durante el juego.
- Game Settings controla musica, efectos, sus volumenes, tamano de la mano jugable y tamano de fichas colocadas. Los cambios se aplican a Teams y Block.
- La puntuacion de ranking usa el modo `teams_2v2`.

# Inventario actual Block (2026-07-15)

- Block CPU y Block online 1 vs 1 conservan sus reglas, tablero, selector de extremo, perfiles, ranking, Notes, Settings, sonidos, anuncios, version y celebracion final.
- El selector de extremo de Block usa el mismo sistema rojo/azul de extremos parpadeantes de Teams, sin depender de flechas ambiguas.
- Block online conserva exclusividad de sala, reanudacion, salida confirmada, abandono seguro y revancha aceptada por ambos jugadores.
- La pantalla final conserva perfiles, nivel, puntos, fichas restantes, confeti, Play Again y Return to Lobby.

# Auditoria integral 2026-07-15 - version 5.0.94+108

- Se ejecuto `flutter analyze` dos veces durante la auditoria; resultado final: cero problemas.
- Se ejecuto la suite completa dos veces. Resultado final repetido: 26 de 26 pruebas aprobadas.
- La validacion automatica completo 1,000 partidas Teams CPU, comprobando mazo de 28 fichas, turnos, equipos, aperturas, pases, tranques, premios, puntuacion y geometria despues de cada jugada.
- La validacion de Block completo 40 partidas deterministas rapidas y comprobo conexiones del tablero, turnos y reglas.
- APK debug Android compilo correctamente. No habia emulador Android disponible para una inspeccion visual real en esta auditoria; no confundir compilacion con prueba visual Android.
- iOS Simulator compilo correctamente despues de las verificaciones finales.
- Se usaron cuatro simuladores iOS: iPhone 16 Pro, iPhone 16e, iPhone 16 e iPhone 16 Plus.
- Teams online se probo dos veces de principio a fin con cuatro clientes humanos simultaneos. Los cuatro terminaron con el mismo resultado y perspectiva correcta; una partida termino trancada 50-0 y otra por domino 30-5.
- Block online se probo dos veces de principio a fin con dos clientes. Ambas partidas terminaron sincronizadas, 38-0 y 39-14.
- Teams CPU se abrio y reviso visualmente en los cuatro tamanos. Las 1,000 partidas automatizadas cubren la finalizacion completa de su logica.
- Block CPU se abrio y reviso visualmente en los cuatro tamanos. Las 40 partidas automatizadas cubren su logica completa.
- Home, Notes, Start Game, Settings y Game Settings se revisaron en los cuatro tamanos. No se detectaron desbordamientos de Flutter ni controles fuera de sus paneles.
- Quick messages se abrio en un cliente online real y se envio Well played. El envio del emisor, la escritura Firestore, la recepcion implementada y la prueba de widget quedaron verificados. La captura exacta del receptor no se obtuvo dentro de la ventana temporal de 3.2 segundos.
- Los registros de las partidas online revisadas no mostraron `KAPI_ONLINE_ERROR`, `Unhandled Exception`, `FATAL EXCEPTION` ni mensajes de overflow.
- Observacion menor sin eliminar nada: Settings puede mostrar la version en mas de un lugar dependiendo de la altura disponible. Es redundancia visual, no un fallo funcional, y no debe quitarse sin aprobacion.
- Observacion externa: los anuncios de prueba pueden tardar o no llenar un espacio en algun simulador; la version permanece visible debajo del area reservada.

# Correccion de orientacion de salida Teams 2 vs 2 (2026-07-15)

- Una ficha regular de salida colocada verticalmente debe pintar su extremo derecho logico hacia el brazo superior y su extremo izquierdo logico hacia el brazo inferior.
- La correccion es solamente visual: no cambia el orden de la cadena, los turnos, la puntuacion ni las reglas.
- Las salidas dobles permanecen simetricas y no se voltean.
- Esta regla tiene pruebas dedicadas y se valido junto con 1,000 partidas completas y el validador geometrico del tablero.

# Proteccion obligatoria de conexiones Teams 2 vs 2 (2026-07-15)

- Teams CPU y Teams Online usan el mismo `TeamDominoChainValidator` antes de aceptar cada ficha.
- La validacion funciona en builds release; no depende de `assert`.
- Antes de colocar se comprueba que la mesa actual sea valida, que el numero de la ficha coincida con el extremo elegido y que la orientacion resultante conserve toda la cadena.
- Despues de colocar se ejecuta una segunda comprobacion. Si falla, la jugada se revierte antes de descontar la ficha, sumar premios o avanzar el turno.
- Firestore rechaza una transaccion online si la cadena recibida o la jugada propuesta no es valida.
- Antes de dibujar se valida tambien la orientacion visual de cada ficha y de la ficha de salida. Una mesa que no pase esta barrera no se pinta; se muestra un estado seguro de verificacion.
- La suite incluye casos de conexiones derecha/izquierda, ficha invertida, numero fuera de 0-6, cadena previamente danada y salida vertical pintada al reves.
- La simulacion de 1,000 partidas ahora valida despues de cada jugada tanto la cadena logica como los numeros que quedan orientados hacia cada brazo visual.
# TestFlight con proteccion de conexiones 2v2 (2026-07-15)

- Se preparo la version `5.0.94+109` para TestFlight.
- Esta compilacion incluye la validacion obligatoria de conexiones logicas y visuales en Teams 2 vs 2, tanto CPU como online.
- La version rechaza y revierte cualquier ficha que no conecte correctamente antes de mostrarla o sincronizarla.

# Reportes y sugerencias desde Settings (2026-07-15)

- Settings conserva todas sus opciones aprobadas y agrega `Reportar error o sugerencia` dentro de `Cuenta y ayuda`.
- La opcion permite elegir entre reporte de error y sugerencia sin enviar nada automaticamente.
- El mensaje de correo se prepara para `sales@liisgo.com` con la version y la plataforma de la app, y el usuario decide si lo envia.
- Si el dispositivo no puede abrir una app de correo, la direccion de soporte se copia y se muestra un aviso.

# Identidad fija por jugador en Teams Online (2026-07-16)

- La sala online nunca debe asumir que el primer elemento de `players` es el usuario local.
- Cada telefono localiza su asiento global por el codigo permanente de su `publicId` y rota la vista para mostrar siempre su propio perfil en `Tu/You`, abajo. Cambiar iniciales o pais no cambia la identidad durante la reconciliacion.
- Nombre, avatar, pais y puntos permanecen unidos al mismo ID; al reanudar la busqueda se actualiza el perfil completo en su mismo asiento, nunca campos sueltos por posicion.
- Compañero y rivales se calculan en relacion con el asiento real del usuario: relativo 0 es el usuario, 1 rival derecho, 2 compañero y 3 rival izquierdo.
- Si el snapshot no contiene el ID local o contiene una identidad duplicada, la sala falla de forma segura y no presenta el perfil de otra persona como `Tu/You`.
- Las pruebas dedicadas verifican las perspectivas de JP y MP, la rotacion de los cuatro asientos, la ausencia del ID local y los IDs duplicados.
- Verificacion final: `flutter analyze` sin problemas y suite completa con 39 pruebas aprobadas.

# Verificacion real de identidad JP / MP (2026-07-16)

- La correccion de identidad se probo con dos instalaciones independientes: JP/US/JP0001 y MP/DO/MP0002.
- En la sala de JP, JP aparece siempre como `Tu/You` y MP como rival. En la sala de MP, MP aparece siempre como `Tu/You` y JP como rival.
- La misma relacion se conserva dentro de la partida desde las dos perspectivas; nombre, pais, avatar y puntos no cambian de propietario.
- Salir de la sala, reemplazar por CPU, enviar un mensaje rapido y actualizar un turno usan la identidad permanente del perfil, no el orden temporal del arreglo de jugadores.
- Si una identidad no coincide o esta duplicada, el cliente falla de forma segura en vez de adoptar el nombre de otro jugador.

# Tienda Kapi y cosmeticos (2026-07-16)

- La moneda cosmetica se llama `Kapi Coins`. Es independiente del ranking y nunca aumenta puntos competitivos ni cambia reglas, fichas disponibles o probabilidades.
- Cada perfil recibe 150 Kapi Coins de bienvenida una sola vez y 10 Kapi Coins por mano ganada.
- Las recompensas online llevan una clave unica por partida, revision e identidad para impedir que una reconstruccion de pantalla o una reconexion entregue monedas duplicadas.
- La tienda conserva las categorias Mesa, Dominos, Avatar, Bandera y Dados. Cada categoria tiene un articulo base gratuito y opciones comprables/equipables.
- Los articulos comprados, el saldo y la seleccion equipada se guardan localmente y se sincronizan con la cuenta cuando Firebase esta disponible.
- Equipar un avatar actualiza el perfil real. Equipar bandera la muestra junto al perfil local y en las salas/partidas online. Mesa y dominos se aplican visualmente sin alterar la logica del juego.
- El saldo usa una revision monotona al sincronizar; nunca se fusiona usando el saldo mayor porque eso podria devolver monedas ya gastadas.
- La tienda cabe y permite completar una compra en una pantalla automatizada de 320 x 720 puntos sin overflow.
- Las compras con dinero real NO estan habilitadas todavia. Antes de vender paquetes de monedas hay que crear productos oficiales de Apple/Google y validar recibos en un servidor; no se debe confiar en un saldo modificable solamente desde el cliente.

# Auditoria posterior a tienda e identidad (2026-07-16)

- `flutter analyze` termino sin problemas.
- La suite completa termino con 45 pruebas aprobadas.
- Se volvieron a completar 1,000 partidas Teams 2 vs 2 CPU y 40 partidas Block deterministas, ademas de validadores de cadena, reglas, pantallas compactas, mensajes, resultados, tienda e identidad online.
- Ninguna funcion aprobada fue eliminada para agregar la tienda: se conservan Notes, Settings, perfiles/mensajes, audio, anuncios, version, reglas, Reset solo en CPU y navegacion existente.
- Android release compilo correctamente: `app-release.apk`, SHA-256 `50a33281f0c0f3027e65a143b287e264004ba324a82ebe167288dd920ed89bb3`.
- iOS Simulator compilo correctamente y la version normal 5.0.94+109 quedo instalada y abierta en iPhone 16e e iPhone 16.
- El arranque final en ambos iPhone no produjo excepciones fatales ni mensajes de overflow; Home conserva todos sus botones y agrega Kapi Shop sin ocultar ninguna funcion previa.

# Revalidacion integral final (2026-07-17) - version 5.0.94+109

- Se reviso el arbol de cambios existente sin borrar, revertir ni sustituir ninguna funcion aprobada.
- `flutter analyze` termino con cero problemas.
- La suite completa termino con 45 pruebas aprobadas.
- La logica volvio a completar 1,000 partidas Teams 2 vs 2 CPU y 40 partidas Block deterministas, incluyendo reglas, turnos, pases, tranques, premios y validacion logica/visual de cada conexion.
- Las pruebas de identidad online confirmaron que JP y MP conservan nombre, avatar, pais, puntos y asiento relativo correctos; tambien pasaron Quick messages, tienda, recompensas y UI compacta.
- Android release compilo correctamente. APK: `build/app/outputs/flutter-apk/app-release.apk`; SHA-256 `50a33281f0c0f3027e65a143b287e264004ba324a82ebe167288dd920ed89bb3`.
- iOS Simulator compilo correctamente con la ruta normal de la aplicacion.
- Home se reviso en iPhone 16e, iPhone 16, iPhone 16 Pro e iPhone 16 Plus. Todos muestran Start Game, Open Notes, Remove Ads, Share App, Kapi Shop, Settings, Privacy Policy, banner y version sin controles cortados.
- Teams 2 vs 2 CPU, Block, Kapi Shop y Settings se abrieron individualmente para revision visual. Las mesas, manos, perfiles, botones, anuncios y version permanecen dentro de la pantalla.
- Despues de las inspecciones especiales se reinstalo la compilacion normal en los cuatro simuladores y se dejo Kapi Note abierta en Home.
- Los registros finales de los cuatro simuladores no mostraron `fatal`, `unhandled`, `overflow` ni `KAPI_ONLINE_ERROR`.
- Observacion visual menor preservada: Settings muestra la version en dos lugares. No afecta funciones y no debe eliminarse una de ellas sin autorizacion explicita del propietario.

# Economia de Kapi Coins basada en juego (2026-07-17)

- Se conservan 150 Kapi Coins de bienvenida y 10 Kapi Coins por cada mano ganada.
- Ningun articulo de pago puede costar menos de 300 Kapi Coins. Con el regalo inicial, el jugador debe ganar por lo menos 15 manos antes de comprar su primer cosmetico.
- Las banderas cuestan 350 Kapi Coins, equivalentes a 20 manos ganadas despues del regalo inicial.
- Los precios regulares progresan desde 300 hasta 700 Kapi Coins para que los cosmeticos mantengan valor y requieran juego real.
- Caribe, Domino Coral, Avatar Campeon y Dado Dorado son articulos exclusivos claramente identificados en la tienda y cuestan entre 1,000 y 1,400 Kapi Coins.
- Los articulos gratuitos base permanecen disponibles para que la personalizacion nunca impida jugar.
- Kapi Coins siguen siendo solamente cosmeticas: no alteran ranking, reglas, probabilidades, turnos ni puntuacion.
- Se agrego una prueba permanente que falla si algun articulo de pago baja del costo de 15 victorias o si el catalogo deja de tener articulos exclusivos.
- Verificacion final: `flutter analyze` sin problemas, 46 pruebas aprobadas, Android Release e iOS Simulator compilados correctamente.
- APK actualizado: `build/app/outputs/flutter-apk/app-release.apk`; SHA-256 `837c40be5ee84858647894f374947761c42c9efddebd9ae3428165d0387b732c`.
- La compilacion normal actualizada quedo instalada y abierta en iPhone 16e, iPhone 16, iPhone 16 Pro e iPhone 16 Plus.

# Boton para agregar Kapi Coins en pruebas (2026-07-17)

- Kapi Shop muestra un boton compacto `TEST +500` solamente en compilaciones de desarrollo o en un APK de prueba habilitado expresamente.
- Cada toque agrega 500 Kapi Coins y guarda el saldo, permitiendo probar compras, equipamiento, categorias y articulos exclusivos sin jugar decenas de manos durante QA.
- La compilacion publica oculta el boton y el servicio tambien rechaza la operacion; no basta con intentar abrir el control desde fuera de la interfaz.
- La economia real no cambia: 150 monedas de bienvenida, 10 por mano ganada y precios que exigen entre 15 y 20 victorias para la primera compra.
- La tienda y el boton se revisaron visualmente en iPhone 16e; no hubo overflow y el banner, version, precios y etiqueta `EXCLUSIVE` permanecen visibles.
- Verificacion final: `flutter analyze` sin problemas y 47 pruebas aprobadas, incluyendo persistencia del saldo de prueba, compra/equipamiento en 320 x 720, 1,000 partidas Teams 2 vs 2 y 40 partidas Block.
- APK de prueba con boton: `build/app/outputs/flutter-apk/kapi-note-test-coins.apk`; SHA-256 `7cc75dd2d9b97cb28d96a10274e554d0b0eaad959b799f6f5e5399d44207306e`.
- APK publico sin boton: `build/app/outputs/flutter-apk/app-release.apk`; SHA-256 `7fd67d0c4c53d85659a7c2458945c0c55248e08246adcc8cbcc75432d16f0ecc`.
- La compilacion normal de iOS se restauro, instalo y dejo abierta en iPhone 16e, iPhone 16, iPhone 16 Pro e iPhone 16 Plus.

# Rediseño premium de Kapi Shop (2026-07-17)

- Se elimino el amarillo plano de saldo, categorias y estado equipado. El dorado champan se usa solamente como acento, borde y texto de alto valor.
- La tienda usa fondo azul noche, superficies elevadas, sombras controladas, tarjetas con gradientes y estados diferenciados: comprar en verde petroleo, usar en azul profundo y equipado en dorado oscuro.
- El saldo aparece dentro de una capsula oscura con borde metalico. El panel de Kapi Coins y el boton `TEST +500` mantienen todas sus funciones con una presentacion mas discreta.
- Las categorias seleccionadas usan fondo oscuro y borde champan, sin bloques amarillos brillantes.
- La etiqueta de articulo exclusivo, precios, compras, equipamiento, monedas, anuncios y version se conservaron sin cambios funcionales.
- La tienda se inspecciono visualmente en iPhone 16e y paso la prueba automatizada de 320 x 720 sin overflow.
- Verificacion final: `flutter analyze` sin problemas y 47 pruebas aprobadas, incluyendo 1,000 partidas Teams 2 vs 2 y 40 partidas Block.
- APK de prueba actualizado: `build/app/outputs/flutter-apk/kapi-note-test-coins.apk`; SHA-256 `2694d8ef9187df5a936aa5e8fb4577491037dbc83c01933940815d98c92d6cc0`.
- APK publico actualizado: `build/app/outputs/flutter-apk/app-release.apk`; SHA-256 `769f2d112d8da455e466d1fbb3117389e8d36bf493c6099449514f0afa4ab2c2`.
- La compilacion normal quedo instalada y abierta en iPhone 16e, iPhone 16, iPhone 16 Pro e iPhone 16 Plus.

# Catalogo visual premium y tienda destacada (2026-07-17)

- Kapi Shop pasa a ser una accion destacada en Home, colocada junto a las acciones principales con saldo visible, icono de tienda, borde metalico y una descripcion breve. No se elimino ningun boton existente.
- Las cuatro mesas iniciales usan vistas de producto realistas: casino clasico verde, noche azul, caoba y Caribe. Las imagenes muestran superficies y materiales premium sin cambiar las reglas del tablero.
- Los cinco perfiles de la tienda usan retratos 3D semirrealistas coherentes con Kapi Note: jugador, estrella, robot, gamer y campeon.
- Se conservaron Republica Dominicana, Estados Unidos y Puerto Rico, y se agregaron Mexico, Colombia, Venezuela, Cuba, España, Panama, Brasil, Jamaica y Haiti.
- Las categorias y los precios dejaron de depender de emojis inconsistentes: ahora usan iconos nativos y una moneda dorada uniforme en Android e iOS.
- Se mantienen precios, saldo, compras, equipamiento, articulos exclusivos, TEST +500 en builds de prueba, anuncios y version. Esta es una nota historica; la integracion posterior de compras oficiales de Kapi Coins se documenta en una seccion posterior de este archivo.
- La prueba compacta de 320 x 720 ahora abre Mesas, Perfiles y Banderas, completa una compra y confirma que el catalogo ampliado no genera overflow.
- Verificacion final: `flutter analyze` sin problemas y 47 pruebas aprobadas, incluyendo 1,000 partidas Teams 2 vs 2, 40 partidas Block, cadena visual/logica, online, mensajes, Settings y tienda.
- Android release e iOS Simulator compilaron correctamente. APK publico: `build/app/outputs/flutter-apk/app-release.apk`; SHA-256 `0b1b20dbc13bd4cee5625ecaa03f00ace7a4d2627b9b7c2b67a2bec90e521ede`.
- La version normal quedo instalada y abierta en iPhone 16e, iPhone 16, iPhone 16 Pro e iPhone 16 Plus. Kapi Shop se inspecciono directamente en iPhone 16e con las cuatro mesas completas, anuncio y version visibles.
## Kapi Shop: centros de mesa y nombres neutrales (2026-07-18)

- Las cuatro mesas visibles se conservan sin cambios: Mesa clásica, Noche azul, Caoba y Caribe. No se deben convertir los nuevos motivos culturales en mesas completas.
- Se añadió la categoría independiente `Centro de mesa`. El jugador puede combinar cualquier centro comprado con cualquier mesa comprada, sin cambiar la mesa seleccionada ni interferir con el toque de las fichas.
- Centros disponibles: Sin centro, Escudo Quisqueya, Coquí de luna, Fiesta de plátano, Ritmo de fiesta, Águila dorada y Café tropical. Se muestran como adornos suaves debajo de las fichas.
- Las antiguas mesas experimentales de coquí, plátano, águila y agave permanecen cargables para no romper compras guardadas, pero quedaron ocultas del catálogo visible.
- Los nombres visibles de avatares son neutrales y de fantasía, como Campeón dorado, As carmesí, Táctico verde, As violeta, Caballero rubí, Campeona escarlata y Androide esmeralda. No se presentan avatares como asiático, indio, español, boricua, mexicano ni otra nacionalidad o etnia.
- Los identificadores internos antiguos de los avatares se conservan únicamente por compatibilidad con perfiles y compras ya guardados; esos identificadores no se muestran al usuario.
- Dados nuevos: Medianoche dorada, Turquesa Caribe, Rubí marfil, Amatista neón y Sol azul. El color del cuerpo y el color de los puntos son independientes y visibles en la tienda.
- Banderas añadidas: India, Japón y Corea del Sur, además de las banderas latinoamericanas y caribeñas ya existentes.
- Comprar y equipar se persiste en el dispositivo y en la cuenta autenticada. Equipar un avatar actualiza también el perfil público utilizado en las salas online.
- Los prompts y la procedencia de los recursos generados están documentados en `assets/kapi_shop/ASSET_PROMPTS.md`.

## Perfiles ampliados y selección visual de extremo en Teams 2v2 (2026-07-17)

- Al tocar el perfil propio, del compañero o de cualquiera de los dos rivales se abre una tarjeta grande con el avatar específico de ese asiento, bandera, nombre/iniciales, identificador, nivel, puntos, equipo y cantidad de fichas.
- El perfil propio conserva los emojis y mensajes rápidos aprobados; esta función no fue removida ni sustituida.
- Cuando una ficha puede jugarse en dos extremos diferentes, el jugador elige tocando directamente la ficha de previsualización roja o azul sobre la mesa.
- Los botones rojo y azul superiores fueron removidos por decisión del propietario; el mensaje superior solamente explica la acción y permite cancelarla.
- La zona táctil de cada previsualización cubre ahora toda la ficha coloreada visible y añade margen alrededor. Antes, la animación agrandaba la ficha visualmente pero dejaba una zona de toque pequeña, por lo que tocar el centro o los extremos podía no responder.
- La opción seleccionada queda marcada brevemente antes de colocar la ficha. Si ambos extremos tienen el mismo número se conserva la regla aprobada de jugar automáticamente por la derecha/abajo sin mostrar selector.
- El selector dejó de usar una ventana bloqueante, por lo que la mesa permanece visible e interactiva mientras se elige el color.
- Se añadieron pruebas permanentes para el perfil grande propio, el perfil del compañero y la conservación de Quick messages.
- Verificación final: `flutter analyze` sin problemas y 52 pruebas aprobadas, incluyendo una prueba que toca la esquina más alejada de la ficha coloreada, 1,000 partidas completas Teams 2v2, Block, reglas, conexiones, puntuación, UI compacta y perfiles.
- Android Release de prueba e iOS Simulator compilaron correctamente. APK de prueba: `build/app/outputs/flutter-apk/kapi-note-test-coins.apk`; SHA-256 `6fb06647a55a1193c1d5da0ac9e4d2219e6f0a805fce2eb465aa93bc022c5147`.
- La compilación quedó instalada y abierta en iPhone 16e, iPhone 16, iPhone 16 Pro e iPhone 16 Plus.

## Perfiles táctiles en Block (2026-07-17)

- Las dos tarjetas superiores de Block, tanto la del jugador como la del CPU, son controles táctiles y no deben volver a convertirse en elementos solamente visuales.
- Al tocar una tarjeta se abre un perfil grande con avatar, identificador, nivel, puntos acumulados, marcador actual y cantidad de fichas restantes.
- El perfil propio usa el avatar, bandera e información guardados del jugador; el CPU se identifica claramente como no clasificatorio.
- Esta función se añadió sin remover mensajes, ajustes, anuncios, cosméticos ni ninguna otra función existente de Block.

## Selección directa de extremo en Block (2026-07-17)

- Block usa el mismo patrón aprobado de Teams 2v2: cuando una ficha puede jugarse en dos extremos distintos, la elección se hace tocando directamente la ficha roja o azul dibujada sobre la mesa.
- Los botones grandes `RED` y `BLUE` del mensaje superior fueron eliminados. El mensaje ahora es compacto, no bloquea la mesa, explica que se toque una ficha coloreada y conserva solamente cancelar.
- Se eliminó el bloqueo de interacción que impedía tocar las vistas previas. Toda la ficha coloreada, incluidos sus bordes y un margen exterior, funciona como zona táctil.
- Si ambos extremos representan realmente la misma jugada, se conserva la regla aprobada de elegir automáticamente derecha/abajo sin mostrar selector.
- Verificación: `flutter analyze` sin problemas y 53 pruebas aprobadas. La prueba permanente toca la esquina exterior de la ficha coloreada de Block y confirma que el evento se recibe.

## Reacciones humanas del CPU al paso redondo (2026-07-17)

- En Teams 2 vs 2 contra CPU, un paso redondo real puede provocar de forma ocasional una reacción breve con emoji y mensaje rápido. No se activa por un pase común ni por un tranque.
- Cuando el jugador completa el paso redondo, uno de los dos rivales CPU puede responder con `Buena jugada`, `Wow` o `Está encendido`.
- Cuando un CPU completa el paso redondo, ese mismo CPU puede celebrarlo con `Está encendido`, `Jajaja` o `Wow`.
- Las reacciones son aleatorias y no aparecen siempre, para dar presencia a los rivales sin volver repetitiva la partida.
- Se reutilizan la notificación, animación, traducción y sonido de mensajes rápidos existentes; respetan los ajustes de audio del juego y no cambian puntuación, turnos ni reglas.
- Las partidas online continúan usando solamente los mensajes reales enviados por sus jugadores; esta automatización no se ejecuta online.
- La política tiene pruebas deterministas para comprobar que la reacción es ocasional, que un rival CPU responde al paso redondo del jugador y que el CPU que completa su propio paso redondo habla desde su asiento correcto.

## Regla del tranque en Teams 2 vs 2 (2026-07-17)

- El jugador que tranca es el último jugador que colocó una ficha antes de que ocurran los cuatro pases consecutivos.
- Para decidir el tranque, ese jugador se compara **solamente con el jugador que juega inmediatamente después de él** en el orden de turnos.
- Los otros dos jugadores, aunque tengan menos puntos o incluso cero puntos en sus fichas, no participan en la decisión del ganador del tranque.
- Entre el jugador que trancó y el jugador siguiente, gana quien tenga menos puntos en sus fichas restantes. Si empatan, la ventaja corresponde al jugador que produjo el tranque.
- El equipo del ganador recibe la suma de los puntos de todas las fichas que quedaron sin jugar entre los cuatro jugadores.
- Ejemplo obligatorio de regresión: si MP tranca con 7 puntos y el siguiente jugador, CPU R, tiene 26 puntos, gana MP. CPU L no puede ganar ese tranque aunque tenga 0 puntos.
- Esta regla es única y compartida por Teams 2 vs 2 contra CPU, Teams 2 vs 2 online y el simulador automático de partidas.
- La regla está protegida con pruebas directas y también con 1,000 partidas completas simuladas.
- Verificación final: `flutter analyze` sin problemas, 55 pruebas aprobadas, 1,000 partidas Teams 2 vs 2 validadas y compilación iOS Simulator correcta. La versión actualizada quedó instalada y abierta en iPhone 16.

## Superficie central de las mesas durante la partida (2026-07-17)

- Las vistas completas de mesa, con marco, esquinas y bandejas decorativas, se conservan en Kapi Shop para presentar el producto.
- Durante una partida de Block o Teams 2 vs 2 se usa solamente el material del centro de la mesa seleccionada. Ese material llena toda el área interior delimitada por la orilla dorada.
- La superficie se obtiene recortando y ampliando el centro de la imagen de la mesa, sin deformarla ni repetirla.
- No se modificaron las fichas, su encadenamiento, los perfiles, los controles, las reglas, la puntuación ni las zonas táctiles.
- El recorte afecta únicamente al fondo. Los perfiles y controles que sobresalen de la mesa permanecen completos y no se recortan.
- Verificación final: `flutter analyze` sin problemas, pruebas de superficie y UI compacta aprobadas, y revisión visual directa en Block y Teams 2 vs 2 sobre iPhone 16.
- Versión trabajada: `5.0.94+109`.

## Pro sin anuncios y paquetes oficiales de Kapi Coins (2026-07-18)

- Una cuenta Pro no muestra banners ni necesita ver anuncios recompensados para continuar una función. Tampoco se conserva un espacio vacío donde antes estaba el anuncio; la versión de la aplicación permanece visible.
- Kapi Shop ofrece cuatro consumibles oficiales: `kapi_coins_300` (300 monedas, precio objetivo de USD 1.99), `kapi_coins_550` (550, USD 2.99), `kapi_coins_2000` (2,000, USD 9.99, Popular) y `kapi_coins_4500` (4,500, USD 19.99, Mejor valor).
- El precio que se presenta cuando la tienda está activa proviene de App Store o Google Play y se muestra con la moneda y formato local del usuario. Los precios objetivo solo funcionan como vista previa mientras el producto todavía no está activo.
- Si Apple o Google no devuelve un producto activo, la aplicación no acredita monedas localmente ni simula una compra real.
- Cada transacción de monedas usa un identificador estable y una reclamación idempotente para impedir que el mismo recibo acredite dos veces.
- Los paquetes son consumibles cosméticos. No modifican reglas, turnos, ranking ni resultados competitivos.
- Antes de publicar, los cuatro productos deben crearse y activarse con exactamente esos identificadores en App Store Connect y Google Play Console.
- Para seguridad antifraude de producción, la validación definitiva de recibos/transacciones debe hacerse en un servidor confiable antes de entregar las monedas. La protección local y de Firebase evita duplicados accidentales, pero por sí sola no sustituye la validación de servidor.
- Versión trabajada: `5.0.94+109`.

## Premio de pase redondo para el compañero (2026-07-17)

- Un pase redondo real completado por el jugador del frente/compañero debe sumar `+10` al marcador compartido del equipo de ustedes, exactamente igual que cuando lo completa el jugador local.
- La acreditación quedó centralizada en una sola regla para CPU y online: los asientos 0 y 2 suman al equipo de ustedes; los asientos 1 y 3 suman al equipo rival.
- La bonificación solo se acredita después de que el mismo jugador que colocó la última ficha recibe tres pases consecutivos y vuelve a colocar una ficha válida. Un tranque o cuarto pase continúa sin premio.
- En la partida online el mensaje ahora muestra explícitamente que el compañero completó el pase redondo y recibió `+10`.
- Se añadieron pruebas permanentes para el compañero (asiento 2) y el compañero rival (asiento 3), verificando que cada premio llegue únicamente al equipo correcto.
- Verificación final: `flutter analyze` sin problemas, 58 pruebas aprobadas y 1,000 partidas completas Teams 2 vs 2 validadas.
- Versión trabajada: `5.0.94+109`.

## Tarjetas de perfil por encima de la mesa en Block (2026-07-17)

- La orilla dorada de la mesa nunca debe dibujarse por encima de las tarjetas superiores del jugador, la ronda o el CPU.
- El marco de la mesa se pinta sobre el material central, pero detrás de los perfiles y de todos los controles de juego.
- Las superficies de las tres tarjetas superiores son opacas para que ninguna parte del marco se transparente ni parezca cortar el avatar, el nombre o la puntuación.
- No se cambiaron la posición de las fichas, reglas, puntuación, perfiles táctiles, sonidos, anuncios ni controles.
- Versión trabajada: `5.0.94+109`.

## Contraste automático para la mano del jugador (2026-07-17)

- La bandeja inferior debe contrastar automáticamente con el diseño de dominó equipado.
- Cuando las fichas son negras u oscuras, la mano usa una superficie clara color champaña con una trama diagonal suave, borde dorado tenue y sombra para separar claramente cada ficha.
- Cuando las fichas son claras, la mano conserva una superficie oscura azul marino para mantener el contraste.
- Esta regla visual se comparte en Teams 2 vs 2 contra CPU, Teams 2 vs 2 online, Block contra CPU y Block online.
- El cambio es solamente visual: no modifica reglas, turnos, zonas táctiles, encadenamiento, puntuación, perfiles ni sonidos.
- Versión trabajada: `5.0.94+109`.
# Regla permanente de avatar y perfil

- Los avatares se compran, seleccionan y equipan exclusivamente en **Kapi Shop**.
- El editor de perfil solo permite cambiar las iniciales y el país. No volver a añadir ahí un selector de iconos o avatares.
- Toda superficie que represente a un jugador humano (tarjeta, lobby, partida, resultado y perfil ampliado) debe mostrar automáticamente el avatar equipado mediante `DominoAvatarVisual`, con un icono genérico únicamente como respaldo si el asset no está disponible.

## Pie inferior compacto en todas las pantallas (2026-07-18)

- Todas las pantallas con anuncio y versión deben usar un solo espacio seguro inferior; nunca se debe sumar el `SafeArea` de la pantalla al espacio que ya reserva el pie compartido.
- El anuncio debe quedar lo más abajo posible y la versión debe aparecer inmediatamente debajo, con separación mínima y sin una franja vacía adicional.
- En compilaciones de prueba, el identificador de pantalla comparte la misma fila inferior que la versión, alineado a la izquierda, y no crea una segunda fila.
- La regla se aplica a inicio, selección de juego, salas, partidas Block y Teams 2 vs 2, tienda, perfiles, ranking, ajustes y pantallas online.
- Verificación: `flutter analyze` sin problemas, 65 pruebas aprobadas y revisión visual en iPhone 16.
- Versión trabajada: `5.0.94+109`.

## Cuenta Kapi, país compacto y protección de Kapi Coins (2026-07-18)

- El editor de perfil conserva solamente las iniciales y el país. El país se selecciona con un menú desplegable compacto para no ocupar la altura completa de la pantalla.
- Desde el editor se puede registrar o recuperar una cuenta Kapi con correo y contraseña; Apple y Google continúan disponibles como métodos de cuenta protegida.
- Las cuentas creadas con correo deben verificar el email antes de comprar Kapi Coins. Jugar, ganar monedas y usar funciones gratuitas continúa disponible sin registro.
- Al intentar abrir o comprar un paquete de Kapi Coins sin una cuenta verificada, la aplicación abre primero el registro y no inicia la compra hasta completar la protección.
- El correo es privado y nunca se muestra a otros jugadores. El perfil público continúa usando iniciales, país y avatar equipado.
- El monedero cosmético se sincroniza en `kapi_player_accounts/{uid}.cosmetics`. Una cuenta nueva conserva y sube las monedas locales; al recuperar una cuenta existente, el monedero guardado en la nube tiene prioridad para evitar sobrescribirlo con datos viejos del teléfono.
- Firebase Authentication debe tener habilitado el proveedor **Email/Password** antes de publicar esta función.
- Versión trabajada: `5.0.94+109`.

## Lista persistente de amigos online y offline (2026-07-18)

- En Block Lobby, `Invite a friend` conserva las opciones anteriores para introducir un ID y compartir el ID público, y añade `Ver amigos online y desconectados`.
- La pantalla `Mis amigos` separa las amistades aceptadas en dos grupos: `En línea` y `Desconectados`. Cada grupo muestra su cantidad y tiene un control independiente para ocultarlo o mostrarlo.
- Los amigos no desaparecen al desconectarse. Las amistades aceptadas se guardan en `kapi_friendships`; la presencia reciente solo decide en cuál de los dos grupos aparece cada persona.
- Un amigo se considera online únicamente cuando su estado es `online` y su última actualización tiene menos de 90 segundos. Un estado viejo nunca debe dejar a alguien online indefinidamente.
- Desde el botón de agregar se puede enviar una solicitud usando el hashtag corto o el ID público completo. Las solicitudes recibidas se pueden aceptar o rechazar en la misma pantalla.
- Solo los amigos online muestran el botón `Invitar`; los desconectados permanecen visibles pero no se les puede enviar una invitación de partida hasta que regresen.
- Cuando todavía no hay amistades aceptadas, se presenta una vista previa claramente marcada como `EJEMPLO`, con jugadores online y offline. Estos perfiles de demostración nunca envían una invitación real.
- La partida continúa usando el sistema existente de invitaciones online; esta pantalla solamente organiza y expone las amistades persistentes sin reemplazar los flujos anteriores.
- Versión trabajada: `5.0.94+109`.

## Dados retirados de la tienda visible (2026-07-18)

- La categoría **Dados** queda retirada de Kapi Shop porque los juegos actuales de dominó no usan dados y mostrar skins sin una función real confunde al usuario.
- No se añade por ahora ningún botón de dados ni una función incompleta dentro de las partidas.
- Los identificadores, recursos, compras antiguas y selección guardada de dados se conservan internamente y ocultos para mantener compatibilidad con instalaciones de prueba anteriores; no se borra progreso ni datos del usuario.
- Idea futura guardada: una utilidad opcional e independiente para lanzar de 1 a 4 dados, con selección de cantidad, animación de lanzamiento, sonido, vibración y resultado claro. Esta función solo se implementará después de aprobar su experiencia completa.
- Una futura utilidad de dados no debe cambiar reglas, ranking, puntuación ni resultados de Block o Teams 2 vs 2.
- Versión trabajada: `5.0.94+109`.

## Expansión premium de Kapi Shop (2026-07-18)

- La expansión es completamente aditiva: no se retiró ninguna mesa, dominó, avatar, bandera, compra, selección ni artículo ya existente.
- Se añadieron tres mesas premium funcionales y equipables: **Club obsidiana**, **Terciopelo real** y **Cristal ártico**. Cada mesa tiene un asset original con centro despejado para mantener legible la cadena de dominó.
- Se añadieron seis estilos de dominó funcionales y equipables: **Jade**, **Perla**, **Amatista**, **Oro rosa**, **Neón lima** y **Obsidiana dorada**. Sus combinaciones de cuerpo y puntos mantienen contraste alto durante la partida.
- Se añadieron tres avatares premium funcionales y equipables: **Estratega nocturna**, **Táctico plateado** y **Campeón del alba**. Los nombres son neutrales y no etiquetan nacionalidades ni etnias.
- Los avatares nuevos están conectados al perfil público, lobbies, partidas, resultados y vista ampliada mediante la misma fuente única de selección de Kapi Shop.
- Se añadieron 16 banderas: Canadá, Argentina, Chile, Perú, Ecuador, Costa Rica, Guatemala, Honduras, El Salvador, Nicaragua, Portugal, Italia, Francia, Alemania, Filipinas y Reino Unido.
- Las banderas continúan siendo cosméticas. No sustituyen el país público del perfil ni cambian reglas, ranking, emparejamiento o resultados.
- La categoría de dados permanece oculta tal como fue aprobada. Esta expansión no añade ni reactiva dados.
- Los prompts de los seis assets nuevos quedan preservados en `assets/kapi_shop/ASSET_PROMPTS.md` para poder reproducir o ampliar el estilo visual.
- Las pruebas permanentes verifican IDs únicos, cantidad mínima por categoría, archivos existentes, nombres neutrales y conexión exacta entre cada avatar visible y su imagen de perfil.
- Versión trabajada: `5.0.94+109`.

## Verificación integral de compras y selecciones de Kapi Shop (2026-07-18)

- Cada artículo visible de Kapi Shop se prueba de forma automática: compra, descuento exacto de monedas, propiedad, selección, cambio por otro artículo de la misma categoría y restauración después de reiniciar el servicio.
- Volver a seleccionar o intentar comprar un artículo ya adquirido nunca descuenta monedas por segunda vez.
- Las selecciones de mesas, dominós, avatares, banderas y centros de mesa persisten correctamente. Los avatares equipados continúan conectados a la imagen pública del perfil.
- Se verificó también el cambio visual entre una opción comprada y la opción clásica directamente desde la tienda.
- Resultado final: 67 pruebas aprobadas, incluyendo 1,000 partidas completas de Teams 2 vs 2, 40 partidas rápidas de Block y las pruebas de interfaz en teléfonos pequeños.
- `flutter analyze` terminó sin problemas. El APK Release se generó correctamente, su archivo interno pasó la comprobación de integridad y contiene los recursos de avatares, centros de mesa y mesas.
- La aplicación se compiló, instaló y abrió correctamente en el simulador iPhone 16 para la comprobación visual final.
- APK final: `build/app/outputs/flutter-apk/app-release.apk`.
- SHA-256: `fb4eaa5ebb211a070e75fed4dc631a487c8b0aff42b38ab1e29a8f8fc9ca6`.
- Versión verificada: `5.0.94+109`.

## Cuenta Kapi protege monedas y ranking (2026-07-19)

- La tarjeta de registro debe comunicar claramente que una cuenta Kapi protege tanto los **Kapi Coins** como el **ranking** del jugador.
- El ranking competitivo continúa separado del monedero cosmético: registrar una cuenta nunca regala puntos, cambia resultados ni mezcla Kapi Coins con puntos de ranking.
- Al crear, recuperar o sincronizar una cuenta, se restaura el mismo código estable y `publicId` del perfil y se vuelve a registrar esa identidad en `kapi_player_points`. De esta manera el jugador conserva el mismo documento de ranking al iniciar sesión en otro dispositivo.
- Los mensajes de confirmación de cuenta deben mencionar explícitamente que se sincronizaron o protegieron las monedas y el ranking.
- Versión trabajada: `5.0.98+113`.
# Pantalla Kapi Note Pro con tema Kapi (2026-07-19)

- La pantalla Pro usa el tema oscuro, rojo y dorado de Kapi para mantener coherencia con la tienda y los juegos.
- Se mantienen las compras mensual/anual, aceptación legal, restauración de compras, continuar gratis y gestión de suscripción.
- Los mensajes técnicos de productos no disponibles no se muestran al jugador; se reemplazan por un aviso claro con opción de reintentar.
- Versión: `5.0.100+115`.
# Paneles de fichas en Kapi Shop (2026-07-19)

- Nueva categoría **Paneles / Trays** para personalizar el fondo del rack inferior donde se ven las fichas del jugador.
- Paneles disponibles: clásico, medianoche, caoba, caribe y real.
- Solo altera el panel inferior; no cambia las mesas ni el estilo de dominós.
- Se refleja automáticamente en Block CPU, Block Online y Teams 2v2, manteniendo contraste adaptativo para fichas claras u oscuras.
- Esta adición es independiente de dominós y Dice; no elimina funciones existentes.
- Versión técnica: **5.0.101+116**.
# Marcador manual Notes con tema Kapi (2026-07-20)

- El marcador manual conserva todas sus funciones existentes: editar nombres, sumar/restar, bono, totales, reset y acceso a ajustes.
- La presentación se actualizó al sistema visual actual de Kapi: fondo navy, barra superior rojo vino, paneles oscuros premium, azul para Team A, rojo para Team B y totales dorados.
- Versión: `5.0.104+119`.

# Inicio sin rótulo duplicado (2026-07-20)

- Se eliminó el rótulo “Online · vs CPU · Notes · 4 games” porque repetía el mensaje principal de inicio.
- Se conservaron el texto descriptivo, los botones y toda la navegación.
- Versión: `5.0.106+121`.

# Selector de modos estilo Kapi (2026-07-20)

- Se rediseñó el selector de modos con tarjetas compactas siguiendo el estilo visual de Kapi.
- El orden ahora prioriza **Block** y **Teams 2 vs 2**, seguido por la ayuda del modo activo.
- All Fives y Draw / Pool conservan su estado no disponible, con apariencia gris y candado.
- Se eliminaron las flechas laterales; el modo elegido se indica con un check claro.
- No se modificó la lógica de selección ni la navegación de los modos.
- Versión: `5.0.107+122`.
# Actualización visual — Block Lobby (2026-07-20)

- Versión `5.0.108+123`.
- Se renovó únicamente el aspecto del lobby de Block: fondo rojo/azul oscuro, estado de conexión, marca VS estilizada y botones verde/gris.
- No se modificaron las acciones de buscar jugador, invitar amigo ni jugar contra CPU.

## Ideas futuras

### Kapi Coach — asistente de entrenamiento

- Robot o mascota opcional para enseñar a jugar Block y Teams 2 vs 2.
- Al activarlo, recomienda una jugada sin jugar por la persona; por ejemplo: “Selecciona 5–1” o “Selecciona 5–6”.
- Puede iluminar la ficha y el extremo recomendado, acompañado por una explicación breve.
- Debe poder apagarse en cualquier momento y no modificar reglas, resultados, ranking ni el equilibrio de partidas online.
- Se implementará en una fase futura, una vez establecida la jugabilidad actual.
