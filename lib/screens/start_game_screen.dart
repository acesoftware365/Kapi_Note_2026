// lib/screens/start_game_screen.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../premium_notifier.dart';
import '../services/analytics_service.dart';
import '../services/player_account_service.dart';
import 'player_account_screen.dart';
import '../widgets/anchored_adaptive_banner_ad.dart';
import 'admob_variable.dart';
import 'domino_player_profile.dart';

class StartGameScreen extends StatefulWidget {
  const StartGameScreen({super.key});

  @override
  State<StartGameScreen> createState() => _StartGameScreenState();
}

class _StartGameScreenState extends State<StartGameScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _playerCodeController = TextEditingController();
  final Random _random = Random();
  GameMode _selectedMode = GameMode.block;
  String _selectedCountryCode = 'US';
  String _selectedAvatarKey = 'person';
  bool _didSetDefaultCountry = false;
  bool _didReadRouteArgs = false;
  bool _resumeGameAvailable = false;
  bool _hasSavedProfile = false;
  bool _hasUsedFreeProfileEdit = false;
  bool _isSavingProfile = false;
  bool _isLoadingRewardedAd = false;
  bool _isPreloadingRewardedAd = false;
  RewardedAd? _rewardedAd;

  static const String _profileInitialsKey = 'kapi_player_profile_initials';
  static const String _profileCodeKey = 'kapi_player_profile_code';
  static const String _profileCountryKey = 'kapi_player_profile_country';
  static const String _profileAvatarKey = 'kapi_player_profile_avatar';
  static const String _profileSavedKey = 'kapi_player_profile_saved';
  static const String _profileFreeEditUsedKey =
      'kapi_player_profile_free_edit_used';

  static const List<_CountryOption> _countryOptions = [
    _CountryOption('US', 'United States', 'Estados Unidos'),
    _CountryOption('DR', 'Dominican Republic', 'Republica Dominicana'),
    _CountryOption('PR', 'Puerto Rico', 'Puerto Rico'),
    _CountryOption('MX', 'Mexico', 'Mexico'),
    _CountryOption('CO', 'Colombia', 'Colombia'),
    _CountryOption('VE', 'Venezuela', 'Venezuela'),
    _CountryOption('ES', 'Spain', 'Espana'),
    _CountryOption('CA', 'Canada', 'Canada'),
    _CountryOption('AR', 'Argentina', 'Argentina'),
    _CountryOption('CL', 'Chile', 'Chile'),
    _CountryOption('PE', 'Peru', 'Peru'),
    _CountryOption('EC', 'Ecuador', 'Ecuador'),
    _CountryOption('PA', 'Panama', 'Panama'),
    _CountryOption('CR', 'Costa Rica', 'Costa Rica'),
    _CountryOption('GT', 'Guatemala', 'Guatemala'),
    _CountryOption('HN', 'Honduras', 'Honduras'),
    _CountryOption('SV', 'El Salvador', 'El Salvador'),
    _CountryOption('NI', 'Nicaragua', 'Nicaragua'),
    _CountryOption('CU', 'Cuba', 'Cuba'),
    _CountryOption('BR', 'Brazil', 'Brasil'),
    _CountryOption('UY', 'Uruguay', 'Uruguay'),
    _CountryOption('PY', 'Paraguay', 'Paraguay'),
    _CountryOption('BO', 'Bolivia', 'Bolivia'),
    _CountryOption('IT', 'Italy', 'Italia'),
    _CountryOption('FR', 'France', 'Francia'),
    _CountryOption('DE', 'Germany', 'Alemania'),
    _CountryOption('GB', 'United Kingdom', 'Reino Unido'),
    _CountryOption('AU', 'Australia', 'Australia'),
  ];

  bool get _isSpanish => Localizations.localeOf(context).languageCode == 'es';

  String get _playerInitials {
    final initials = _nameController.text.trim().toUpperCase();
    return initials.length == 2 ? initials : '--';
  }

  String get _publicPlayerId =>
      _hasSavedProfile
          ? 'ID: $_playerInitials.$_selectedCountryCode.${_playerCodeController.text}'
          : (_isSpanish ? 'Crea tu perfil' : 'Create profile');

  String get _analyticsGameMode => switch (_selectedMode) {
    GameMode.block => 'block',
    GameMode.draw => 'draw_pool',
    GameMode.allFives => 'all_fives',
    GameMode.teams => 'teams_2v2_cpu',
  };

  String get _selectedModeTitle {
    switch (_selectedMode) {
      case GameMode.block:
        return 'Block';
      case GameMode.draw:
        return _isSpanish ? 'Draw / Pozo' : 'Draw / Pool';
      case GameMode.allFives:
        return 'All Fives';
      case GameMode.teams:
        return 'Teams 2 vs 2';
    }
  }

  String get _selectedModeHelpButtonText =>
      _isSpanish
          ? 'Cómo jugar $_selectedModeTitle'
          : 'How to play $_selectedModeTitle';

  DominoPlayerProfile get _selectedAvatarProfile => DominoPlayerProfile(
    initials: _playerInitials,
    countryCode: _selectedCountryCode,
    code: _playerCodeController.text,
    avatarKey: _selectedAvatarKey,
  );

  String get _adUnitId =>
      defaultTargetPlatform == TargetPlatform.android
          ? AdmobVariable.bannerAndroidUnit
          : AdmobVariable.bannerIosUnit;

  @override
  void initState() {
    super.initState();
    _nameController.text = '';
    _generatePlayerCode();
    _loadSavedProfile();
    _preloadRewardedAd();
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _nameController.dispose();
    _playerCodeController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didReadRouteArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['resumeClassicGame'] == true) {
        _resumeGameAvailable = true;
        _selectedMode = GameMode.block;
      }
      _didReadRouteArgs = true;
    }
    if (_didSetDefaultCountry || _hasSavedProfile) return;
    final deviceCountry = Localizations.localeOf(context).countryCode;
    if (deviceCountry != null &&
        _countryOptions.any((country) => country.code == deviceCountry)) {
      _selectedCountryCode = deviceCountry;
    }
    _didSetDefaultCountry = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: _buildPlayerIdText(),
        leading: IconButton(
          icon: const Icon(Icons.home_rounded, color: Colors.white),
          color: Colors.white,
          style: IconButton.styleFrom(foregroundColor: Colors.white),
          tooltip: _isSpanish ? 'Inicio' : 'Home',
          onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              icon: const Icon(Icons.settings_rounded),
              tooltip: _isSpanish ? 'Configuracion' : 'Settings',
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/image/background.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Color(0xAA000000),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xAA4B0706), Color(0xDD071524)],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isTablet = constraints.maxWidth >= 720;
                      final isCompact =
                          !isTablet && constraints.maxHeight < 720;
                      return Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 48 : 20,
                            vertical: isCompact ? 8 : 18,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isTablet ? 720 : double.infinity,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeader(isTablet, isCompact),
                                SizedBox(
                                  height: isTablet ? 28 : (isCompact ? 8 : 14),
                                ),
                                _buildSetupPanel(isTablet, isCompact),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                  child: _buildContinueButton(isTablet: false),
                ),
                AnchoredAdaptiveBannerAd(
                  adUnitId: _adUnitId,
                  margin: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isTablet, bool isCompact) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _isSpanish ? 'Modo de juego' : 'Game Mode',
            textAlign: TextAlign.left,
            style: TextStyle(
              color: Colors.white,
              fontSize: isTablet ? 46 : (isCompact ? 25 : 30),
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: 0,
              shadows: const [
                Shadow(
                  blurRadius: 18,
                  color: Colors.black54,
                  offset: Offset(0, 8),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton.outlined(
          onPressed: () => Navigator.pushNamed(context, '/ranking'),
          tooltip: _isSpanish ? 'Ranking de puntos' : 'Points Ranking',
          icon: const Icon(Icons.leaderboard_rounded),
          color: Colors.white,
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.22),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
          ),
        ),
      ],
    );
  }

  Widget _buildSetupPanel(bool isTablet, bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 22 : (isCompact ? 10 : 14)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileButton(isTablet, compact: isCompact),
          SizedBox(height: isCompact ? 8 : 12),
          _buildModeCard(
            mode: GameMode.block,
            icon: Icons.view_module_rounded,
            title: 'Block',
            subtitle: _isSpanish ? 'Bloqueo sin pozo' : 'Block without draw',
            isTablet: isTablet,
            compact: isCompact,
          ),
          SizedBox(height: isCompact ? 6 : 8),
          _buildModeCard(
            mode: GameMode.teams,
            icon: Icons.groups_2_rounded,
            title: 'Teams 2 vs 2',
            subtitle:
                _isSpanish
                    ? 'Tú y un compañero contra dos CPU'
                    : 'You and a partner against two CPUs',
            isTablet: isTablet,
            compact: isCompact,
          ),
          SizedBox(height: isCompact ? 8 : 12),
          _buildHowToPlayCard(isTablet, compact: isCompact),
          SizedBox(height: isCompact ? 6 : 8),
          _buildModeCard(
            mode: GameMode.allFives,
            icon: Icons.filter_5_rounded,
            title: 'All Fives',
            subtitle: _isSpanish ? 'Próximamente' : 'Coming soon',
            isTablet: isTablet,
            compact: isCompact,
          ),
          SizedBox(height: isCompact ? 6 : 8),
          _buildModeCard(
            mode: GameMode.draw,
            icon: Icons.inventory_2_rounded,
            title: _isSpanish ? 'Robo / Pozo' : 'Draw / Pool',
            subtitle: _isSpanish ? 'Próximamente' : 'Coming soon',
            isTablet: isTablet,
            compact: isCompact,
          ),
        ],
      ),
    );
  }

  Widget _buildHowToPlayCard(bool isTablet, {required bool compact}) {
    return InkWell(
      onTap: _showSelectedModeHowToPlay,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 18 : 14,
          vertical: isTablet ? 15 : (compact ? 8 : 10),
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF142A32).withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.help_rounded,
              color: Colors.white,
              size: isTablet ? 29 : (compact ? 22 : 25),
            ),
            SizedBox(width: isTablet ? 16 : 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedModeHelpButtonText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 16 : (compact ? 12 : 14),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _isSpanish ? 'Aprende las reglas' : 'Learn the rules',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.66),
                      fontSize: isTablet ? 12 : (compact ? 9 : 11),
                      fontWeight: FontWeight.w700,
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

  Widget _buildContinueButton({required bool isTablet}) {
    return SizedBox(
      width: double.infinity,
      height: isTablet ? 72 : 52,
      child: FilledButton.icon(
        onPressed: _continueToGame,
        icon: Icon(Icons.play_arrow_rounded, size: isTablet ? 32 : 25),
        label: Text(
          _resumeGameAvailable && _selectedMode == GameMode.block
              ? (_isSpanish ? 'Continuar partida' : 'Resume game')
              : (_isSpanish ? 'Continuar' : 'Continue'),
          style: TextStyle(
            fontSize: isTablet ? 22 : 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFE53935),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String hint,
    required bool isTablet,
    String? helperText,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: isTablet ? 19 : 16,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.9)),
        labelText: label,
        hintText: hint,
        helperText: helperText,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
        helperStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.58),
          fontWeight: FontWeight.w600,
        ),
        suffixIcon: suffixIcon,
        suffixIconColor: Colors.white.withValues(alpha: 0.9),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.24),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFFD36B), width: 1.4),
        ),
      ),
    );
  }

  Widget _buildPlayerIdText() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.verified_rounded,
            color: Color(0xFF7CFF9B),
            size: 16,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _publicPlayerId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileButton(bool isTablet, {bool compact = false}) {
    final country = _countryOptions.firstWhere(
      (option) => option.code == _selectedCountryCode,
      orElse: () => _countryOptions.first,
    );
    final countryName = _isSpanish ? country.spanishName : country.englishName;
    final tierVisual = DominoTierVisual.fromScore(0, ranked: _hasSavedProfile);
    final avatarProfile = _selectedAvatarProfile;
    final avatarColor =
        _hasSavedProfile
            ? tierVisual.avatarBackground(avatarProfile.color)
            : avatarProfile.color;

    return InkWell(
      onTap:
          () => _showProfileEditor(requiredInitialProfile: !_hasSavedProfile),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.all(isTablet ? 18 : (compact ? 9 : 12)),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                _hasSavedProfile
                    ? tierVisual.frameColor()
                    : Colors.white.withValues(alpha: 0.18),
          ),
          boxShadow:
              _hasSavedProfile && tierVisual.shadows().isNotEmpty
                  ? tierVisual.shadows()
                  : null,
        ),
        child: Row(
          children: [
            Container(
              width: isTablet ? 54 : (compact ? 40 : 46),
              height: isTablet ? 54 : (compact ? 40 : 46),
              decoration: BoxDecoration(
                gradient:
                    _hasSavedProfile
                        ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [tierVisual.accent, avatarColor],
                        )
                        : null,
                color: _hasSavedProfile ? null : avatarColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      _hasSavedProfile
                          ? tierVisual.frameColor()
                          : const Color(0xFFFFD36B),
                  width: _hasSavedProfile ? 1.4 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: DominoAvatarVisual(
                avatarKey: _selectedAvatarKey,
                fallbackIcon: avatarProfile.icon,
                backgroundColor: avatarColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hasSavedProfile
                        ? (_isSpanish ? 'Editar perfil' : 'Edit Profile')
                        : (_isSpanish ? 'Crear perfil' : 'Create Profile'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 18 : 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _hasSavedProfile
                        ? '$_playerInitials · $_selectedCountryCode · $countryName'
                        : (_isSpanish
                            ? 'Requerido antes de jugar'
                            : 'Required before playing'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: isTablet ? 13 : 11,
                      fontWeight: FontWeight.w700,
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

  Future<void> _preloadRewardedAd() async {
    if (kIsWeb || _rewardedAd != null || _isPreloadingRewardedAd) return;
    if (context.read<PremiumNotifier>().isPremium) return;

    _isPreloadingRewardedAd = true;
    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd?.dispose();
          _rewardedAd = ad;
          _isPreloadingRewardedAd = false;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isPreloadingRewardedAd = false;
        },
      ),
    );
  }

  Future<RewardedAd?> _loadRewardedAdNow() async {
    if (kIsWeb) return null;
    if (_rewardedAd != null) return _rewardedAd;

    final completer = Completer<RewardedAd?>();
    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd?.dispose();
          _rewardedAd = ad;
          completer.complete(ad);
        },
        onAdFailedToLoad: (_) {
          _rewardedAd = null;
          completer.complete(null);
        },
      ),
    );
    return completer.future;
  }

  Future<bool> _showLoadedRewardedAd(RewardedAd ad) {
    final completer = Completer<bool>();
    var rewarded = false;
    _rewardedAd = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(_preloadRewardedAd());
        if (!completer.isCompleted) completer.complete(rewarded);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        unawaited(_preloadRewardedAd());
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    ad.show(
      onUserEarnedReward: (_, __) {
        rewarded = true;
      },
    );
    return completer.future;
  }

  Future<void> _loadSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final savedInitials = prefs.getString(_profileInitialsKey);
    final savedCode = prefs.getString(_profileCodeKey);
    final savedCountry = prefs.getString(_profileCountryKey);
    final savedAvatar = prefs.getString(_profileAvatarKey);

    if (!mounted) return;
    setState(() {
      _hasSavedProfile = prefs.getBool(_profileSavedKey) ?? false;
      _hasUsedFreeProfileEdit = prefs.getBool(_profileFreeEditUsedKey) ?? false;

      if (savedInitials != null && savedInitials.length == 2) {
        _nameController.text = savedInitials;
      }
      if (savedCode != null && _isValidPlayerCode(savedCode)) {
        _playerCodeController.text = savedCode;
      } else if (savedCode != null && savedCode.isNotEmpty) {
        final newCode = _generatePlayerCodeValue();
        _playerCodeController.text = newCode;
        unawaited(prefs.setString(_profileCodeKey, newCode));
      } else {
        final newCode =
            _isValidPlayerCode(_playerCodeController.text)
                ? _playerCodeController.text
                : _generatePlayerCodeValue();
        _playerCodeController.text = newCode;
        unawaited(prefs.setString(_profileCodeKey, newCode));
      }
      if (savedCountry != null &&
          _countryOptions.any((country) => country.code == savedCountry)) {
        _selectedCountryCode = savedCountry;
      }
      if (savedAvatar != null && savedAvatar.trim().isNotEmpty) {
        _selectedAvatarKey = savedAvatar;
      }
    });

    if (!(prefs.getBool(_profileSavedKey) ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showProfileEditor(requiredInitialProfile: true);
      });
    }
  }

  String _cleanInitials(String value) {
    final lettersOnly = value.trim().toUpperCase().replaceAll(
      RegExp('[^A-Z]'),
      '',
    );
    if (lettersOnly.length >= 2) {
      return lettersOnly.substring(0, 2);
    }
    return lettersOnly;
  }

  bool _profileChanged({
    required String initials,
    required String countryCode,
  }) {
    return _cleanInitials(initials) != _playerInitials ||
        countryCode != _selectedCountryCode;
  }

  Future<void> _saveProfileFromEditor({
    required BuildContext sheetContext,
    required String initials,
    required String countryCode,
  }) async {
    if (_isSavingProfile) return;

    final cleanedInitials = initials.trim().toUpperCase();
    if (cleanedInitials.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSpanish
                ? 'Usa exactamente 2 letras para tus iniciales.'
                : 'Use exactly 2 letters for your initials.',
          ),
        ),
      );
      return;
    }

    final changed = _profileChanged(
      initials: cleanedInitials,
      countryCode: countryCode,
    );
    if (!changed && _hasSavedProfile) {
      Navigator.pop(sheetContext);
      return;
    }

    final premiumNotifier = context.read<PremiumNotifier>();
    final wasFirstProfile = !_hasSavedProfile;
    final canSaveNow =
        premiumNotifier.isPremium ||
        !_hasSavedProfile ||
        !_hasUsedFreeProfileEdit;

    if (!canSaveNow) {
      final allowedByReward = await _showProfileEditGate();
      if (!allowedByReward) return;
    }

    setState(() => _isSavingProfile = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileInitialsKey, cleanedInitials);
    await prefs.setString(_profileCountryKey, countryCode);
    await prefs.setString(_profileCodeKey, _playerCodeController.text);
    await prefs.setBool(_profileSavedKey, true);
    if (!premiumNotifier.isPremium) {
      await prefs.setBool(_profileFreeEditUsedKey, true);
    }
    await PlayerAccountService.instance.syncCurrentProfile();

    if (!mounted) return;
    unawaited(
      AnalyticsService.logDominoProfileSaved(
        countryCode: countryCode,
        avatarKey: _selectedAvatarKey,
        gameMode: _analyticsGameMode,
        isFirstProfile: wasFirstProfile,
        isPremium: premiumNotifier.isPremium,
      ),
    );
    setState(() {
      _nameController.text = cleanedInitials;
      _selectedCountryCode = countryCode;
      _hasSavedProfile = true;
      _hasUsedFreeProfileEdit =
          premiumNotifier.isPremium ? _hasUsedFreeProfileEdit : true;
      _isSavingProfile = false;
    });

    if (sheetContext.mounted) {
      Navigator.pop(sheetContext);
    }
  }

  Future<bool> _showProfileEditGate() async {
    final decision = await showDialog<_ProfileEditDecision>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101820),
          title: Text(
            _isSpanish ? 'Editar perfil' : 'Edit profile',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            _isSpanish
                ? 'Ya usaste tu cambio gratis. Puedes ver un anuncio para guardar este cambio o activar Pro.'
                : 'You already used your free profile change. Watch a rewarded ad to save this change or upgrade to Pro.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.84)),
          ),
          actions: [
            TextButton(
              onPressed:
                  () => Navigator.pop(context, _ProfileEditDecision.cancel),
              child: Text(_isSpanish ? 'Cancelar' : 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _ProfileEditDecision.pro),
              child: const Text('Pro'),
            ),
            FilledButton(
              onPressed:
                  _isLoadingRewardedAd
                      ? null
                      : () => Navigator.pop(
                        context,
                        _ProfileEditDecision.rewardedAd,
                      ),
              child: Text(_isSpanish ? 'Ver anuncio' : 'Watch ad'),
            ),
          ],
        );
      },
    );

    switch (decision) {
      case _ProfileEditDecision.rewardedAd:
        return _showRewardedAdForProfileEdit();
      case _ProfileEditDecision.pro:
        if (mounted) {
          Navigator.pushNamed(context, '/premium');
        }
        return false;
      case _ProfileEditDecision.cancel:
      case null:
        return false;
    }
  }

  Future<bool> _showRewardedAdForProfileEdit() async {
    if (kIsWeb) return false;
    if (context.read<PremiumNotifier>().isPremium) return true;

    setState(() => _isLoadingRewardedAd = true);
    final ad = await _loadRewardedAdNow();
    final allowed = ad != null && await _showLoadedRewardedAd(ad);
    if (!mounted) return false;
    setState(() => _isLoadingRewardedAd = false);

    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSpanish
                ? 'No se pudo completar el anuncio. Intenta otra vez o usa Pro.'
                : 'The ad could not be completed. Try again or use Pro.',
          ),
        ),
      );
    }
    return allowed;
  }

  String get _rewardedAdUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AdmobVariable.rewardedAndroidUnit;
      case TargetPlatform.iOS:
        return AdmobVariable.rewardedIosUnit;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return AdmobVariable.rewardedIosUnit;
    }
  }

  void _showProfileEditor({bool requiredInitialProfile = false}) {
    final tempInitialsController = TextEditingController(
      text: _hasSavedProfile ? _playerInitials : '',
    );
    String tempCountryCode = _selectedCountryCode;
    final tempPlayerCode = _playerCodeController.text;

    String tempPublicPlayerId() {
      final initials = _cleanInitials(tempInitialsController.text);
      if (initials.length != 2) {
        return _isSpanish
            ? 'ID se completa con tus iniciales'
            : 'ID completes with your initials';
      }
      return 'ID: $initials.$tempCountryCode.$tempPlayerCode';
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: !requiredInitialProfile,
      enableDrag: !requiredInitialProfile,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final account = PlayerAccountService.instance;
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xEE101820),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFFD36B)),
                ),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.72,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          Text(
                            requiredInitialProfile
                                ? (_isSpanish
                                    ? 'Crea tu perfil para jugar'
                                    : 'Create your profile to play')
                                : (_isSpanish
                                    ? 'Crear perfil'
                                    : 'Create Profile'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tempPublicPlayerId(),
                            style: const TextStyle(
                              color: Color(0xFFFFD36B),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: tempInitialsController,
                            icon: Icons.person_rounded,
                            label: _isSpanish ? 'Iniciales' : 'Initials',
                            hint: _isSpanish ? 'Ej. JP' : 'Ex. JP',
                            helperText:
                                _isSpanish
                                    ? 'Solo 2 letras para mostrar a otros jugadores.'
                                    : 'Only 2 letters shown to other players.',
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp('[a-zA-Z]'),
                              ),
                              LengthLimitingTextInputFormatter(2),
                              UpperCaseTextFormatter(),
                            ],
                            onChanged: (_) => setSheetState(() {}),
                            isTablet: false,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _isSpanish ? 'Pais del jugador' : 'Player country',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: tempCountryCode,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF17222D),
                            iconEnabledColor: const Color(0xFFFFD36B),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.public_rounded,
                                color: Color(0xFF67B7FF),
                              ),
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                              ),
                            ),
                            items: _countryOptions
                                .map((country) {
                                  final name =
                                      _isSpanish
                                          ? country.spanishName
                                          : country.englishName;
                                  return DropdownMenuItem<String>(
                                    value: country.code,
                                    child: Text(
                                      '${country.code} - $name',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  );
                                })
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) return;
                              setSheetState(() => tempCountryCode = value);
                            },
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color:
                                  account.isProtected
                                      ? const Color(0xFF123329)
                                      : const Color(0xFF172A3B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    account.canPurchaseCoins
                                        ? const Color(0xFF55D98A)
                                        : const Color(0xFFFFD36B),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  account.canPurchaseCoins
                                      ? Icons.cloud_done_rounded
                                      : Icons.account_balance_wallet_rounded,
                                  color:
                                      account.canPurchaseCoins
                                          ? const Color(0xFF7CFF9B)
                                          : const Color(0xFFFFD36B),
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        account.isProtected
                                            ? (_isSpanish
                                                ? 'Cuenta Kapi protegida'
                                                : 'Protected Kapi account')
                                            : (_isSpanish
                                                ? 'Guarda tus Kapi Coins y ranking'
                                                : 'Save your Kapi Coins and ranking'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        account.isProtected
                                            ? (account.accountEmail ??
                                                account.providerLabel ??
                                                'Kapi')
                                            : (_isSpanish
                                                ? 'Regístrate para protegerlos y comprar.'
                                                : 'Register to protect them and buy.'),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFFCCD2D9),
                                          fontSize: 12,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip:
                                      _isSpanish
                                          ? 'Administrar cuenta'
                                          : 'Manage account',
                                  onPressed: () async {
                                    await Navigator.push<void>(
                                      this.context,
                                      MaterialPageRoute<void>(
                                        settings: const RouteSettings(
                                          name: '/player-account',
                                        ),
                                        builder:
                                            (_) => const PlayerAccountScreen(),
                                      ),
                                    );
                                    if (context.mounted) {
                                      setSheetState(() {});
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnchoredAdaptiveBannerAd(adUnitId: _adUnitId),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          _saveProfileFromEditor(
                            sheetContext: context,
                            initials: tempInitialsController.text,
                            countryCode: tempCountryCode,
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _isSpanish ? 'Guardar perfil' : 'Save Profile',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    if (requiredInitialProfile) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await Navigator.push(
                            this.context,
                            MaterialPageRoute<void>(
                              settings: const RouteSettings(
                                name: '/player-account-recovery',
                              ),
                              builder:
                                  (_) => const PlayerAccountScreen(
                                    recoverOnly: true,
                                  ),
                            ),
                          );
                          if (mounted) await _loadSavedProfile();
                        },
                        icon: const Icon(Icons.restore_rounded),
                        label: Text(
                          _isSpanish
                              ? 'Recuperar perfil existente'
                              : 'Recover existing profile',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFFD36B),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(tempInitialsController.dispose);
  }

  Widget _buildModeCard({
    required GameMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isTablet,
    required bool compact,
  }) {
    final selected = _selectedMode == mode;
    final isComingSoon = mode != GameMode.block && mode != GameMode.teams;
    return InkWell(
      onTap: () => setState(() => _selectedMode = mode),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 18 : 14,
          vertical: isTablet ? 18 : (compact ? 8 : 11),
        ),
        decoration: BoxDecoration(
          color:
              selected
                  ? const Color(0xFF53647B).withValues(alpha: 0.94)
                  : isComingSoon
                  ? const Color(0xFF343942).withValues(alpha: 0.82)
                  : Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                selected
                    ? const Color(0xFFC7D8FF)
                    : isComingSoon
                    ? const Color(0xFF8A8F99).withValues(alpha: 0.58)
                    : Colors.white.withValues(alpha: 0.18),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isComingSoon ? const Color(0xFFA8ABB2) : Colors.white,
              size: isTablet ? 34 : (compact ? 24 : 27),
            ),
            SizedBox(width: isTablet ? 18 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          isComingSoon ? const Color(0xFFA8ABB2) : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: isTablet ? 18 : 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isComingSoon
                        ? (_isSpanish ? 'Proximamente' : 'Coming soon')
                        : subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          isComingSoon
                              ? const Color(0xFFA8ABB2)
                              : Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w600,
                      fontSize: isTablet ? 13 : 11,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: isTablet ? 28 : 23,
              )
            else if (isComingSoon)
              Icon(
                Icons.lock_rounded,
                color: const Color(0xFFA8ABB2),
                size: isTablet ? 23 : 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showModeComingSoon() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _selectedMode == GameMode.allFives
                      ? Icons.filter_5_rounded
                      : Icons.inventory_2_rounded,
                  color: Color(0xFFFFD36B),
                  size: 44,
                ),
                const SizedBox(height: 14),
                Text(
                  _selectedModeTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSpanish
                      ? 'Este modo viene pronto. Por ahora puedes probar Block beta.'
                      : 'This mode is coming soon. For now, you can test Block beta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _isSpanish ? 'Entendido' : 'Got it',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSelectedModeHowToPlay() {
    final pages = _selectedModeHelpPages;
    var page = 0;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(18),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF421719),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFFFD36B),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton.filled(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF101820),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: const Color(
                              0xFFFFD36B,
                            ).withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      _selectedModeTitle.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                            offset: Offset(1, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _buildHowToPlayPage(
                        pages[page],
                        key: ValueKey('${_selectedMode.name}-$page'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        pages.length,
                        (index) => Container(
                          width: index == page ? 18 : 9,
                          height: 9,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color:
                                index == page
                                    ? const Color(0xFFFFD36B)
                                    : Colors.white.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                page == 0
                                    ? null
                                    : () => setSheetState(() => page--),
                            icon: const Icon(Icons.chevron_left_rounded),
                            label: Text(_isSpanish ? 'Atras' : 'Back'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white38,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              if (page == pages.length - 1) {
                                Navigator.pop(context);
                              } else {
                                setSheetState(() => page++);
                              }
                            },
                            icon: Icon(
                              page == pages.length - 1
                                  ? Icons.check_rounded
                                  : Icons.chevron_right_rounded,
                            ),
                            label: Text(
                              page == pages.length - 1
                                  ? (_isSpanish ? 'Entendido' : 'Got it')
                                  : (_isSpanish ? 'Siguiente' : 'Next'),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<_HowToPlayPage> get _selectedModeHelpPages {
    switch (_selectedMode) {
      case GameMode.teams:
        return [
          _HowToPlayPage(
            icon: Icons.groups_2_rounded,
            title: 'Teams 2 vs 2',
            body:
                _isSpanish
                    ? 'Cuatro jugadores, siete fichas cada uno. Tú y tu compañero juegan en posiciones opuestas.'
                    : 'Four players with seven tiles each. You and your partner sit opposite each other.',
          ),
          _HowToPlayPage(
            icon: Icons.looks_6_rounded,
            title: 'Double-6',
            body:
                _isSpanish
                    ? 'La primera mano sale con el doble más alto. Después sale solamente quien dominó la mano anterior.'
                    : 'The first hand opens with the highest double. Later, only the previous dominator opens.',
          ),
          _HowToPlayPage(
            icon: Icons.calculate_rounded,
            title: _isSpanish ? 'Tranca y puntos' : 'Block and scoring',
            body:
                _isSpanish
                    ? 'Quien tranca se compara solamente con el jugador que le sigue. Gana quien tenga menos puntos entre esos dos y su equipo recibe todos los puntos no jugados. El pase redondo vale 10.'
                    : 'The blocker competes only with the next player. The lower total between those two wins, and their team scores every unplayed pip. A round pass is worth 10.',
          ),
        ];
      case GameMode.block:
        return [
          _HowToPlayPage(
            icon: Icons.view_module_rounded,
            title: 'Block Dominoes',
            body:
                _isSpanish
                    ? 'Juega hasta que un jugador se quede sin fichas o hasta que ambos jugadores esten bloqueados.'
                    : 'Play until one player has no tiles left or until both players are blocked.',
          ),
          _HowToPlayPage(
            icon: Icons.do_not_disturb_on_total_silence_rounded,
            title: _isSpanish ? 'Sin pozo' : 'No draw pile',
            body:
                _isSpanish
                    ? 'En Block no se toman fichas del pozo. Si no tienes jugada valida, pasas.'
                    : 'In Block, players do not draw from the boneyard. If you have no valid move, you pass.',
          ),
          _HowToPlayPage(
            icon: Icons.calculate_rounded,
            title: _isSpanish ? 'Puntos al final' : 'End round points',
            body:
                _isSpanish
                    ? 'Al terminar la ronda, las fichas restantes cuentan. Si hay tranque y ambos tienen los mismos puntos, gana quien hizo el tranque.'
                    : 'At the end of the round, remaining tiles count. If the round is blocked and points are tied, the player who blocked wins.',
          ),
        ];
      case GameMode.draw:
        return [
          _HowToPlayPage(
            icon: Icons.sports_esports_rounded,
            title: _isSpanish ? 'Objetivo' : 'Round objective',
            body:
                _isSpanish
                    ? 'Juega hasta que un jugador se quede sin fichas o hasta que ambos jugadores esten bloqueados.'
                    : 'Play until one player has no dominoes left or until both players are blocked.',
          ),
          _HowToPlayPage(
            icon: Icons.inventory_2_rounded,
            title: _isSpanish ? 'Tomar del pozo' : 'Draw from the boneyard',
            body:
                _isSpanish
                    ? 'Si no tienes jugada valida, tomas fichas del pozo hasta encontrar una que puedas jugar.'
                    : 'If you are blocked, draw from the boneyard until you get a playable domino.',
          ),
          _HowToPlayPage(
            icon: Icons.vertical_align_center_rounded,
            title: _isSpanish ? 'Dobles' : 'Doubles',
            body:
                _isSpanish
                    ? 'Las fichas dobles solo conectan con otras dos fichas: una en cada extremo abierto.'
                    : 'Double dominoes can only connect to two other dominoes, one on each open end.',
          ),
          _HowToPlayPage(
            icon: Icons.calculate_rounded,
            title: _isSpanish ? 'Puntos al final' : 'End round points',
            body:
                _isSpanish
                    ? 'Al terminar la ronda, se cuentan los puntos de las fichas restantes. Las fichas del oponente se suman a tu puntuacion y tus fichas restantes se suman a la puntuacion del oponente.'
                    : "At the end of the round, remaining domino points are counted. Your opponent's remaining points are added to your score, and your remaining points are added to your opponent's score.",
          ),
        ];
      case GameMode.allFives:
        return [
          _HowToPlayPage(
            icon: Icons.filter_5_rounded,
            title: _isSpanish ? 'Puntos por 5' : 'Score by 5s',
            body:
                _isSpanish
                    ? 'Cuando juegas una ficha, se suman las puntas abiertas del tablero. Si el total es multiplo de 5, como 5, 10 o 15, ganas esos puntos.'
                    : "When you play a domino, the board's open ends are added. If the total is a multiple of 5, like 5, 10, or 15, you score those points.",
          ),
          _HowToPlayPage(
            icon: Icons.inventory_2_rounded,
            title: _isSpanish ? 'Pozo' : 'Boneyard',
            body:
                _isSpanish
                    ? 'Si estas bloqueado, tomas fichas del pozo hasta encontrar una ficha que puedas jugar.'
                    : "If you're blocked, draw from the boneyard until you get a playable domino.",
          ),
          _HowToPlayPage(
            icon: Icons.hub_rounded,
            title: 'Spinner',
            body:
                _isSpanish
                    ? 'El primer doble puede conectar desde cuatro lados. Eso abre mas caminos para jugar.'
                    : 'The first double domino can connect from four sides, opening more ways to play.',
          ),
          _HowToPlayPage(
            icon: Icons.calculate_rounded,
            title: _isSpanish ? 'Final de ronda' : 'End round points',
            body:
                _isSpanish
                    ? 'Al terminar la ronda, se cuentan los puntos de las fichas restantes. Las fichas del oponente se suman a tu puntuacion y tus fichas restantes se suman a la puntuacion del oponente.'
                    : "At the end of the round, remaining domino points are counted. Your opponent's remaining points are added to your score, and your remaining points are added to your opponent's score.",
          ),
        ];
    }
  }

  Widget _buildHowToPlayPage(_HowToPlayPage page, {required Key key}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF101820),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFD36B).withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        children: [
          Icon(page.icon, color: const Color(0xFFFFD36B), size: 58),
          const SizedBox(height: 16),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _continueToGame() async {
    if (!_hasSavedProfile) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSpanish
                ? 'Primero crea tu perfil para poder jugar.'
                : 'Create your profile before playing.',
          ),
        ),
      );
      _showProfileEditor(requiredInitialProfile: true);
      return;
    }

    final name = _nameController.text.trim().toUpperCase();
    if (name.length != 2 || _playerCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSpanish
                ? 'Agrega 2 letras para tus iniciales.'
                : 'Add 2 letters for your initials.',
          ),
        ),
      );
      return;
    }

    if (_resumeGameAvailable && _selectedMode == GameMode.block) {
      Navigator.pop(context);
      return;
    }

    if (_resumeGameAvailable && _selectedMode != GameMode.block) {
      final reset = await _confirmResetPausedGame();
      if (!mounted) return;
      if (!reset) return;
      _resumeGameAvailable = false;
    }

    if (_selectedMode == GameMode.teams) {
      if (!mounted) return;
      Navigator.pushNamed(context, '/domino-teams-online-lobby');
      return;
    }

    if (_selectedMode != GameMode.block) {
      _showModeComingSoon();
      return;
    }

    if (!mounted) return;
    Navigator.pushNamed(context, '/simple-lobby');
  }

  Future<bool> _confirmResetPausedGame() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF101820),
            title: Text(
              _isSpanish ? 'Resetear partida?' : 'Reset match?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Text(
              _isSpanish
                  ? 'Tienes una partida Block en progreso. Si cambias de modo, esa partida se va a cerrar.'
                  : 'You have a Block match in progress. Changing modes will close that match.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_isSpanish ? 'Cancelar' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                ),
                child: Text(_isSpanish ? 'Resetear' : 'Reset'),
              ),
            ],
          ),
    );
    return result == true;
  }

  void _generatePlayerCode() {
    _playerCodeController.text = _generatePlayerCodeValue();
  }

  String _generatePlayerCodeValue() {
    const characters = 'ABCDEFGHIJKLMNPQRSTUVWXYZ123456789';
    return List.generate(
      6,
      (_) => characters[_random.nextInt(characters.length)],
    ).join();
  }

  bool _isValidPlayerCode(String value) {
    return RegExp(r'^[A-NP-Z1-9]{6}$').hasMatch(value.toUpperCase());
  }
}

enum GameMode { allFives, draw, block, teams }

enum _ProfileEditDecision { cancel, rewardedAd, pro }

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _CountryOption {
  const _CountryOption(this.code, this.englishName, this.spanishName);

  final String code;
  final String englishName;
  final String spanishName;
}

class _HowToPlayPage {
  const _HowToPlayPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
