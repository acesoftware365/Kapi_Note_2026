// lib/screens/fireworks_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import '../font_size_notifier.dart';
import 'dart:math';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import 'game_screen.dart';

// Particle class to represent individual particles (unchanged)
class Particle {
  Offset position;
  Color color;
  double size;
  Offset velocity;
  double lifetime;
  double initialLifetime;

  Particle({
    required this.position,
    required this.color,
    required this.size,
    required this.velocity,
    required this.lifetime,
  }) : initialLifetime = lifetime;

  void update() {
    position += velocity;
    lifetime -= 0.01;
    if (lifetime < 0) lifetime = 0;
  }
}

// CustomPainter for drawing fireworks particles (unchanged)
class FireworksPainter extends CustomPainter {
  final List<Particle> particles;

  FireworksPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.lifetime)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particle.size / 4)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(particle.position, particle.size * particle.lifetime, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class FireworksScreen extends StatefulWidget {
  final String winningTeamName;

  const FireworksScreen({super.key, required this.winningTeamName});

  @override
  State<FireworksScreen> createState() => _FireworksScreenState();
}

class _FireworksScreenState extends State<FireworksScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  final List<Particle> _particles = [];
  final Random _random = Random();


  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
      _updateParticles();
      if (_animationController.isCompleted) {
        if (mounted) {
          _generateInitialParticles(MediaQuery.of(context).size);
          _animationController.forward(from: 0.0);
        }
      }
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _resetGameNavigation();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_particles.isEmpty) {
      _generateInitialParticles(MediaQuery.of(context).size);
      _animationController.forward();
    }
  }

  void _showRewardedAdAndResetGame() {
    _resetGameNavigation();
  }

  Future<void> _resetGameNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('teamAScores');
    await prefs.remove('teamBScores');
    //this cause an error when press back button
    //Navigator.popUntil(context, ModalRoute.withName('/home'));
    // Navigate back to the home screen

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const GameScreen()),
    );


    //end of reset game navigation
    /*
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );

     */

  }


  void _generateInitialParticles(Size screenSize) {
    _particles.clear();
    final int numberOfParticles = 50 + _random.nextInt(50);
    final Offset explosionCenter = Offset(
      _random.nextDouble() * screenSize.width,
      _random.nextDouble() * screenSize.height,
    );

    for (int i = 0; i < numberOfParticles; i++) {
      final double angle = _random.nextDouble() * 2 * pi;
      final double speed = 2 + _random.nextDouble() * 4;
      final Color color = Color.fromARGB(
        255,
        _random.nextInt(256),
        _random.nextInt(256),
        _random.nextInt(256),
      );
      final double size = 2 + _random.nextDouble() * 3;

      _particles.add(
        Particle(
          position: explosionCenter,
          color: color,
          size: size,
          velocity: Offset(cos(angle) * speed, sin(angle) * speed),
          lifetime: 1.0,
        ),
      );
    }
  }

  void _updateParticles() {
    setState(() {
      _particles.removeWhere((particle) => particle.lifetime <= 0);
      for (var particle in _particles) {
        particle.update();
        particle.velocity = Offset(particle.velocity.dx, particle.velocity.dy + 0.05);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations appLocalizations = AppLocalizations.of(context)!;
    final fontSizeNotifier = Provider.of<FontSizeNotifier>(context);

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.purple.shade800,
                  Colors.blue.shade800,
                  Colors.green.shade800,
                ],
              ),
            ),
          ),
          CustomPaint(
            painter: FireworksPainter(_particles),
            child: Container(),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.celebration,
                    size: MediaQuery.of(context).textScaler.scale(100 * fontSizeNotifier.fontSizeScale),
                    color: Colors.yellowAccent,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${widget.winningTeamName} ${appLocalizations.maxScoreReachedMessage}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).textScaler.scale(30 * fontSizeNotifier.fontSizeScale),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black,
                          offset: Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: _showRewardedAdAndResetGame,
                    icon: const Icon(Icons.refresh),
                    label: Text(appLocalizations.resetGame),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
