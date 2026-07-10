import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domino_player_profile.dart';

class SimpleLobbyScreen extends StatefulWidget {
  const SimpleLobbyScreen({super.key});

  @override
  State<SimpleLobbyScreen> createState() => _SimpleLobbyScreenState();
}

class _SimpleLobbyScreenState extends State<SimpleLobbyScreen> {
  DominoPlayerProfile? _profile;
  int _points = 0;
  bool _searching = false;

  bool get _isSpanish => Localizations.localeOf(context).languageCode == 'es';

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    final profile = await DominoPlayerProfile.load();
    final prefs = await SharedPreferences.getInstance();
    final points =
        prefs.getInt('kapi_player_points_${profile.code}_total') ?? 0;
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _points = points;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final isTablet = MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6D0907), Color(0xFF071524)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 56 : 20,
                    10,
                    isTablet ? 56 : 20,
                    28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 18),
                          if (profile == null)
                            const Center(child: CircularProgressIndicator())
                          else ...[
                            _buildPlayers(profile),
                            const SizedBox(height: 18),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child:
                                  _searching
                                      ? _buildSearchingPanel()
                                      : _buildChoicePanel(profile),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: _isSpanish ? 'Volver' : 'Back',
          ),
          Expanded(
            child: Text(
              _isSpanish ? 'Lobby simple' : 'Simple Lobby',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD36B).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFFFD36B).withValues(alpha: 0.55),
              ),
            ),
            child: const Text(
              'PREVIEW',
              style: TextStyle(
                color: Color(0xFFFFD36B),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          _isSpanish ? 'Elige como jugar' : 'Choose how to play',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isSpanish ? 'Block Dominoes · 1 vs 1' : 'Block Dominoes · 1 vs 1',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.70),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayers(DominoPlayerProfile profile) {
    final tier = DominoTierVisual.fromScore(_points);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _PlayerSlot(
              icon: profile.icon,
              initials: profile.initials,
              subtitle: tier.label,
              color: tier.avatarBackground(profile.color),
              borderColor: tier.frameColor(),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'VS',
              style: TextStyle(
                color: Color(0xFFFFD36B),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: _PlayerSlot(
              icon: Icons.add_rounded,
              initials: _isSpanish ? 'Rival' : 'Rival',
              subtitle: _isSpanish ? 'Sin elegir' : 'Not selected',
              color: const Color(0xFF21181B),
              borderColor: Colors.white24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoicePanel(DominoPlayerProfile profile) {
    return Container(
      key: const ValueKey('choices'),
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LobbyChoiceButton(
            icon: Icons.travel_explore_rounded,
            title: _isSpanish ? 'Buscar jugador' : 'Find a player',
            subtitle:
                _isSpanish
                    ? 'Conectar con alguien disponible'
                    : 'Connect with someone available',
            primary: true,
            onTap: () => setState(() => _searching = true),
          ),
          const SizedBox(height: 12),
          _LobbyChoiceButton(
            icon: Icons.person_add_alt_1_rounded,
            title: _isSpanish ? 'Invitar amigo' : 'Invite a friend',
            subtitle:
                _isSpanish
                    ? 'Elegir un amigo online o compartir ID'
                    : 'Choose an online friend or share your ID',
            onTap: () => _showInviteChoices(profile),
          ),
          const SizedBox(height: 12),
          _LobbyChoiceButton(
            icon: Icons.smart_toy_rounded,
            title: _isSpanish ? 'Jugar contra CPU' : 'Play against CPU',
            subtitle:
                _isSpanish
                    ? 'Practicar sin esperar'
                    : 'Practice without waiting',
            onTap: () => Navigator.pushNamed(context, '/domino-block'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingPanel() {
    return Container(
      key: const ValueKey('searching'),
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          const SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(
              color: Color(0xFFFFD36B),
              strokeWidth: 5,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isSpanish ? 'Buscando jugador…' : 'Finding a player…',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSpanish
                ? 'Puedes cancelar cuando quieras.'
                : 'You can cancel at any time.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _searching = false),
              icon: const Icon(Icons.close_rounded),
              label: Text(_isSpanish ? 'Cancelar búsqueda' : 'Cancel search'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.42)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showInviteChoices(DominoPlayerProfile profile) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isSpanish ? 'Invitar amigo' : 'Invite a friend',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SheetAction(
                    icon: Icons.groups_rounded,
                    title:
                        _isSpanish
                            ? 'Elegir amigo online'
                            : 'Choose an online friend',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/lobby');
                    },
                  ),
                  const SizedBox(height: 10),
                  _SheetAction(
                    icon: Icons.ios_share_rounded,
                    title: _isSpanish ? 'Compartir mi ID' : 'Share my ID',
                    onTap: () async {
                      Navigator.pop(context);
                      await Share.share(
                        _isSpanish
                            ? 'Juega Block Dominoes conmigo en Kapi Note. Mi ID es ${profile.publicId.toUpperCase()}.'
                            : 'Play Block Dominoes with me in Kapi Note. My ID is ${profile.publicId.toUpperCase()}.',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: const Color(0xFF141414).withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      boxShadow: const [
        BoxShadow(color: Colors.black38, blurRadius: 18, offset: Offset(0, 10)),
      ],
    );
  }
}

class _PlayerSlot extends StatelessWidget {
  const _PlayerSlot({
    required this.icon,
    required this.initials,
    required this.subtitle,
    required this.color,
    required this.borderColor,
  });

  final IconData icon;
  final String initials;
  final String subtitle;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 8),
        Text(
          initials,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LobbyChoiceButton extends StatelessWidget {
  const _LobbyChoiceButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          primary
              ? const Color(0xFFE53935)
              : Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  primary
                      ? const Color(0xFFFFD36B).withValues(alpha: 0.72)
                      : Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(title),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.26)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
