import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

class ForceUpdateGate extends StatefulWidget {
  final Widget child;

  const ForceUpdateGate({super.key, required this.child});

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate> {
  static const String _defaultMinimumVersion = '5.0.0';
  static const String _defaultAndroidUrl =
      'https://play.google.com/store/apps/details?id=com.liisgo.kapi.note&hl=en_US';
  static const String _defaultIosUrl =
      'https://apps.apple.com/us/app/kapi-note/id6752557170';

  bool? _needsUpdate;
  String _storeUrl = Platform.isIOS ? _defaultIosUrl : _defaultAndroidUrl;

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    final info = await PackageInfo.fromPlatform();
    final remoteConfig = FirebaseRemoteConfig.instance;
    String minimumVersion = _defaultMinimumVersion;
    String storeUrl = Platform.isIOS ? _defaultIosUrl : _defaultAndroidUrl;

    try {
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults(const {
        'minimum_android_version': _defaultMinimumVersion,
        'minimum_ios_version': _defaultMinimumVersion,
        'android_store_url': _defaultAndroidUrl,
        'ios_store_url': _defaultIosUrl,
      });
      await remoteConfig.fetchAndActivate();

      minimumVersion =
          Platform.isIOS
              ? remoteConfig.getString('minimum_ios_version')
              : remoteConfig.getString('minimum_android_version');
      storeUrl =
          Platform.isIOS
              ? remoteConfig.getString('ios_store_url')
              : remoteConfig.getString('android_store_url');
    } catch (_) {
      minimumVersion = _defaultMinimumVersion;
    }

    if (minimumVersion.trim().isEmpty) {
      minimumVersion = _defaultMinimumVersion;
    }
    if (storeUrl.trim().isEmpty) {
      storeUrl = Platform.isIOS ? _defaultIosUrl : _defaultAndroidUrl;
    }

    final bool needsUpdate = _isLowerVersion(info.version, minimumVersion);
    if (mounted) {
      setState(() {
        _needsUpdate = needsUpdate;
        _storeUrl = storeUrl;
      });
    }
  }

  bool _isLowerVersion(String current, String minimum) {
    List<int> parse(String v) =>
        v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final c = parse(current);
    final m = parse(minimum);
    final len = c.length > m.length ? c.length : m.length;
    for (int i = 0; i < len; i++) {
      final ci = i < c.length ? c[i] : 0;
      final mi = i < m.length ? m[i] : 0;
      if (ci != mi) return ci < mi;
    }
    return false;
  }

  Future<void> _openStore() async {
    final Uri uri = Uri.parse(_storeUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_needsUpdate != true) {
      return widget.child;
    }

    final appLocalizations = AppLocalizations.of(context)!;

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.7),
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        appLocalizations.forceUpdateTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        appLocalizations.forceUpdateMessage,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _openStore,
                          child: Text(appLocalizations.forceUpdateButton),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
