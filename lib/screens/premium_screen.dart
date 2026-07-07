import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  bool _acceptedTermsForPurchase = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final legalAcceptance = context.read<LegalAcceptanceNotifier>();
      if (legalAcceptance.hasAccepted) {
        setState(() => _acceptedTermsForPurchase = true);
      }
      final premiumNotifier = context.read<PremiumNotifier>();
      if (!premiumNotifier.isPremium && premiumNotifier.isStoreSupported) {
        premiumNotifier.loadProducts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: isSpanish ? 'Volver' : 'Back',
          onPressed: () => _goBack(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/image/background.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Color.fromARGB((255 * 0.3).round(), 0, 0, 0),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0x66000000)
                      : const Color(0x33FFFFFF),
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xAA000000)
                      : const Color(0x66FFFFFF),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _buildPremiumCard(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context) {
    final premiumNotifier = Provider.of<PremiumNotifier>(context);
    final monthlyProduct = premiumNotifier.monthlyProduct;
    final yearlyProduct = premiumNotifier.yearlyProduct;
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';

    final activeText =
        isSpanish
            ? 'Pro activo. Los anuncios están removidos.'
            : 'Pro active. Ads are removed.';
    final description =
        isSpanish
            ? 'Kapi Note Free sigue funcionando para llevar tus puntos. Pro remueve anuncios y nos ayuda a mejorar la app, crear más herramientas para nuestro hobby del dominó y apoyar a la comunidad.'
            : 'Kapi Note Free keeps working for scorekeeping. Pro removes ads and helps us improve the app, build more tools for our domino hobby, and support the community.';
    final unavailableText =
        isSpanish
            ? 'No pudimos cargar los productos de la tienda ahora. Puedes seguir usando la app gratis y reintentar más tarde.'
            : 'We could not load store products right now. You can keep using the app for free and try again later.';
    final restoreText = isSpanish ? 'Restaurar' : 'Restore';

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).cardColor.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.84 : 0.94,
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 34,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Kapi Note Pro',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (premiumNotifier.isPremium)
                  Icon(
                    Icons.check_circle_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              premiumNotifier.isPremium ? activeText : description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            _buildComparison(context, isSpanish),
            const SizedBox(height: 12),
            _buildManageSubscriptionButton(context, premiumNotifier, isSpanish),
            if (!premiumNotifier.isPremium) ...[
              const SizedBox(height: 18),
              if (premiumNotifier.isLoading)
                Text(
                  isSpanish ? 'Cargando precios...' : 'Loading prices...',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else if (!premiumNotifier.isStoreSupported)
                Text(
                  isSpanish
                      ? 'Las compras Pro no están disponibles en esta plataforma.'
                      : 'Pro purchases are not available on this platform.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else if (!premiumNotifier.canBuyPremium &&
                  premiumNotifier.isReady)
                _buildStoreIssue(context, unavailableText)
              else if (premiumNotifier.isReady &&
                  monthlyProduct == null &&
                  yearlyProduct == null)
                _buildStoreIssue(context, unavailableText)
              else ...[
                Text(
                  isSpanish
                      ? 'Para suscribirte, elige el plan mensual o anual abajo. La compra se completa dentro del app con ${_storeName()}.'
                      : 'To subscribe, choose the monthly or yearly plan below. The purchase is completed inside the app with ${_storeName()}.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _buildPurchaseTermsCheckbox(context, isSpanish),
                const SizedBox(height: 12),
                _buildPremiumPlanButton(
                  context: context,
                  title: isSpanish ? 'Mensual' : 'Monthly',
                  product: monthlyProduct,
                  missingProductId: premiumNotifier.currentMonthlyProductId,
                ),
                const SizedBox(height: 10),
                _buildPremiumPlanButton(
                  context: context,
                  title: isSpanish ? 'Anual' : 'Yearly',
                  product: yearlyProduct,
                  missingProductId: premiumNotifier.currentYearlyProductId,
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _goBack(context),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(isSpanish ? 'Continuar gratis' : 'Continue free'),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed:
                      premiumNotifier.isLoading ||
                              !premiumNotifier.isStoreSupported
                          ? null
                          : premiumNotifier.restorePurchases,
                  icon: const Icon(Icons.restore_rounded),
                  label: Text(restoreText),
                ),
              ),
            ],
            if (premiumNotifier.isLoading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (premiumNotifier.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                premiumNotifier.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacementNamed(context, '/home');
  }

  Widget _buildComparison(BuildContext context, bool isSpanish) {
    final freeItems =
        isSpanish
            ? [
              'Marcador usable',
              'Ajustes de juego',
              'Compartir app',
              'Incluye anuncios',
            ]
            : [
              'Usable scorekeeper',
              'Game settings',
              'Share app',
              'Includes ads',
            ];
    final proItems =
        isSpanish
            ? [
              'Sin anuncios',
              'Uso ilimitado sin interrupciones de ads',
              'Herramientas y plantillas premium cuando estén disponibles',
              'Apoya a una compañía pequeña que crea apps útiles',
            ]
            : [
              'No ads',
              'Unlimited use without ad interruptions',
              'Premium tools and templates when available',
              'Supports a small company building useful apps',
            ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        final children = [
          _buildFeatureColumn(context, isSpanish ? 'Free' : 'Free', freeItems),
          _buildFeatureColumn(context, 'Pro', proItems),
        ];

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[0]),
              const SizedBox(width: 12),
              Expanded(child: children[1]),
            ],
          );
        }

        return Column(
          children: [children[0], const SizedBox(height: 12), children[1]],
        );
      },
    );
  }

  Widget _buildFeatureColumn(
    BuildContext context,
    String title,
    List<String> items,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_rounded, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStoreIssue(BuildContext context, String text) {
    final premiumNotifier = Provider.of<PremiumNotifier>(
      context,
      listen: false,
    );
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: premiumNotifier.loadProducts,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(isSpanish ? 'Reintentar cargar precios' : 'Retry prices'),
        ),
      ],
    );
  }

  Widget _buildManageSubscriptionButton(
    BuildContext context,
    PremiumNotifier premiumNotifier,
    bool isSpanish,
  ) {
    if (!premiumNotifier.isStoreSupported) {
      return const SizedBox.shrink();
    }
    if (!premiumNotifier.isPremium && premiumNotifier.activeProductId == null) {
      return const SizedBox.shrink();
    }

    return OutlinedButton.icon(
      onPressed:
          () => _openSubscriptionSettings(
            context,
            premiumNotifier.activeProductId,
            isSpanish,
          ),
      icon: const Icon(Icons.manage_accounts_rounded),
      label: Text(
        isSpanish
            ? 'Administrar o cancelar suscripción'
            : 'Manage or cancel subscription',
      ),
    );
  }

  Widget _buildPurchaseTermsCheckbox(BuildContext context, bool isSpanish) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
        ),
      ),
      child: CheckboxListTile(
        value: _acceptedTermsForPurchase,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        onChanged: (value) {
          setState(() => _acceptedTermsForPurchase = value ?? false);
        },
        title: Text(
          isSpanish
              ? 'Acepto los Terms & Conditions y Privacy Policy antes de suscribirme a Pro.'
              : 'I agree to the Terms & Conditions and Privacy Policy before subscribing to Pro.',
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 0,
          children: [
            TextButton(
              onPressed:
                  () => _showLegalSheet(
                    LegalContent.termsTitle,
                    LegalContent.termsBody,
                  ),
              child: const Text(LegalContent.termsTitle),
            ),
            TextButton(
              onPressed:
                  () => _showLegalSheet(
                    LegalContent.privacyTitle,
                    LegalContent.privacyBody,
                  ),
              child: const Text(LegalContent.privacyTitle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumPlanButton({
    required BuildContext context,
    required String title,
    required ProductDetails? product,
    required String missingProductId,
  }) {
    final premiumNotifier = Provider.of<PremiumNotifier>(
      context,
      listen: false,
    );
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    final label =
        product == null
            ? '$title - ${isSpanish ? 'no disponible' : 'not available'}'
            : '$title - ${product.price}';

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed:
            premiumNotifier.isLoading
                ? null
                : () {
                  if (product == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isSpanish
                              ? 'La tienda no devolvió el producto $missingProductId. Revisa que exista y esté aprobado.'
                              : 'The store did not return $missingProductId. Check that it exists and is approved.',
                        ),
                      ),
                    );
                    premiumNotifier.loadProducts();
                    return;
                  }
                  if (!_acceptedTermsForPurchase) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isSpanish
                              ? 'Acepta los Terms & Conditions y Privacy Policy antes de suscribirte a Pro.'
                              : 'Please accept the Terms & Conditions and Privacy Policy before subscribing to Pro.',
                        ),
                      ),
                    );
                    return;
                  }
                  context.read<LegalAcceptanceNotifier>().accept();
                  premiumNotifier.buy(product);
                },
        icon: const Icon(Icons.workspace_premium_rounded),
        label: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _showLegalSheet(String title, String body) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: FractionallySizedBox(
              heightFactor: 0.78,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        body,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.45),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSubscriptionSettings(
    BuildContext context,
    String? productId,
    bool isSpanish,
  ) async {
    final opened = await SubscriptionManagementService.openSubscriptionSettings(
      productId: productId,
    );
    if (!context.mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSpanish
              ? 'No pudimos abrir la página de suscripciones. Ábrela desde ${_storeName()}.'
              : 'We could not open subscription settings. Open them from ${_storeName()}.',
        ),
      ),
    );
  }

  String _storeName() {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? 'App Store'
        : 'Google Play';
  }
}
