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
import '../widgets/anchored_adaptive_banner_ad.dart';
import '../widgets/app_version_label.dart';
import 'admob_variable.dart';

class StartGameScreen extends StatefulWidget {
  const StartGameScreen({super.key});

  @override
  State<StartGameScreen> createState() => _StartGameScreenState();
}

class _StartGameScreenState extends State<StartGameScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _playerCodeController = TextEditingController();
  final Random _random = Random();
  GameMode _selectedMode = GameMode.classic;
  String _selectedCountryCode = 'US';
  String _selectedAvatarKey = 'person';
  bool _didSetDefaultCountry = false;
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

  static const List<_AvatarOption> _avatarOptions = [
    _AvatarOption('person', Icons.person_rounded, Color(0xFF1E88E5)),
    _AvatarOption('woman', Icons.face_3_rounded, Color(0xFFE91E63)),
    _AvatarOption('robot', Icons.smart_toy_rounded, Color(0xFF26C6DA)),
    _AvatarOption('rainbow', Icons.auto_awesome_rounded, Color(0xFFAB47BC)),
    _AvatarOption('game', Icons.sports_esports_rounded, Color(0xFF43A047)),
    _AvatarOption('star', Icons.star_rounded, Color(0xFFFFB300)),
  ];

  bool get _isSpanish => Localizations.localeOf(context).languageCode == 'es';

  String get _playerInitials {
    final initials = _nameController.text.trim().toUpperCase();
    return initials.length == 2 ? initials : 'JP';
  }

  String get _publicPlayerId =>
      'ID: $_playerInitials.$_selectedCountryCode.${_playerCodeController.text}';

  String get _analyticsGameMode =>
      _selectedMode == GameMode.classic ? 'classic' : 'draw_pool';

  _AvatarOption get _selectedAvatar => _avatarOptions.firstWhere(
    (avatar) => avatar.key == _selectedAvatarKey,
    orElse: () => _avatarOptions.first,
  );

  String get _adUnitId =>
      defaultTargetPlatform == TargetPlatform.android
          ? AdmobVariable.bannerAndroidUnit
          : AdmobVariable.bannerIosUnit;

  @override
  void initState() {
    super.initState();
    _nameController.text = 'JP';
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
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: _isSpanish ? 'Volver' : 'Back',
          onPressed: () => Navigator.pop(context),
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
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isTablet = constraints.maxWidth >= 720;
                      return Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 48 : 20,
                            vertical: 22,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isTablet ? 720 : double.infinity,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeader(isTablet),
                                SizedBox(height: isTablet ? 28 : 20),
                                _buildSetupPanel(isTablet),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                AnchoredAdaptiveBannerAd(
                  adUnitId: _adUnitId,
                  margin: EdgeInsets.zero,
                ),
                const AppVersionLabel(
                  padding: EdgeInsets.only(top: 6, bottom: 8),
                  fontSize: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isTablet) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sports_esports_rounded,
                color: Color(0xFFFFF176),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _isSpanish ? 'Nuevo juego' : 'New game',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _isSpanish ? 'Prepara la partida' : 'Set Up Match',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: isTablet ? 54 : 38,
            fontWeight: FontWeight.w900,
            height: 1,
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
        const SizedBox(height: 12),
        Text(
          _isSpanish
              ? 'Crea tu perfil y elige el modo antes de empezar.'
              : 'Create your profile and choose the game mode before starting.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.84),
            fontSize: isTablet ? 20 : 15,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSetupPanel(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 22 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileButton(isTablet),
          const SizedBox(height: 18),
          Text(
            _isSpanish ? 'Modo de juego' : 'Game mode',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontWeight: FontWeight.w800,
              fontSize: isTablet ? 18 : 14,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildModeCard(
                  mode: GameMode.classic,
                  icon: Icons.style_rounded,
                  title: _isSpanish ? 'Clasico beta' : 'Classic beta',
                  subtitle: _isSpanish ? 'Paso sin pozo' : 'Pass without pool',
                  isTablet: isTablet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModeCard(
                  mode: GameMode.draw,
                  icon: Icons.inventory_2_rounded,
                  title: _isSpanish ? 'Control con pozo' : 'Draw / Pool',
                  subtitle:
                      _isSpanish ? 'Tomar fichas del pozo' : 'Draw from pool',
                  isTablet: isTablet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: isTablet ? 58 : 50,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/ranking'),
              icon: Icon(Icons.leaderboard_rounded, size: isTablet ? 24 : 20),
              label: Text(
                _isSpanish ? 'Ranking de puntos' : 'Points Ranking',
                style: TextStyle(
                  fontSize: isTablet ? 17 : 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black.withValues(alpha: 0.18),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: isTablet ? 72 : 58,
            child: FilledButton.icon(
              onPressed: _continueToGame,
              icon: Icon(Icons.play_arrow_rounded, size: isTablet ? 32 : 26),
              label: Text(
                _isSpanish ? 'Continuar' : 'Continue',
                style: TextStyle(
                  fontSize: isTablet ? 22 : 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
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

  Widget _buildProfileButton(bool isTablet) {
    final country = _countryOptions.firstWhere(
      (option) => option.code == _selectedCountryCode,
      orElse: () => _countryOptions.first,
    );
    final countryName = _isSpanish ? country.spanishName : country.englishName;

    return InkWell(
      onTap: _showProfileEditor,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: EdgeInsets.all(isTablet ? 18 : 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: isTablet ? 54 : 46,
              height: isTablet ? 54 : 46,
              decoration: BoxDecoration(
                color: _selectedAvatar.color,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFD36B)),
              ),
              child: Center(
                child: Icon(
                  _selectedAvatar.icon,
                  color: Colors.white,
                  size: isTablet ? 30 : 26,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSpanish ? 'Crear perfil' : 'Create Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 18 : 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$_playerInitials · $_selectedCountryCode · $countryName',
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
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Future<void> _preloadRewardedAd() async {
    if (kIsWeb || _rewardedAd != null || _isPreloadingRewardedAd) return;

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
      if (savedAvatar != null &&
          _avatarOptions.any((avatar) => avatar.key == savedAvatar)) {
        _selectedAvatarKey = savedAvatar;
      }
    });
  }

  String _cleanInitials(String value) {
    final lettersOnly = value.trim().toUpperCase().replaceAll(
      RegExp('[^A-Z]'),
      '',
    );
    if (lettersOnly.length >= 2) {
      return lettersOnly.substring(0, 2);
    }
    return 'JP';
  }

  bool _profileChanged({
    required String initials,
    required String countryCode,
    required String avatarKey,
  }) {
    return _cleanInitials(initials) != _playerInitials ||
        countryCode != _selectedCountryCode ||
        avatarKey != _selectedAvatarKey;
  }

  Future<void> _saveProfileFromEditor({
    required BuildContext sheetContext,
    required String initials,
    required String countryCode,
    required String avatarKey,
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
      avatarKey: avatarKey,
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
    await prefs.setString(_profileAvatarKey, avatarKey);
    await prefs.setString(_profileCodeKey, _playerCodeController.text);
    await prefs.setBool(_profileSavedKey, true);
    if (!premiumNotifier.isPremium) {
      await prefs.setBool(_profileFreeEditUsedKey, true);
    }

    if (!mounted) return;
    unawaited(
      AnalyticsService.logDominoProfileSaved(
        countryCode: countryCode,
        avatarKey: avatarKey,
        gameMode: _analyticsGameMode,
        isFirstProfile: wasFirstProfile,
        isPremium: premiumNotifier.isPremium,
      ),
    );
    setState(() {
      _nameController.text = cleanedInitials;
      _selectedCountryCode = countryCode;
      _selectedAvatarKey = avatarKey;
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

  void _showProfileEditor() {
    final tempInitialsController = TextEditingController(text: _playerInitials);
    String tempCountryCode = _selectedCountryCode;
    String tempAvatarKey = _selectedAvatarKey;
    final tempPlayerCode = _playerCodeController.text;

    String tempPublicPlayerId() {
      final initials = _cleanInitials(tempInitialsController.text);
      return 'ID: $initials.$tempCountryCode.$tempPlayerCode';
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
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
                            _isSpanish ? 'Crear perfil' : 'Create Profile',
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
                            _isSpanish ? 'Icono del jugador' : 'Player icon',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children:
                                _avatarOptions.map((avatar) {
                                  final selected = avatar.key == tempAvatarKey;
                                  return InkWell(
                                    onTap: () {
                                      setSheetState(
                                        () => tempAvatarKey = avatar.key,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        color: avatar.color.withValues(
                                          alpha: selected ? 0.95 : 0.42,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color:
                                              selected
                                                  ? const Color(0xFFFFD36B)
                                                  : Colors.white.withValues(
                                                    alpha: 0.18,
                                                  ),
                                          width: selected ? 2 : 1,
                                        ),
                                      ),
                                      child: Icon(
                                        avatar.icon,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  );
                                }).toList(),
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
                          Container(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.sizeOf(context).height < 820
                                      ? 160
                                      : 180,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: _countryOptions.length,
                              separatorBuilder:
                                  (_, __) => Divider(
                                    height: 1,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                              itemBuilder: (context, index) {
                                final country = _countryOptions[index];
                                final selected =
                                    country.code == tempCountryCode;
                                final countryName =
                                    _isSpanish
                                        ? country.spanishName
                                        : country.englishName;
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        selected
                                            ? const Color(0xFF1E88E5)
                                            : Colors.white.withValues(
                                              alpha: 0.10,
                                            ),
                                    child: Text(
                                      country.code,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    '${country.code} - $countryName',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: selected ? 1 : 0.82,
                                      ),
                                      fontWeight:
                                          selected
                                              ? FontWeight.w900
                                              : FontWeight.w700,
                                    ),
                                  ),
                                  trailing:
                                      selected
                                          ? const Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF7CFF9B),
                                          )
                                          : null,
                                  onTap: () {
                                    setSheetState(
                                      () => tempCountryCode = country.code,
                                    );
                                  },
                                );
                              },
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
                            avatarKey: tempAvatarKey,
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
  }) {
    final selected = _selectedMode == mode;
    final isComingSoon = mode == GameMode.draw;
    return InkWell(
      onTap:
          isComingSoon
              ? _showDrawComingSoon
              : () => setState(() => _selectedMode = mode),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.all(isTablet ? 18 : 14),
        decoration: BoxDecoration(
          color:
              selected
                  ? const Color(0xFF1E88E5).withValues(alpha: 0.92)
                  : Colors.black.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                selected
                    ? const Color(0xFFFFD36B)
                    : isComingSoon
                    ? const Color(0xFFFFD36B).withValues(alpha: 0.42)
                    : Colors.white.withValues(alpha: 0.18),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isComingSoon ? Icons.lock_clock_rounded : icon,
              color: Colors.white,
              size: isTablet ? 32 : 26,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: isTablet ? 18 : 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isComingSoon
                  ? (_isSpanish ? 'Proximamente' : 'Coming soon')
                  : subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontWeight: FontWeight.w600,
                fontSize: isTablet ? 13 : 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDrawComingSoon() {
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
                const Icon(
                  Icons.inventory_2_rounded,
                  color: Color(0xFFFFD36B),
                  size: 44,
                ),
                const SizedBox(height: 14),
                Text(
                  _isSpanish ? 'Control con pozo' : 'Draw / Pool',
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
                      ? 'Este modo viene pronto. Por ahora puedes probar Classic beta.'
                      : 'This mode is coming soon. For now, you can test Classic beta.',
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

  void _continueToGame() {
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

    if (_selectedMode == GameMode.draw) {
      _showDrawComingSoon();
      return;
    }

    unawaited(
      AnalyticsService.logDominoCpuGameStarted(
        gameMode: _analyticsGameMode,
        countryCode: _selectedCountryCode,
        avatarKey: _selectedAvatarKey,
      ),
    );
    Navigator.pushNamed(
      context,
      _selectedMode == GameMode.classic ? '/domino-classic' : '/domino-draw',
    );
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

enum GameMode { classic, draw }

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

class _AvatarOption {
  const _AvatarOption(this.key, this.icon, this.color);

  final String key;
  final IconData icon;
  final Color color;
}
