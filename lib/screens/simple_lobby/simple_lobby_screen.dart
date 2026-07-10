import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/block_matchmaking_service.dart';
import '../../widgets/anchored_adaptive_banner_ad.dart';
import '../../widgets/app_version_label.dart';
import '../admob_variable.dart';
import '../domino_online_game_screen.dart';
import '../domino_player_profile.dart';
import 'simple_friends_screen.dart';

class SimpleLobbyScreen extends StatefulWidget {
  const SimpleLobbyScreen({super.key});

  @override
  State<SimpleLobbyScreen> createState() => _SimpleLobbyScreenState();
}

class _SimpleLobbyScreenState extends State<SimpleLobbyScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DominoPlayerProfile? _profile;
  int _points = 0;
  bool _searching = false;
  bool _openingGame = false;
  Timer? _presenceTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _matchSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _inviteSubscription;
  String? _shownInviteId;

  late final BlockMatchmakingService _matchmaking = BlockMatchmakingService(
    _db,
  );

  bool get _isSpanish => Localizations.localeOf(context).languageCode == 'es';
  String get _adUnitId =>
      defaultTargetPlatform == TargetPlatform.android
          ? AdmobVariable.bannerAndroidUnit
          : AdmobVariable.bannerIosUnit;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    unawaited(_matchSubscription?.cancel());
    unawaited(_inviteSubscription?.cancel());
    final profile = _profile;
    if (_searching && profile != null) {
      unawaited(_matchmaking.cancel(profile.publicId));
    }
    super.dispose();
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
    await _upsertPresence(profile);
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => unawaited(_upsertPresence(profile)),
    );
    _listenForInvites(profile);
    const autoMatch = bool.fromEnvironment('KAPI_AUTO_MATCH');
    if (autoMatch) unawaited(_startMatchmaking());
  }

  Future<void> _upsertPresence(DominoPlayerProfile profile) async {
    final tier = DominoTierVisual.fromScore(_points);
    final batch = _db.batch();
    batch.set(
      _db.collection('kapi_lobby_profiles').doc(profile.publicId),
      {
        'publicId': profile.publicId,
        'initials': profile.initials,
        'countryCode': profile.countryCode,
        'code': profile.code,
        'avatarKey': profile.avatarKey,
        'rank': tier.label,
        'totalPoints': _points,
        'status': 'online',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      _db.collection('kapi_lobby_codes').doc(profile.code),
      {
        'code': profile.code,
        'publicId': profile.publicId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  void _listenForInvites(DominoPlayerProfile profile) {
    _inviteSubscription = _db
        .collection('kapi_game_invites')
        .where('toId', isEqualTo: profile.publicId.toUpperCase())
        .snapshots()
        .listen((snapshot) {
          for (final doc in snapshot.docs) {
            if (doc.data()['status'] == 'pending' && doc.id != _shownInviteId) {
              _shownInviteId = doc.id;
              unawaited(_showIncomingInvite(doc));
              break;
            }
          }
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
              AnchoredAdaptiveBannerAd(
                adUnitId: _adUnitId,
                margin: EdgeInsets.zero,
              ),
              const AppVersionLabel(padding: EdgeInsets.symmetric(vertical: 5)),
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
              _isSpanish ? 'Lobby de Block' : 'Block Lobby',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 48),
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
              subtitle: '${_countryLabel(profile.countryCode)} · ${tier.label}',
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
            onTap: _startMatchmaking,
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
              onPressed: _cancelMatchmaking,
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

  Future<void> _startMatchmaking() async {
    final profile = _profile;
    if (profile == null || _searching) return;
    setState(() => _searching = true);
    await _matchSubscription?.cancel();
    _matchSubscription = _matchmaking.watch(profile.publicId).listen((doc) {
      final data = doc.data();
      if (data?['status'] == 'matched') {
        final gameId = data?['gameId'] as String?;
        if (gameId != null && gameId.isNotEmpty) {
          unawaited(_openOnlineGame(gameId));
        }
      }
    });
    try {
      await _matchmaking.start(profile: profile, points: _points);
    } catch (error) {
      if (!mounted) return;
      setState(() => _searching = false);
      _showMessage(error.toString());
    }
  }

  Future<void> _cancelMatchmaking() async {
    final profile = _profile;
    if (profile != null) await _matchmaking.cancel(profile.publicId);
    if (!mounted) return;
    setState(() => _searching = false);
  }

  Future<void> _openOnlineGame(String gameId) async {
    if (_openingGame || !mounted) return;
    _openingGame = true;
    setState(() => _searching = false);
    await Navigator.pushNamed(
      context,
      '/domino-online',
      arguments: {
        'gameId': gameId,
        'playerId': _profile!.publicId.toUpperCase(),
      },
    );
    _openingGame = false;
  }

  Future<void> _showIncomingInvite(
    QueryDocumentSnapshot<Map<String, dynamic>> invite,
  ) async {
    if (!mounted) return;
    final data = invite.data();
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(_isSpanish ? 'Invitacion para jugar' : 'Game invite'),
            content: Text(
              _isSpanish
                  ? '${data['fromInitials'] ?? 'Un amigo'} quiere jugar Block Dominoes contigo.'
                  : '${data['fromInitials'] ?? 'A friend'} wants to play Block Dominoes with you.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_isSpanish ? 'Rechazar' : 'Decline'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(_isSpanish ? 'Aceptar' : 'Accept'),
              ),
            ],
          ),
    );
    await invite.reference.set({
      'status': accepted == true ? 'accepted' : 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (accepted == true) {
      await _openOnlineGame(data['gameId'] as String);
    }
  }

  Future<String?> _resolveCode(String raw) async {
    final code = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (!RegExp(r'^[A-NP-Z1-9]{6}$').hasMatch(code)) {
      _showMessage(
        _isSpanish
            ? 'Escribe los 6 caracteres, sin cero ni letra O.'
            : 'Enter all 6 characters, without zero or the letter O.',
      );
      return null;
    }
    final doc = await _db.collection('kapi_lobby_codes').doc(code).get();
    return doc.data()?['publicId'] as String?;
  }

  Future<void> _inviteByCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(_isSpanish ? 'ID del jugador' : 'Player ID'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: const InputDecoration(hintText: 'TGHIDU'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_isSpanish ? 'Cancelar' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: Text(_isSpanish ? 'Invitar' : 'Invite'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (code == null) return;
    final playerId = await _resolveCode(code);
    if (playerId == null) {
      _showMessage(_isSpanish ? 'Jugador no encontrado.' : 'Player not found.');
      return;
    }
    await _invitePlayer(playerId);
  }

  Future<void> _invitePlayer(String playerId) async {
    final profile = _profile!;
    if (playerId.toUpperCase() == profile.publicId.toUpperCase()) return;
    final playerDoc =
        await _db.collection('kapi_lobby_profiles').doc(playerId).get();
    final initials = playerDoc.data()?['initials'] as String? ?? 'P2';
    final gameId = await OnlineGameFactory.createClassicGame(
      db: _db,
      host: profile,
      guestId: playerId,
      guestInitials: initials,
    );
    await _db.collection('kapi_game_invites').add({
      'fromId': profile.publicId.toUpperCase(),
      'toId': playerId.toUpperCase(),
      'mode': 'block',
      'status': 'pending',
      'gameId': gameId,
      'fromInitials': profile.initials,
      'toInitials': initials,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _showMessage(_isSpanish ? 'Invitacion enviada.' : 'Invite sent.');
    await _openOnlineGame(gameId);
  }

  Future<void> _openFriends() async {
    final friend = await Navigator.push<SimpleLobbyFriend>(
      context,
      MaterialPageRoute(
        builder: (_) => SimpleFriendsScreen(profile: _profile!),
      ),
    );
    if (friend != null) await _invitePlayer(friend.publicId);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _countryLabel(String code) => code == 'US' ? 'USA' : code;

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
                      unawaited(_openFriends());
                    },
                  ),
                  const SizedBox(height: 10),
                  _SheetAction(
                    icon: Icons.tag_rounded,
                    title:
                        _isSpanish
                            ? 'Entrar ID de 6 caracteres'
                            : 'Enter 6-character ID',
                    onTap: () {
                      Navigator.pop(context);
                      unawaited(_inviteByCode());
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
                            ? 'Juega Block Dominoes conmigo en Kapi Note. Mi ID es ${profile.code.toUpperCase()}.'
                            : 'Play Block Dominoes with me in Kapi Note. My ID is ${profile.code.toUpperCase()}.',
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
