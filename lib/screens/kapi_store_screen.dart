import 'package:dominoes_note2025/screens/admob_variable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../premium_notifier.dart';
import '../services/kapi_cosmetics_service.dart';
import '../services/player_account_service.dart';
import '../widgets/anchored_adaptive_banner_ad.dart';
import 'player_account_screen.dart';

class KapiStoreScreen extends StatefulWidget {
  const KapiStoreScreen({super.key, this.ensureCoinAccount});

  /// Allows the purchase sheet to be exercised without a live Firebase
  /// session in widget tests. Production routes leave this unset.
  final Future<bool> Function(BuildContext context)? ensureCoinAccount;

  @override
  State<KapiStoreScreen> createState() => _KapiStoreScreenState();
}

class _KapiStoreScreenState extends State<KapiStoreScreen> {
  static const _ink = Color(0xFF050B14);
  static const _night = Color(0xFF091522);
  static const _surface = Color(0xFF101E2C);
  static const _surfaceRaised = Color(0xFF172A3B);
  static const _champagne = Color(0xFFD6B56B);
  static const _champagneLight = Color(0xFFF1D99C);
  static const _teal = Color(0xFF3FA99C);
  static const _blue = Color(0xFF4D8FC9);

  KapiCosmeticType _type = KapiCosmeticType.table;

  bool get _isSpanish => Localizations.localeOf(context).languageCode == 'es';
  String get _adUnitId =>
      defaultTargetPlatform == TargetPlatform.android
          ? AdmobVariable.bannerAndroidUnit
          : AdmobVariable.bannerIosUnit;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<KapiCosmeticsService>();
    final items = KapiCosmeticsService.catalog
        .where((item) => item.type == _type && item.storeVisible)
        .toList(growable: false);
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF710C18), Color(0xFF310A17)],
            ),
            border: Border(bottom: BorderSide(color: Color(0x66D6B56B))),
          ),
        ),
        title: Text(
          _isSpanish ? 'Tienda Kapi' : 'Kapi Shop',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: .2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xCC0B1420),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _champagne, width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: Color(0xFFE6C66E),
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${store.balance}',
                      style: const TextStyle(
                        color: _champagneLight,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_night, _ink],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF162B3D), Color(0xFF0B2027)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x99D6B56B)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 16,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF241E14),
                          shape: BoxShape.circle,
                          border: Border.all(color: _champagne),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.monetization_on_rounded,
                          color: _champagneLight,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isSpanish ? 'Kapi Coins' : 'Kapi Coins',
                              style: const TextStyle(
                                color: _champagneLight,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              _isSpanish
                                  ? 'Gana 10 por cada mano online ganada.'
                                  : 'Earn 10 for every online hand you win.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 36,
                            child: FilledButton.icon(
                              onPressed: _showCoinPacks,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF263C4C),
                                foregroundColor: _champagneLight,
                                side: const BorderSide(color: _champagne),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 16,
                              ),
                              label: Text(
                                _isSpanish ? 'Comprar' : 'Buy',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          if (KapiCosmeticsService.testCoinToolsEnabled) ...[
                            const SizedBox(height: 5),
                            SizedBox(
                              height: 27,
                              child: FilledButton(
                                onPressed: () => _addTestCoins(store),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFF24151C),
                                  foregroundColor: const Color(0xFFFFBDC3),
                                  side: const BorderSide(
                                    color: Color(0xFF8F3B4B),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text(
                                  'TEST +500',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Text(
                      _isSpanish ? 'ELIGE TU ESTILO' : 'CHOOSE YOUR STYLE',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 66,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    _tab(
                      KapiCosmeticType.table,
                      Icons.table_restaurant_rounded,
                      _isSpanish ? 'Mesas' : 'Tables',
                    ),
                    _tab(
                      KapiCosmeticType.centerpiece,
                      Icons.center_focus_strong_rounded,
                      _isSpanish ? 'Centro de mesa' : 'Centerpieces',
                    ),
                    _tab(
                      KapiCosmeticType.domino,
                      Icons.view_module_rounded,
                      _isSpanish ? 'Fichas' : 'Dominoes',
                    ),
                    _tab(
                      KapiCosmeticType.handTray,
                      Icons.inventory_2_rounded,
                      _isSpanish ? 'Paneles' : 'Trays',
                    ),
                    _tab(
                      KapiCosmeticType.avatar,
                      Icons.account_circle_rounded,
                      _isSpanish ? 'Perfiles' : 'Avatars',
                    ),
                    _tab(
                      KapiCosmeticType.flag,
                      Icons.flag_rounded,
                      _isSpanish ? 'Banderas' : 'Flags',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final count =
                        constraints.maxWidth >= 700
                            ? 4
                            : constraints.maxWidth >= 430
                            ? 3
                            : 2;
                    return GridView.builder(
                      key: ValueKey<KapiCosmeticType>(_type),
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: count,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio:
                            constraints.maxWidth < 360 ? 0.78 : 0.84,
                      ),
                      itemCount: items.length,
                      itemBuilder:
                          (context, index) => _itemCard(store, items[index]),
                    );
                  },
                ),
              ),
              AnchoredAdaptiveBannerAd(adUnitId: _adUnitId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(KapiCosmeticType type, IconData icon, String label) {
    final selected = _type == type;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _type = type),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minWidth: 72),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient:
                  selected
                      ? const LinearGradient(
                        colors: [Color(0xFF861425), Color(0xFF3D0D19)],
                      )
                      : null,
              color: selected ? null : const Color(0xFF111D29),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? _champagne : const Color(0xFF42505D),
                width: selected ? 1.5 : 1,
              ),
              boxShadow:
                  selected
                      ? const [
                        BoxShadow(
                          color: Color(0x332FBAAA),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ]
                      : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? _champagneLight : Colors.white60,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? _champagneLight : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemCard(KapiCosmeticsService store, KapiCosmeticItem item) {
    final owned = store.owns(item);
    final equipped = store.equipped(item.type).id == item.id;
    final canBuy = store.balance >= item.price;
    final previewDark =
        Color.lerp(item.primary, const Color(0xFF07111B), .34) ?? item.primary;
    final actionColor =
        equipped
            ? _champagne
            : owned
            ? _blue
            : canBuy
            ? _teal
            : const Color(0xFF536170);
    final action = equipped ? null : () => _activateItem(store, item);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_surfaceRaised, _surface],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: equipped ? _champagneLight : const Color(0xFF344657),
          width: equipped ? 2.2 : 1,
        ),
        boxShadow: [
          const BoxShadow(
            color: Color(0x66000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
          if (equipped)
            const BoxShadow(
              color: Color(0x55D6B56B),
              blurRadius: 16,
              spreadRadius: 1,
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: action,
          splashColor: _champagne.withValues(alpha: .18),
          highlightColor: Colors.white.withValues(alpha: .04),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [item.primary, previewDark],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: item.secondary.withValues(alpha: .72),
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 9,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (item.previewAsset != null)
                          Padding(
                            padding:
                                item.type == KapiCosmeticType.centerpiece
                                    ? const EdgeInsets.all(10)
                                    : EdgeInsets.zero,
                            child: Image.asset(
                              item.previewAsset!,
                              fit:
                                  item.type == KapiCosmeticType.centerpiece
                                      ? BoxFit.contain
                                      : BoxFit.cover,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, _, _) => _emojiPreview(item),
                            ),
                          )
                        else if (item.type == KapiCosmeticType.dice)
                          _dicePreview(item)
                        else if (item.type == KapiCosmeticType.handTray)
                          _handTrayPreview(item)
                        else
                          _emojiPreview(item),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0x33000000)],
                              stops: [0.58, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 6,
                          top: 6,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  equipped
                                      ? const Color(0xFFE7C778)
                                      : owned
                                      ? const Color(0xDD184E72)
                                      : const Color(0xCC08131E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    equipped
                                        ? _champagneLight
                                        : Colors.white.withValues(alpha: .22),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  equipped
                                      ? Icons.check_circle_rounded
                                      : owned
                                      ? Icons.inventory_2_rounded
                                      : Icons.lock_open_rounded,
                                  color: equipped ? _ink : Colors.white,
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  equipped
                                      ? (_isSpanish ? 'EN USO' : 'ACTIVE')
                                      : owned
                                      ? (_isSpanish ? 'TUYO' : 'OWNED')
                                      : (_isSpanish ? 'NUEVO' : 'NEW'),
                                  style: TextStyle(
                                    color: equipped ? _ink : Colors.white,
                                    fontSize: 7,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (item.exclusive)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF541625),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: _champagne),
                              ),
                              child: Text(
                                _isSpanish ? 'EXCLUSIVO' : 'EXCLUSIVE',
                                style: const TextStyle(
                                  color: _champagneLight,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.nameFor(Localizations.localeOf(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (equipped)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: _champagneLight,
                        size: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: OutlinedButton(
                    onPressed: action,
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                          equipped
                              ? const Color(0xFF262116)
                              : owned
                              ? const Color(0xFF122B43)
                              : canBuy
                              ? const Color(0xFF102E2B)
                              : const Color(0xFF19232D),
                      foregroundColor:
                          equipped ? _champagneLight : Colors.white,
                      disabledBackgroundColor: const Color(0xFF262116),
                      disabledForegroundColor: _champagneLight,
                      side: BorderSide(color: actionColor, width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: FittedBox(
                      child:
                          equipped || owned
                              ? Text(
                                equipped
                                    ? (_isSpanish ? 'Equipado' : 'Equipped')
                                    : (_isSpanish ? 'Usar' : 'Use'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                              : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${item.price}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.monetization_on_rounded,
                                    color: Color(0xFFE6C66E),
                                    size: 17,
                                  ),
                                ],
                              ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _activateItem(
    KapiCosmeticsService store,
    KapiCosmeticItem item,
  ) async {
    if (!store.owns(item)) {
      final bought = await store.purchase(item);
      if (!bought || !mounted) {
        if (mounted) _notEnough();
        return;
      }
    }
    await store.equip(item);
  }

  Widget _emojiPreview(KapiCosmeticItem item) {
    final isFlag = item.type == KapiCosmeticType.flag;
    return Center(
      child: Container(
        width: isFlag ? 68 : 58,
        height: isFlag ? 68 : 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xAA07111B),
          border: Border.all(
            color: item.secondary.withValues(alpha: .8),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x77000000), blurRadius: 12),
          ],
        ),
        child: Text(item.emoji, style: TextStyle(fontSize: isFlag ? 36 : 32)),
      ),
    );
  }

  Widget _handTrayPreview(KapiCosmeticItem item) {
    final dark = item.primary.computeLuminance() < .28;
    final tileColor = dark ? const Color(0xFFFFF2D2) : const Color(0xFF17212B);
    final pipColor = dark ? const Color(0xFF111318) : Colors.white;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [item.primary, item.secondary.withValues(alpha: .72)],
          ),
          border: Border.all(
            color: item.secondary.withValues(alpha: .9),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            3,
            (index) => Container(
              width: 24,
              height: 48,
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: item.secondary.withValues(alpha: .55),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _trayPips(index + 1, pipColor),
                  Container(height: 1, color: pipColor.withValues(alpha: .4)),
                  _trayPips(3 - index, pipColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _trayPips(int count, Color color) {
    final pipCount = count.clamp(1, 3).toInt();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        pipCount,
        (_) => Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _dicePreview(KapiCosmeticItem item) {
    return Center(
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: item.primary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.secondary.withValues(alpha: .72),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 13,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              for (final alignment in const <Alignment>[
                Alignment.topLeft,
                Alignment.topRight,
                Alignment.center,
                Alignment.bottomLeft,
                Alignment.bottomRight,
              ])
                Align(
                  alignment: alignment,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: item.secondary,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(color: Color(0x55000000), blurRadius: 2),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCoinPacks() async {
    if (!await _ensureCoinAccount()) return;
    if (!mounted) return;
    final premium = context.read<PremiumNotifier>();
    if (!premium.isLoading && premium.coinProducts.isEmpty) {
      await premium.loadProducts();
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Consumer2<PremiumNotifier, KapiCosmeticsService>(
          builder: (context, premium, store, _) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .88,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF152A3B), Color(0xFF07111B)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: _champagne, width: 1.4)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF251E13),
                            shape: BoxShape.circle,
                            border: Border.all(color: _champagne, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.monetization_on_rounded,
                            color: _champagneLight,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isSpanish
                                    ? 'Comprar Kapi Coins'
                                    : 'Buy Kapi Coins',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                _isSpanish
                                    ? 'Saldo: ${store.balance} monedas'
                                    : 'Balance: ${store.balance} coins',
                                style: const TextStyle(
                                  color: _champagneLight,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          tooltip: _isSpanish ? 'Cerrar' : 'Close',
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final spacing = constraints.maxWidth < 350 ? 8.0 : 12.0;
                        final width = (constraints.maxWidth - spacing) / 2;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            for (final pack in PremiumNotifier.coinPacks)
                              SizedBox(
                                width: width,
                                child: _coinPackCard(premium, pack),
                              ),
                          ],
                        );
                      },
                    ),
                    if (premium.isLoading) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(
                        color: _champagne,
                        backgroundColor: Color(0x332FBAAA),
                      ),
                    ],
                    if (premium.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _isSpanish
                            ? 'Algunos paquetes todavía están pendientes de activación en la tienda.'
                            : 'Some packs are still awaiting store activation.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFB7BF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _isSpanish
                                ? 'Compra segura procesada por Apple o Google. Solo artículos cosméticos.'
                                : 'Secure purchase processed by Apple or Google. Cosmetic items only.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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

  Widget _coinPackCard(PremiumNotifier premium, KapiCoinPack pack) {
    final product = premium.productForCoinPack(pack);
    final price = product?.price ?? pack.fallbackPrice;
    final badge = _isSpanish ? pack.badgeEs : pack.badgeEn;
    final highlighted = badge != null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              highlighted
                  ? const [Color(0xFF243A47), Color(0xFF102A2B)]
                  : const [Color(0xFF172A3B), Color(0xFF101D29)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted ? _champagne : const Color(0xFF405263),
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 22,
            child:
                badge == null
                    ? const SizedBox.shrink()
                    : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF541625),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _champagne),
                      ),
                      child: FittedBox(
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: _champagneLight,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
          ),
          const SizedBox(height: 5),
          const Icon(
            Icons.monetization_on_rounded,
            color: Color(0xFFE6C66E),
            size: 34,
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              '${pack.coins}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            _isSpanish ? 'Kapi Coins' : 'Kapi Coins',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: FilledButton(
              onPressed: premium.isLoading ? null : () => _buyCoinPack(pack),
              style: FilledButton.styleFrom(
                backgroundColor:
                    highlighted
                        ? const Color(0xFF8B2637)
                        : const Color(0xFF153B37),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF24313B),
                side: BorderSide(
                  color: highlighted ? _champagne : _teal,
                  width: 1.2,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: FittedBox(
                child: Text(
                  price,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buyCoinPack(KapiCoinPack pack) async {
    if (!await _ensureCoinAccount()) return;
    if (!mounted) return;
    final premium = context.read<PremiumNotifier>();
    if (premium.productForCoinPack(pack) == null) {
      await premium.loadProducts();
    }
    if (!mounted) return;

    if (!premium.canBuyCoins || premium.productForCoinPack(pack) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSpanish
                ? 'Este paquete está pendiente de activación en la tienda.'
                : 'This pack is awaiting store activation.',
          ),
        ),
      );
      return;
    }

    final started = await premium.buyCoinPack(pack);
    if (!mounted || started) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSpanish
              ? 'No se pudo iniciar la compra. Inténtalo nuevamente.'
              : 'The purchase could not be started. Please try again.',
        ),
      ),
    );
  }

  Future<bool> _ensureCoinAccount() async {
    final accountCheck = widget.ensureCoinAccount;
    if (accountCheck != null) return accountCheck(context);

    final account = PlayerAccountService.instance;
    if (account.canPurchaseCoins) return true;

    final protected = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        settings: const RouteSettings(name: '/protect-kapi-coins'),
        builder:
            (_) => const PlayerAccountScreen(
              purchaseGate: true,
              returnOnSuccess: true,
            ),
      ),
    );
    if (!mounted) return false;

    final ready =
        protected == true && PlayerAccountService.instance.canPurchaseCoins;
    if (!ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSpanish
                ? 'Registra y verifica tu correo antes de comprar Kapi Coins.'
                : 'Register and verify your email before buying Kapi Coins.',
          ),
        ),
      );
    }
    return ready;
  }

  void _notEnough() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSpanish
              ? 'No tienes suficientes Kapi Coins.'
              : 'Not enough Kapi Coins.',
        ),
      ),
    );
  }

  Future<void> _addTestCoins(KapiCosmeticsService store) async {
    final added = await store.addTestCoins();
    if (!mounted || !added) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSpanish
              ? 'Prueba: se añadieron 500 Kapi Coins.'
              : 'Test: 500 Kapi Coins added.',
        ),
      ),
    );
  }
}
