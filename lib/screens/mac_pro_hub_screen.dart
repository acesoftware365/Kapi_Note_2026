import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../premium_notifier.dart';
import '../services/mac_pro_features_service.dart';

class MacProHubScreen extends StatefulWidget {
  const MacProHubScreen({super.key});

  @override
  State<MacProHubScreen> createState() => _MacProHubScreenState();
}

class _MacProHubScreenState extends State<MacProHubScreen> {
  static const _gold = Color(0xFFFFD36B);
  int _targetScore = 100;
  Set<String> _registered = {};

  bool get _spanish => Localizations.localeOf(context).languageCode == 'es';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final target = await MacProFeaturesService.instance.targetScore();
    final registrations =
        await MacProFeaturesService.instance.eventRegistrations();
    if (!mounted) return;
    setState(() {
      _targetScore = target;
      _registered = registrations;
    });
  }

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumNotifier>();
    if (!Platform.isMacOS || !premium.isMacPro) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kapi Note Pro')),
        body: Center(
          child: FilledButton(
            onPressed:
                () => Navigator.pushReplacementNamed(context, '/premium'),
            child: Text(
              _spanish ? 'Activar Pro en Mac' : 'Activate Pro on Mac',
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF071524),
      appBar: AppBar(
        title: const Text('Kapi Note Pro'),
        backgroundColor: const Color(0xFF710C18),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _section(
            icon: Icons.tune_rounded,
            title: _spanish ? 'Reglas de sala' : 'Room rules',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _spanish
                      ? 'Elige la meta para las salas 1 vs 1 que tú crees e invites desde tu Mac.'
                      : 'Choose the goal for 1v1 rooms you create and invite from your Mac.',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                SegmentedButton<int>(
                  segments: [
                    for (final score
                        in MacProFeaturesService.supportedTargetScores)
                      ButtonSegment(value: score, label: Text('$score pts')),
                  ],
                  selected: {_targetScore},
                  onSelectionChanged: (value) async {
                    final score = value.first;
                    await MacProFeaturesService.instance.setTargetScore(score);
                    if (mounted) setState(() => _targetScore = score);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _section(
            icon: Icons.emoji_events_rounded,
            title: _spanish ? 'Eventos Pro' : 'Pro events',
            child: Column(
              children: [
                _event(
                  id:
                      'season_${DateTime.now().year}_q${((DateTime.now().month - 1) ~/ 3) + 1}',
                  title: _spanish ? 'Copa de temporada' : 'Season Cup',
                  subtitle:
                      _spanish
                          ? 'Clasificación mensual · Block online'
                          : 'Monthly qualifier · Online Block',
                ),
                const Divider(color: Colors.white12),
                _event(
                  id: 'weekend_${DateTime.now().year}_${DateTime.now().month}',
                  title:
                      _spanish ? 'Reto Pro del mes' : 'Monthly Pro Challenge',
                  subtitle:
                      _spanish
                          ? 'Registra tu participación desde esta Mac'
                          : 'Register your participation from this Mac',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _section(
            icon: Icons.workspace_premium_rounded,
            title: _spanish ? 'Tu membresía' : 'Your membership',
            child: Text(
              premium.expiresAt == null
                  ? (_spanish ? 'Pro activo' : 'Pro active')
                  : (_spanish
                      ? 'Acceso verificado hasta ${_date(premium.expiresAt!)}'
                      : 'Access verified through ${_date(premium.expiresAt!)}'),
              style: const TextStyle(color: _gold, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _event({
    required String id,
    required String title,
    required String subtitle,
  }) {
    final active = _registered.contains(id);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Color(0xFF4D1823),
        child: Icon(Icons.sports_esports_rounded, color: _gold),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
      trailing: OutlinedButton(
        onPressed: () async {
          final registered = await MacProFeaturesService.instance
              .toggleEventRegistration(id);
          if (mounted) {
            setState(
              () => registered ? _registered.add(id) : _registered.remove(id),
            );
          }
        },
        child: Text(
          active
              ? (_spanish ? 'Registrado' : 'Registered')
              : (_spanish ? 'Participar' : 'Join'),
        ),
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF101E2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: .65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _gold),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}/${value.year}';
}
