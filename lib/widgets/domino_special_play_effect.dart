import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/kapi_cosmetics_service.dart';

enum DominoSpecialEffectKind { pass, roundPass, domino, capicua, blocked }

class DominoSpecialPlayEffect extends StatefulWidget {
  const DominoSpecialPlayEffect({
    required this.kind,
    required this.sequence,
    required this.spanish,
    this.playerName,
    super.key,
  });

  final DominoSpecialEffectKind kind;
  final int sequence;
  final bool spanish;
  final String? playerName;

  @override
  State<DominoSpecialPlayEffect> createState() =>
      _DominoSpecialPlayEffectState();
}

class _DominoSpecialPlayEffectState extends State<DominoSpecialPlayEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _isCapicua => widget.kind == DominoSpecialEffectKind.capicua;
  bool get _isDomino => widget.kind == DominoSpecialEffectKind.domino;
  bool get _isRoundPass => widget.kind == DominoSpecialEffectKind.roundPass;
  bool get _isBlocked => widget.kind == DominoSpecialEffectKind.blocked;

  Color get _accent {
    final selected = KapiCosmeticsService.instance.equipped(
      KapiCosmeticType.specialEffect,
    );
    if (selected.macProOnly && KapiCosmeticsService.instance.macProAccess) {
      return selected.secondary;
    }
    return _isCapicua
        ? const Color(0xFFFFD65A)
        : _isDomino
        ? const Color(0xFF64F0B5)
        : _isBlocked
        ? const Color(0xFFFFB82E)
        : _isRoundPass
        ? const Color(0xFF66E8FF)
        : const Color(0xFF72C7FF);
  }

  String get _title => switch (widget.kind) {
    DominoSpecialEffectKind.pass => widget.spanish ? '¡PASO!' : 'PASS!',
    DominoSpecialEffectKind.roundPass =>
      widget.spanish ? '¡PASE REDONDO!' : 'ROUND PASS!',
    DominoSpecialEffectKind.domino => '¡DOMINÓ!',
    DominoSpecialEffectKind.capicua => '¡CAPICÚA!',
    DominoSpecialEffectKind.blocked =>
      widget.spanish ? '¡BLOQUEO!' : 'BLOCKED!',
  };

  String get _subtitle => switch (widget.kind) {
    DominoSpecialEffectKind.pass =>
      widget.playerName == null
          ? (widget.spanish ? 'Turno completado' : 'Turn completed')
          : widget.playerName!,
    DominoSpecialEffectKind.roundPass =>
      widget.spanish ? 'Vuelta completa  ·  +10' : 'Full rotation  ·  +10',
    DominoSpecialEffectKind.domino =>
      widget.playerName == null
          ? (widget.spanish
              ? 'SIN FICHAS  ·  MANO GANADA'
              : 'NO TILES  ·  HAND WON')
          : '${widget.playerName}  ·  ${widget.spanish ? 'MANO GANADA' : 'HAND WON'}',
    DominoSpecialEffectKind.capicua =>
      widget.spanish ? 'JUGADA ESPECIAL  ·  +25' : 'SPECIAL PLAY  ·  +25',
    DominoSpecialEffectKind.blocked =>
      widget.spanish
          ? 'TRES PASES  ·  MANO TRANCADA'
          : 'THREE PASSES  ·  BLOCKED HAND',
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds:
            _isCapicua ? 2900 : (_isDomino ? 2850 : (_isBlocked ? 2600 : 2100)),
      ),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final value = _controller.value;
          final entrance = Curves.easeOutBack.transform(
            (value / 0.38).clamp(0.0, 1.0),
          );
          final exit =
              1 -
              Curves.easeIn.transform(((value - 0.78) / 0.22).clamp(0.0, 1.0));
          final opacity = math.min(entrance, exit).clamp(0.0, 1.0);
          final pulse = 1 + math.sin(value * math.pi * 5) * 0.025;
          return Opacity(
            opacity: opacity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha:
                          (_isCapicua || _isDomino || _isBlocked
                              ? 0.40
                              : 0.20) *
                          opacity,
                    ),
                  ),
                ),
                for (
                  var ring = 0;
                  ring < (_isCapicua || _isDomino || _isBlocked ? 3 : 2);
                  ring++
                )
                  Transform.scale(
                    scale: 0.55 + value * (1.15 + ring * 0.28),
                    child: Opacity(
                      opacity: (1 - value) * (0.55 - ring * 0.1),
                      child: Container(
                        width: 210,
                        height: 210,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _accent, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.65),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_isCapicua)
                  ...List.generate(14, (index) {
                    final angle = (math.pi * 2 / 14) * index;
                    final distance = 92 + value * 105;
                    return Transform.translate(
                      offset: Offset(
                        math.cos(angle) * distance,
                        math.sin(angle) * distance,
                      ),
                      child: Transform.rotate(
                        angle: angle + value * 2,
                        child: Icon(
                          index.isEven
                              ? Icons.auto_awesome_rounded
                              : Icons.diamond_rounded,
                          color: index.isEven ? _accent : Colors.white,
                          size: index.isEven ? 18 : 10,
                        ),
                      ),
                    );
                  }),
                if (_isDomino)
                  ...List.generate(12, (index) {
                    final angle = (math.pi * 2 / 12) * index;
                    final distance = 88 + value * 92;
                    return Transform.translate(
                      offset: Offset(
                        math.cos(angle) * distance,
                        math.sin(angle) * distance,
                      ),
                      child: Transform.rotate(
                        angle: angle + value * math.pi,
                        child: Icon(
                          index.isEven
                              ? Icons.grid_view_rounded
                              : Icons.auto_awesome_rounded,
                          color: index.isEven ? Colors.white : _accent,
                          size: index.isEven ? 16 : 19,
                        ),
                      ),
                    );
                  }),
                Transform.scale(
                  scale: entrance * pulse,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 520),
                    margin: const EdgeInsets.symmetric(horizontal: 28),
                    padding: EdgeInsets.symmetric(
                      horizontal: _isCapicua ? 34 : 28,
                      vertical: _isCapicua ? 28 : 22,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xF20B1723),
                          _isCapicua
                              ? const Color(0xF2523100)
                              : _isDomino
                              ? const Color(0xF2074C3A)
                              : _isBlocked
                              ? const Color(0xF25A2400)
                              : const Color(0xF20B2940),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _accent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.60),
                          blurRadius: _isCapicua ? 42 : 26,
                          spreadRadius: _isCapicua ? 7 : 2,
                        ),
                        const BoxShadow(
                          color: Colors.black87,
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isCapicua
                              ? Icons.auto_awesome_rounded
                              : _isDomino
                              ? Icons.grid_view_rounded
                              : _isBlocked
                              ? Icons.lock_rounded
                              : _isRoundPass
                              ? Icons.sync_rounded
                              : Icons.skip_next_rounded,
                          color: _accent,
                          size: _isCapicua || _isDomino ? 54 : 42,
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _title,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _isCapicua || _isDomino ? 46 : 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing:
                                  _isCapicua || _isDomino ? 2.5 : 1.5,
                              shadows: [
                                Shadow(color: _accent, blurRadius: 18),
                                const Shadow(
                                  color: Colors.black,
                                  blurRadius: 4,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _accent,
                            fontSize: _isCapicua || _isDomino ? 17 : 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
