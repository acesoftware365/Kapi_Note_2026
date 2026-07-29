import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../url_link/link_button.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spanish = Localizations.localeOf(context).languageCode == 'es';
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF071524),
        cardColor: const Color(0xEE171C24),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD36A),
          secondary: Color(0xFFF13A37),
          surface: Color(0xEE171C24),
        ),
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            spanish ? 'Acerca de' : 'About',
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
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xEE171C24),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFFD36A).withValues(alpha: 0.55),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 14,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.sports_esports_rounded,
                            size: 52,
                            color: Color(0xFFFFD36A),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Kapi Note',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            spanish
                                ? 'Una aplicacion creada para apuntar y jugar domino de forma sencilla.'
                                : 'An app created to score and play dominoes simply.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFD7D9DF),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _AboutFeature(
                            icon: Icons.edit_note_rounded,
                            title:
                                spanish
                                    ? 'Apuntes de domino'
                                    : 'Domino scorekeeping',
                            body:
                                spanish
                                    ? 'Anota puntos rapidamente y cambia entre la mesa y el marcador.'
                                    : 'Track scores quickly and move between the table and scorekeeper.',
                          ),
                          const SizedBox(height: 14),
                          _AboutFeature(
                            icon: Icons.extension_rounded,
                            title: 'Block Dominoes beta',
                            body:
                                spanish
                                    ? 'Juega online mediante lobby y matchmaking.'
                                    : 'Play online through lobby and matchmaking.',
                          ),
                          const SizedBox(height: 14),
                          _AboutFeature(
                            icon: Icons.leaderboard_rounded,
                            title:
                                spanish
                                    ? 'Perfil, amigos y ranking'
                                    : 'Profile, friends, and ranking',
                            body:
                                spanish
                                    ? 'Tu ID publico mantiene tus amigos, resultados, puntos y posicion.'
                                    : 'Your public ID keeps your friends, results, points, and position.',
                          ),
                          const SizedBox(height: 14),
                          _AboutFeature(
                            icon: Icons.upcoming_rounded,
                            title:
                                spanish
                                    ? 'Draw disponible'
                                    : 'Draw is available',
                            body:
                                spanish
                                    ? 'Draw con pozo ya está disponible online. All Fives continúa en desarrollo.'
                                    : 'Draw with a pool is now available online. All Fives remains in development.',
                          ),
                          const SizedBox(height: 26),
                          LinkButton(
                            text: 'WWW.LIISGO.COM',
                            url: 'https://www.liisgo.com',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'LIISGO LLC',
                            style: TextStyle(color: Color(0xFFD7D9DF)),
                          ),
                          const SizedBox(height: 4),
                          FutureBuilder<PackageInfo>(
                            future: PackageInfo.fromPlatform(),
                            builder: (context, snapshot) {
                              final version = snapshot.data;
                              return Text(
                                version == null
                                    ? 'Version'
                                    : 'Version ${version.version}+${version.buildNumber}',
                                style: const TextStyle(
                                  color: Color(0xFFD7D9DF),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutFeature extends StatelessWidget {
  const _AboutFeature({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFFFD36A), size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(color: Color(0xFFD7D9DF), height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
