import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

import '../legal/legal_content.dart';
import '../legal_acceptance_notifier.dart';
import '../premium_notifier.dart';
import '../services/subscription_management_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  static const _ink = Color(0xFF061522);
  static const _surface = Color(0xFF102838);
  static const _surfaceDeep = Color(0xFF0A1B29);
  static const _red = Color(0xFFEF3934);
  static const _redDark = Color(0xFFAB151A);
  static const _gold = Color(0xFFFFD166);
  static const _copy = Color(0xFFBAC8D2);
  static const _line = Color(0xFF46677B);
  static const _green = Color(0xFF64E99A);

  bool _acceptedTermsForPurchase = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final legal = context.read<LegalAcceptanceNotifier>();
      _acceptedTermsForPurchase = legal.hasAccepted;
      final premium = context.read<PremiumNotifier>();
      if (!premium.isPremium && premium.isStoreSupported) {
        premium.loadProducts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_ink, Color(0xFF091D2B), Color(0xFF061522)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 205,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_redDark, _red.withValues(alpha: .86), _ink],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(38),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 68,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Back',
                          onPressed: _goBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: Colors.white,
                          iconSize: 31,
                        ),
                      ),
                      const Text(
                        'Kapi Note Pro',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: _buildPremiumCard(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context) {
    final premium = context.watch<PremiumNotifier>();
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    final monthly = premium.monthlyProduct;
    final yearly = premium.yearlyProduct;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceDeep.withValues(alpha: .98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _gold.withValues(alpha: .8), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHero(premium.isPremium, isSpanish),
          const SizedBox(height: 20),
          Text(
            premium.isPremium
                ? (isSpanish
                    ? 'Gracias por apoyar a Kapi Note.'
                    : 'Thank you for supporting Kapi Note.')
                : (isSpanish
                    ? 'Juega sin anuncios y apoya a Kapi Note.'
                    : 'Play without ads and support Kapi Note.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _copy,
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          _buildComparison(isSpanish),
          if (premium.isPremium) ...[
            const SizedBox(height: 18),
            _buildManageSubscriptionButton(context, isSpanish),
          ] else ...[
            const SizedBox(height: 20),
            if (premium.isLoading && !premium.isReady)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(color: _gold),
                ),
              )
            else if (!premium.isStoreSupported)
              _buildInfoNotice(
                icon: Icons.storefront_outlined,
                text:
                    isSpanish
                        ? 'Las compras no están disponibles en este dispositivo.'
                        : 'Purchases are not available on this device.',
              )
            else if (!premium.canBuyPremium)
              _buildStoreIssue(context, isSpanish)
            else ...[
              Text(
                isSpanish
                    ? 'Elige tu plan. La compra se completa de forma segura en la tienda de tu dispositivo.'
                    : 'Choose a plan. Your purchase is completed securely in your device store.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _copy,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 15),
              _buildPurchaseTermsCheckbox(context, isSpanish),
              const SizedBox(height: 16),
              _buildPremiumPlanButton(
                context: context,
                title: isSpanish ? 'Mensual' : 'Monthly',
                product: monthly,
                featured: true,
              ),
              const SizedBox(height: 11),
              _buildPremiumPlanButton(
                context: context,
                title: isSpanish ? 'Anual' : 'Yearly',
                product: yearly,
              ),
              const SizedBox(height: 8),
              _buildTextAction(
                label: isSpanish ? 'Continuar gratis' : 'Continue free',
                icon: Icons.play_arrow_rounded,
                onPressed: _goBack,
              ),
              _buildTextAction(
                label: isSpanish ? 'Restaurar compras' : 'Restore purchases',
                icon: Icons.restore_rounded,
                onPressed:
                    premium.isLoading ? null : () => premium.restorePurchases(),
              ),
            ],
          ],
          if (premium.isLoading && premium.isReady) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(color: _gold, backgroundColor: _line),
          ],
        ],
      ),
    );
  }

  Widget _buildHero(bool isPremium, bool isSpanish) {
    return Column(
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_gold, Color(0xFFD79C2C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: _ink,
            size: 37,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isPremium
              ? (isSpanish ? 'Kapi Note Pro activo' : 'Kapi Note Pro active')
              : 'Kapi Note Pro',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 27,
            letterSpacing: -.5,
          ),
        ),
        if (isPremium) ...[
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: .14),
              border: Border.all(color: _green.withValues(alpha: .8)),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              isSpanish ? 'SIN ANUNCIOS' : 'AD-FREE',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildComparison(bool isSpanish) {
    final free = [
      isSpanish ? 'Marcador de dominó' : 'Domino scorekeeper',
      isSpanish ? 'Configuración de juego' : 'Game settings',
      isSpanish ? 'Partidas online y contra CPU' : 'Online and CPU games',
      isSpanish ? 'Tienda y estilos personalizados' : 'Shop and custom styles',
      isSpanish ? 'Anuncios incluidos' : 'Includes ads',
    ];
    final pro = [
      isSpanish ? 'Sin anuncios en toda la app' : 'No ads anywhere in the app',
      isSpanish
          ? 'Juegos y notas sin interrupciones'
          : 'Uninterrupted games and notes',
      isSpanish
          ? 'Acceso a futuras funciones Pro'
          : 'Access to future Pro features',
      isSpanish
          ? 'Restaura tu compra fácilmente'
          : 'Easily restore your purchase',
      isSpanish ? 'Apoyas una app independiente' : 'Support an independent app',
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _buildFeatureColumn(isSpanish ? 'Free' : 'Free', free, false),
          _buildFeatureColumn('Pro', pro, true),
        ];
        if (constraints.maxWidth < 470) {
          return Column(
            children: [cards[0], const SizedBox(height: 12), cards[1]],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }

  Widget _buildFeatureColumn(String title, List<String> features, bool isPro) {
    final color = isPro ? _gold : _copy;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isPro ? _gold.withValues(alpha: .7) : _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 21,
            ),
          ),
          const SizedBox(height: 10),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, color: color, size: 18),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        color: _copy,
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoNotice({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Icon(icon, color: _gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _copy, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreIssue(BuildContext context, bool isSpanish) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _redDark.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _red.withValues(alpha: .75)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: _gold, size: 30),
          const SizedBox(height: 7),
          Text(
            isSpanish
                ? 'La tienda no está disponible por ahora.'
                : 'The store is not available right now.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isSpanish
                ? 'Puedes continuar usando Kapi Note gratis e intentar nuevamente más tarde.'
                : 'You can keep using Kapi Note free and try again later.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _copy, height: 1.3),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.read<PremiumNotifier>().loadProducts(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(isSpanish ? 'Intentar otra vez' : 'Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: _gold),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManageSubscriptionButton(BuildContext context, bool isSpanish) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _openSubscriptionSettings,
        icon: const Icon(Icons.manage_accounts_outlined),
        label: Text(
          isSpanish ? 'Gestionar suscripción' : 'Manage subscription',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _gold,
          side: const BorderSide(color: _gold),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 15),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildPurchaseTermsCheckbox(BuildContext context, bool isSpanish) {
    return Container(
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: .7),
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(17),
      ),
      child: CheckboxListTile(
        value: _acceptedTermsForPurchase,
        activeColor: _gold,
        checkColor: _ink,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        title: Text(
          isSpanish
              ? 'Acepto los Términos y Condiciones y la Política de Privacidad.'
              : 'I agree to the Terms & Conditions and Privacy Policy.',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            height: 1.25,
          ),
        ),
        subtitle: Wrap(
          spacing: 4,
          children: [
            TextButton(
              onPressed:
                  () => _showLegalSheet(
                    context,
                    isSpanish ? 'Términos y Condiciones' : 'Terms & Conditions',
                    LegalContent.termsBody,
                  ),
              child: Text(isSpanish ? 'Leer términos' : 'Read terms'),
            ),
            TextButton(
              onPressed:
                  () => _showLegalSheet(
                    context,
                    isSpanish ? 'Política de Privacidad' : 'Privacy Policy',
                    LegalContent.privacyBody,
                  ),
              child: Text(isSpanish ? 'Privacidad' : 'Privacy'),
            ),
          ],
        ),
        onChanged: (value) async {
          final accepted = value ?? false;
          setState(() => _acceptedTermsForPurchase = accepted);
          if (accepted) {
            await context.read<LegalAcceptanceNotifier>().accept();
          }
        },
      ),
    );
  }

  Widget _buildPremiumPlanButton({
    required BuildContext context,
    required String title,
    required ProductDetails? product,
    bool featured = false,
  }) {
    final premium = context.watch<PremiumNotifier>();
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    final enabled =
        product != null && !premium.isLoading && _acceptedTermsForPurchase;
    final label =
        product == null
            ? '$title · ${isSpanish ? 'Próximamente' : 'Coming soon'}'
            : '$title · ${product.price}';
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled ? () => premium.buy(product) : null,
        icon: const Icon(Icons.workspace_premium_rounded),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: _red,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              featured ? _redDark.withValues(alpha: .72) : _surface,
          disabledForegroundColor:
              featured
                  ? Colors.white.withValues(alpha: .88)
                  : _copy.withValues(alpha: .65),
          elevation: featured ? 7 : 0,
          shadowColor: featured ? _gold.withValues(alpha: .5) : null,
          side:
              featured
                  ? const BorderSide(color: _gold, width: 2)
                  : BorderSide.none,
          padding: EdgeInsets.symmetric(vertical: featured ? 18 : 16),
          shape: const StadiumBorder(),
          textStyle: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: featured ? 19 : 17,
          ),
        ),
      ),
    );
  }

  Widget _buildTextAction({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: _gold,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  void _showLegalSheet(BuildContext context, String title, String content) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 620),
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
              decoration: const BoxDecoration(
                color: _surfaceDeep,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: _gold)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        color: _gold,
                      ),
                    ],
                  ),
                  const Divider(color: _line),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        content,
                        style: const TextStyle(color: _copy, height: 1.45),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _openSubscriptionSettings() async {
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    final opened =
        await SubscriptionManagementService.openSubscriptionSettings();
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSpanish
              ? 'No pudimos abrir la gestión de suscripción en este dispositivo.'
              : 'We could not open subscription management on this device.',
        ),
      ),
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }
}
