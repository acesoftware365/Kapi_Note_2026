import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/anchored_adaptive_banner_ad.dart';
import '../widgets/game_audio_controls.dart';
import '../services/domino_display_settings.dart';

class GameAudioSettingsScreen extends StatefulWidget {
  const GameAudioSettingsScreen({super.key});

  @override
  State<GameAudioSettingsScreen> createState() =>
      _GameAudioSettingsScreenState();
}

class _GameAudioSettingsScreenState extends State<GameAudioSettingsScreen> {
  double _playedTileScale = 1.0;
  double _handTileScale = 1.0;

  @override
  void initState() {
    super.initState();
    DominoDisplaySettings.loadPlayedTileScale().then((value) {
      if (mounted) setState(() => _playedTileScale = value);
    });
    DominoDisplaySettings.loadHandTileScale().then((value) {
      if (mounted) setState(() => _handTileScale = value);
    });
  }

  String get _adUnitId =>
      defaultTargetPlatform == TargetPlatform.android
          ? 'ca-app-pub-8588489900323524/2555306020'
          : 'ca-app-pub-8588489900323524/9168815834';

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
        appBar: AppBar(
          backgroundColor: const Color(0xFF720B09),
          foregroundColor: Colors.white,
          title: Text(spanish ? 'Configuracion del juego' : 'Game Settings'),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF720B09), Color(0xFF171C24), Color(0xFF071524)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 18),
                    child: const GameAudioControls(),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: SizedBox(
                            height: 126,
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 48 * _handTileScale,
                                height: 88 * _handTileScale,
                                child: const RotatedBox(
                                  quarterTurns: 1,
                                  child: CustomPaint(
                                    painter: _DominoSizePreviewPainter(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.touch_app_rounded),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                spanish
                                    ? 'Tamano de fichas para jugar'
                                    : 'Playable hand tile size',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '${(_handTileScale * 100).round()}%',
                              style: const TextStyle(
                                color: Color(0xFFFFD36A),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _handTileScale,
                          min: DominoDisplaySettings.minHandTileScale,
                          max: DominoDisplaySettings.maxHandTileScale,
                          divisions: 4,
                          label: '${(_handTileScale * 100).round()}%',
                          onChanged: (value) {
                            setState(() => _handTileScale = value);
                            DominoDisplaySettings.saveHandTileScale(value);
                          },
                        ),
                        Text(
                          spanish
                              ? 'Cambia las fichas que tocas en tu mano.'
                              : 'Changes the tiles you tap in your hand.',
                          style: const TextStyle(
                            color: Color(0xFFCED2D9),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: SizedBox(
                            height: 112,
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                width: 66 * _playedTileScale,
                                height: 38 * _playedTileScale,
                                child: const CustomPaint(
                                  painter: _DominoSizePreviewPainter(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.aspect_ratio_rounded),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                spanish
                                    ? 'Tamano de fichas en la mesa'
                                    : 'Table tile size',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '${(_playedTileScale * 100).round()}%',
                              style: const TextStyle(
                                color: Color(0xFFFFD36A),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _playedTileScale,
                          min: DominoDisplaySettings.minPlayedTileScale,
                          max: DominoDisplaySettings.maxPlayedTileScale,
                          divisions: 4,
                          label: '${(_playedTileScale * 100).round()}%',
                          onChanged: (value) {
                            setState(() => _playedTileScale = value);
                            DominoDisplaySettings.savePlayedTileScale(value);
                          },
                        ),
                        Text(
                          spanish
                              ? 'Cambia solamente las fichas ya jugadas. Tu mano mantiene su tamano.'
                              : 'Only changes tiles already played. Your hand keeps its size.',
                          style: const TextStyle(
                            color: Color(0xFFCED2D9),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  spanish
                      ? 'Estos controles afectan las partidas online.'
                      : 'These controls affect online matches.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFCED2D9)),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/audio-test'),
                  icon: const Icon(Icons.graphic_eq_rounded),
                  label: Text(spanish ? 'Probar sonidos' : 'Test sounds'),
                ),
                const SizedBox(height: 22),
                AnchoredAdaptiveBannerAd(adUnitId: _adUnitId),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DominoSizePreviewPainter extends CustomPainter {
  const _DominoSizePreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(7),
    );
    canvas.drawShadow(Path()..addRRect(rect), Colors.black, 5, true);
    canvas.drawRRect(rect, Paint()..color = const Color(0xFFFFF4D9));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0xFF332A24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(size.width / 2, 5),
      Offset(size.width / 2, size.height - 5),
      Paint()
        ..color = const Color(0xFFB9AD91)
        ..strokeWidth = 1.5,
    );
    final pip = Paint()..color = const Color(0xFF171411);
    final radius = (size.shortestSide * 0.065).clamp(2.0, 4.5);
    for (final point in <Offset>[
      Offset(size.width * 0.18, size.height * 0.28),
      Offset(size.width * 0.34, size.height * 0.72),
      Offset(size.width * 0.66, size.height * 0.25),
      Offset(size.width * 0.82, size.height * 0.25),
      Offset(size.width * 0.74, size.height * 0.50),
      Offset(size.width * 0.66, size.height * 0.75),
      Offset(size.width * 0.82, size.height * 0.75),
    ]) {
      canvas.drawCircle(point, radius, pip);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
