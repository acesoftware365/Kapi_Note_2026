# Memoria para Codex

Fecha de trabajo: 2026-06-07

Este documento resume los cambios realizados hoy en el proyecto Kapi Note para que Codex pueda recuperar rapido el contexto en futuras sesiones.

## Kapi Note v2.0 / etapa juego beta

Fecha de corte: 2026-07-07

- El usuario decidio empezar a llamar esta nueva etapa **Version 2 del app** porque agrega el juego de domino dentro de Kapi Note.
- Para tiendas, no bajar el numero tecnico de `pubspec.yaml` a `2.0.0` si ya existe una version `5.x` subida; Apple/Google pueden rechazar versiones menores. Usar `v2.0` como nombre interno, tag de Git o nombre de etapa.
- Version tecnica actual del build: `5.0.7+21`.
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
