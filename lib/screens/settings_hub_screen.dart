import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../premium_notifier.dart';
import '../services/subscription_management_service.dart';
import '../widgets/anchored_adaptive_banner_ad.dart';
import '../widgets/app_footer.dart';
import 'about_screen.dart';

class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({super.key});

  static const _burgundy = Color(0xFF720B09);
  static const _navy = Color(0xFF071524);
  static const _panel = Color(0xEE171C24);
  static const _gold = Color(0xFFFFD36A);

  String get _adUnitId =>
      defaultTargetPlatform == TargetPlatform.android
          ? 'ca-app-pub-8588489900323524/2555306020'
          : 'ca-app-pub-8588489900323524/9168815834';

  @override
  Widget build(BuildContext context) {
    final spanish = Localizations.localeOf(context).languageCode == 'es';

    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: _gold,
          secondary: Color(0xFFF13A37),
          surface: _panel,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      child: Scaffold(
        backgroundColor: _navy,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            spanish ? 'Configuracion' : 'Settings',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/image/background.png',
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.42),
                colorBlendMode: BlendMode.darken,
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_burgundy, Color(0xD916171E), _navy],
                    stops: [0, 0.42, 1],
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                children: [
                  _SettingsDestination(
                    icon: Icons.sports_esports_rounded,
                    title:
                        spanish ? 'Configuracion del juego' : 'Game Settings',
                    subtitle:
                        spanish
                            ? 'Musica, efectos y volumen'
                            : 'Music, effects and volume',
                    onTap: () => Navigator.pushNamed(context, '/game-settings'),
                  ),
                  const SizedBox(height: 14),
                  _SettingsDestination(
                    icon: Icons.edit_note_rounded,
                    title:
                        spanish ? 'Configuracion de apuntes' : 'Note Settings',
                    subtitle:
                        spanish
                            ? 'Idioma, tema, puntos y tamanos'
                            : 'Language, theme, scores and sizes',
                    onTap: () => Navigator.pushNamed(context, '/note-settings'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    spanish ? 'Cuenta y ayuda' : 'Account & Help',
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SettingsLink(
                    icon: Icons.verified_user_rounded,
                    title:
                        spanish
                            ? 'Proteger o recuperar perfil'
                            : 'Protect or recover profile',
                    subtitle:
                        spanish
                            ? 'Conserva tu ID, ranking, puntos y amigos'
                            : 'Keep your ID, ranking, points, and friends',
                    onTap:
                        () => Navigator.pushNamed(context, '/player-account'),
                  ),
                  const SizedBox(height: 10),
                  _SettingsLink(
                    icon: Icons.manage_accounts_rounded,
                    title:
                        spanish
                            ? 'Administrar o cancelar suscripcion'
                            : 'Manage or cancel subscription',
                    subtitle:
                        spanish
                            ? 'Abre ${_storeName()} para cambiar o cancelar Pro.'
                            : 'Open ${_storeName()} to change or cancel Pro.',
                    onTap: () => _openSubscriptions(context, spanish),
                  ),
                  const SizedBox(height: 10),
                  _SettingsLink(
                    icon: Icons.feedback_rounded,
                    title:
                        spanish
                            ? 'Reportar error o sugerencia'
                            : 'Report a bug or suggestion',
                    subtitle:
                        spanish
                            ? 'Ayudanos a mejorar Kapi Note'
                            : 'Help us improve Kapi Note',
                    onTap: () => _openFeedbackSheet(context, spanish),
                  ),
                  const SizedBox(height: 10),
                  _SettingsLink(
                    icon: Icons.privacy_tip_rounded,
                    title: 'Terms & Privacy',
                    subtitle:
                        spanish
                            ? 'Ver terminos, condiciones y privacidad'
                            : 'View Terms & Conditions and Privacy Policy',
                    onTap: () => Navigator.pushNamed(context, '/terms-privacy'),
                  ),
                  const SizedBox(height: 10),
                  _SettingsLink(
                    icon: Icons.info_rounded,
                    title: spanish ? 'Acerca de' : 'About',
                    subtitle:
                        spanish
                            ? 'Informacion sobre Kapi Note'
                            : 'Information about Kapi Note',
                    onTap: () => _openAbout(context),
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: AnchoredAdaptiveBannerAd(adUnitId: _adUnitId),
                  ),
                  const SizedBox(height: 14),
                  DefaultTextStyle.merge(
                    style: const TextStyle(color: Color(0xFFD7D9DF)),
                    child: const AppFooter(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _storeName() =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'App Store' : 'Google Play';

  static Future<void> _openSubscriptions(
    BuildContext context,
    bool spanish,
  ) async {
    final premium = context.read<PremiumNotifier>();
    final opened = await SubscriptionManagementService.openSubscriptionSettings(
      productId: premium.activeProductId,
    );
    if (!context.mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          spanish
              ? 'No pudimos abrir las suscripciones. Abrelas desde ${_storeName()}.'
              : 'We could not open subscriptions. Open them from ${_storeName()}.',
        ),
      ),
    );
  }

  static void _openAbout(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/about'),
        builder: (_) => const AboutScreen(),
      ),
    );
  }

  static void _openFeedbackSheet(BuildContext context, bool spanish) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: _navy,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(top: BorderSide(color: _gold, width: 1.4)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  spanish ? '¿Como podemos ayudarte?' : 'How can we help?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  spanish
                      ? 'Prepararemos un mensaje con la version de la app. Tu decides si deseas enviarlo.'
                      : 'We will prepare a message with the app version. You decide whether to send it.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFC7C9CE),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                _FeedbackChoice(
                  icon: Icons.bug_report_rounded,
                  color: const Color(0xFFF13A37),
                  title: spanish ? 'Reportar un error' : 'Report a bug',
                  subtitle:
                      spanish
                          ? 'Algo no funciona correctamente'
                          : 'Something is not working correctly',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openFeedback(context, spanish: spanish, isBug: true);
                  },
                ),
                const SizedBox(height: 11),
                _FeedbackChoice(
                  icon: Icons.lightbulb_rounded,
                  color: const Color(0xFF248BEA),
                  title: spanish ? 'Enviar sugerencia' : 'Send a suggestion',
                  subtitle:
                      spanish
                          ? 'Comparte una idea para mejorar la app'
                          : 'Share an idea to improve the app',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openFeedback(context, spanish: spanish, isBug: false);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _openFeedback(
    BuildContext context, {
    required bool spanish,
    required bool isBug,
  }) async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!context.mounted) return;

    final version = '${packageInfo.version}+${packageInfo.buildNumber}';
    final platform = _platformName();
    final subject =
        isBug
            ? 'Kapi Note - ${spanish ? 'Reporte de error' : 'Bug report'}'
            : 'Kapi Note - ${spanish ? 'Sugerencia' : 'Suggestion'}';
    final body =
        spanish
            ? '${isBug ? 'Describe el error' : 'Describe tu sugerencia'}:\n\n\n'
                'Pasos o detalles:\n- \n\n'
                'Version: $version\nPlataforma: $platform\n'
            : '${isBug ? 'Describe the problem' : 'Describe your suggestion'}:\n\n\n'
                'Steps or details:\n- \n\n'
                'Version: $version\nPlatform: $platform\n';
    final uri = Uri(
      scheme: 'mailto',
      path: 'sales@liisgo.com',
      queryParameters: {'subject': subject, 'body': body},
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted || opened) return;

    await Clipboard.setData(const ClipboardData(text: 'sales@liisgo.com'));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          spanish
              ? 'No pudimos abrir el correo. Copiamos sales@liisgo.com.'
              : 'We could not open email. We copied sales@liisgo.com.',
        ),
      ),
    );
  }

  static String _platformName() {
    if (kIsWeb) return 'Web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }
}

class _FeedbackChoice extends StatelessWidget {
  const _FeedbackChoice({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SettingsHubScreen._panel,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color),
                ),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFB9BBC2),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: SettingsHubScreen._gold,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDestination extends StatelessWidget {
  const _SettingsDestination({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SettingsHubScreen._panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: SettingsHubScreen._gold.withValues(alpha: 0.62),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF13A37),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SettingsHubScreen._gold),
                ),
                child: Icon(icon, color: Colors.white, size: 29),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFFC7C9CE)),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: SettingsHubScreen._gold,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SettingsHubScreen._panel,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: SettingsHubScreen._gold, size: 25),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFB9BBC2),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
