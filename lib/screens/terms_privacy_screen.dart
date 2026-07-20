import 'package:flutter/material.dart';

import '../legal/legal_content.dart';

class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spanish = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          spanish ? 'Terminos y privacidad' : 'Terms & Privacy',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: spanish ? 'Volver' : 'Back',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/image/background.png',
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.48),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF720B09),
                    Color(0xE6171C24),
                    Color(0xFF071524),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
              children: [
                _LegalSection(
                  title: LegalContent.termsTitle,
                  icon: Icons.description_rounded,
                  body: LegalContent.termsBody,
                ),
                const SizedBox(height: 16),
                _LegalSection(
                  title: LegalContent.privacyTitle,
                  icon: Icons.lock_rounded,
                  body: LegalContent.privacyBody,
                ),
                const SizedBox(height: 16),
                _LegalSection(
                  title: spanish ? 'Terminos del juego' : 'Game Terms',
                  icon: Icons.sports_esports_rounded,
                  body:
                      spanish
                          ? '''Block Dominoes esta disponible como funcion beta. Las partidas pueden cambiar mientras seguimos mejorando las reglas, la sincronizacion y el rendimiento.

Debes jugar de manera justa. No puedes manipular partidas, puntos, ranking, solicitudes de amistad, salas o resultados. Podemos corregir o eliminar resultados obtenidos mediante errores, abuso o trampas.

Las partidas online dependen de la conexion de ambos jugadores y de los servicios de Firebase. Una desconexion, salida de sala o problema de red puede interrumpir o terminar una partida.

El ID publico identifica tu perfil y conserva tu progreso. No compartas informacion personal en tus iniciales, invitaciones o comunicaciones relacionadas con el juego.

El ranking solo representa resultados registrados por Kapi Note. No es un premio monetario y puede ajustarse para mantener una competencia justa.'''
                          : '''Block Dominoes is currently available as a beta feature. Matches may change as we continue improving rules, synchronization, and performance.

You must play fairly. You may not manipulate matches, points, rankings, friend requests, rooms, or results. We may correct or remove results obtained through errors, abuse, or cheating.

Online matches depend on both players' connections and Firebase services. A disconnection, room exit, or network issue may interrupt or end a match.

Your public ID identifies your profile and keeps your progress. Do not include personal information in initials, invitations, or game-related communications.

The ranking only represents results recorded by Kapi Note. It has no monetary value and may be adjusted to maintain fair competition.''',
                ),
                const SizedBox(height: 16),
                _LegalSection(
                  title: spanish ? 'Privacidad del juego' : 'Game Privacy',
                  icon: Icons.shield_rounded,
                  body:
                      spanish
                          ? '''Para ofrecer perfiles, amigos, lobby, matchmaking, partidas online y ranking, Kapi Note puede guardar en Firebase tu ID publico, iniciales, pais seleccionado, avatar, estado online, solicitudes, salas, resultados, puntos y actividad necesaria para sincronizar la partida.

Otros jugadores pueden ver tu ID publico, iniciales, pais, avatar, rango, puntos y estado online. Tu nombre real, correo y datos de pago no se muestran como parte del perfil del juego.

Las preferencias de sonido, idioma, tema y tamano de fichas pueden guardarse localmente en tu dispositivo. Analytics puede registrar el modo seleccionado, pais seleccionado, inicio o final de partidas y eventos de uso para mejorar la app.

No vendemos tus datos personales. Los anuncios, compras y servicios externos procesan informacion de acuerdo con sus propias politicas.'''
                          : '''To provide profiles, friends, lobby, matchmaking, online matches, and rankings, Kapi Note may store your public ID, initials, selected country, avatar, online status, requests, rooms, results, points, and activity needed to synchronize a match in Firebase.

Other players may see your public ID, initials, country, avatar, rank, points, and online status. Your real name, email, and payment details are not displayed as part of the game profile.

Sound, language, theme, and tile-size preferences may be stored locally on your device. Analytics may record the selected mode, selected country, match starts or completions, and usage events to improve the app.

We do not sell your personal data. Ads, purchases, and external services process information under their own privacy policies.''',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({
    required this.title,
    required this.icon,
    required this.body,
  });

  final String title;
  final IconData icon;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xEE171C24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFFD36A).withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 34, color: const Color(0xFFFFD36A)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              body,
              style: const TextStyle(color: Color(0xFFD7D9DF), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
