import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

@immutable
class OnlineVersionStatus {
  const OnlineVersionStatus({
    required this.currentVersion,
    required this.requiredVersion,
    required this.storeUrl,
    required this.isTestMode,
  });

  final String currentVersion;
  final String requiredVersion;
  final String storeUrl;
  final bool isTestMode;

  bool get requiresUpdate {
    final current = _versionParts(currentVersion);
    final required = _versionParts(requiredVersion);
    final length =
        current.length > required.length ? current.length : required.length;
    for (var index = 0; index < length; index++) {
      final currentPart = index < current.length ? current[index] : 0;
      final requiredPart = index < required.length ? required[index] : 0;
      if (currentPart < requiredPart) return true;
      if (currentPart > requiredPart) return false;
    }
    return false;
  }

  static List<int> _versionParts(String value) =>
      value
          .split(RegExp(r'[^0-9]+'))
          .where((part) => part.isNotEmpty)
          .map((part) => int.tryParse(part) ?? 0)
          .toList();
}

class OnlineVersionService {
  OnlineVersionService._();

  static final instance = OnlineVersionService._();

  static const currentRequiredVersion = '5.0.153';
  static const _testRequiredVersion = String.fromEnvironment(
    'KAPI_TEST_REQUIRED_ONLINE_VERSION',
  );
  static const _androidUrl =
      'https://play.google.com/store/apps/details?id=com.liisgo.kapi.note&hl=en_US';
  static const _appleUrl =
      'https://apps.apple.com/us/app/kapi-note/id6752557170';
  // This remains the public fallback until Kapi Note has its Microsoft Store
  // product page. Partner Center can override it through Remote Config.
  static const _windowsUrl = 'https://liisgo.com/#/apps/KapiNote';

  OnlineVersionStatus? _cachedStatus;

  Future<OnlineVersionStatus> check({bool refresh = false}) async {
    if (!refresh && _cachedStatus != null) return _cachedStatus!;

    final package = await PackageInfo.fromPlatform();
    final remote = FirebaseRemoteConfig.instance;
    var requiredVersion = currentRequiredVersion;
    var storeUrl = _defaultStoreUrl;

    try {
      await remote.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 8),
          minimumFetchInterval: const Duration(minutes: 5),
        ),
      );
      await remote.setDefaults(const {
        'required_online_android_version': currentRequiredVersion,
        'required_online_ios_version': currentRequiredVersion,
        'required_online_macos_version': currentRequiredVersion,
        'required_online_windows_version': currentRequiredVersion,
        'android_store_url': _androidUrl,
        'ios_store_url': _appleUrl,
        'macos_store_url': _appleUrl,
        'windows_store_url': _windowsUrl,
      });
      await remote.fetchAndActivate();
      requiredVersion = remote.getString(_requiredVersionKey).trim();
      storeUrl = remote.getString(_storeUrlKey).trim();
    } catch (_) {
      // The bundled requirement keeps incompatible clients apart even when
      // Remote Config is temporarily unavailable.
    }

    if (requiredVersion.isEmpty) requiredVersion = currentRequiredVersion;
    if (_testRequiredVersion.trim().isNotEmpty) {
      requiredVersion = _testRequiredVersion.trim();
    }
    if (storeUrl.isEmpty) storeUrl = _defaultStoreUrl;

    return _cachedStatus = OnlineVersionStatus(
      currentVersion: package.version,
      requiredVersion: requiredVersion,
      storeUrl: storeUrl,
      isTestMode: _testRequiredVersion.trim().isNotEmpty,
    );
  }

  String get _requiredVersionKey {
    if (!kIsWeb && Platform.isIOS) return 'required_online_ios_version';
    if (!kIsWeb && Platform.isMacOS) return 'required_online_macos_version';
    if (!kIsWeb && Platform.isWindows) {
      return 'required_online_windows_version';
    }
    return 'required_online_android_version';
  }

  String get _storeUrlKey {
    if (!kIsWeb && Platform.isIOS) return 'ios_store_url';
    if (!kIsWeb && Platform.isMacOS) return 'macos_store_url';
    if (!kIsWeb && Platform.isWindows) return 'windows_store_url';
    return 'android_store_url';
  }

  String get _defaultStoreUrl {
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) return _appleUrl;
    if (!kIsWeb && Platform.isWindows) return _windowsUrl;
    return _androidUrl;
  }
}

Future<bool> _openStore(String storeUrl) async {
  if (!kIsWeb && Platform.isIOS) {
    final appStoreUri = Uri.parse(
      'itms-apps://itunes.apple.com/app/id6752557170',
    );
    try {
      if (await launchUrl(appStoreUri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      // Fall back to the public App Store page below.
    }
  }
  if (!kIsWeb && Platform.isAndroid) {
    final playStoreUri = Uri.parse('market://details?id=com.liisgo.kapi.note');
    try {
      if (await launchUrl(playStoreUri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      // Fall back to the public Google Play page below.
    }
  }
  if (!kIsWeb && Platform.isMacOS) {
    final macAppStoreUri = Uri.parse(
      'macappstore://itunes.apple.com/app/id6752557170',
    );
    try {
      if (await launchUrl(
        macAppStoreUri,
        mode: LaunchMode.externalApplication,
      )) {
        return true;
      }
    } catch (_) {
      // Fall back to the public Mac App Store page below.
    }
  }
  final uri = Uri.parse(storeUrl);
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
  } catch (_) {
    // Some simulators cannot resolve the external App Store application.
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.platformDefault);
  } catch (_) {
    return false;
  }
}

Future<bool> showOnlineVersionDialog(
  BuildContext context,
  OnlineVersionStatus status, {
  required bool allowOffline,
}) async {
  final spanish = Localizations.localeOf(context).languageCode == 'es';
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: allowOffline,
    barrierColor: const Color(0xDD02060B),
    builder:
        (dialogContext) => PopScope(
          canPop: allowOffline,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF20394A), Color(0xFF071521)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFFFFD36B),
                    width: 1.8,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xAA000000),
                      blurRadius: 32,
                      offset: Offset(0, 16),
                    ),
                    BoxShadow(color: Color(0x5563E6FF), blurRadius: 28),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: spanish ? 'Cerrar' : 'Close',
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white,
                        iconSize: 30,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B2637),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFD36B),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.system_update_alt_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      spanish ? 'Actualización necesaria' : 'Update required',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      spanish
                          ? 'Para jugar online, todos deben tener la misma versión de Kapi Note.'
                          : 'Everyone must have the same Kapi Note version to play online.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${spanish ? 'Tu versión' : 'Your version'}: '
                      '${status.currentVersion}  •  '
                      '${spanish ? 'Necesaria' : 'Required'}: '
                      '${status.requiredVersion}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFFFD36B),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final opened = await _openStore(status.storeUrl);
                          if (!opened && dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  spanish
                                      ? 'No se pudo abrir la tienda. Inténtalo en un dispositivo real.'
                                      : 'The store could not be opened. Try it on a real device.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.download_rounded),
                        label: Text(
                          spanish ? 'Actualizar ahora' : 'Update now',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                    if (allowOffline) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text(
                          spanish
                              ? 'Continuar sin jugar online'
                              : 'Continue without online play',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
  );
  return result ?? false;
}
