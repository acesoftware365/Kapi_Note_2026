import 'dart:io';

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
  static const String _minVersion = '5.0.0';
  static const String _androidUrl =
      'https://play.google.com/store/apps/details?id=com.liisgo.kapi.note&hl=en_US';
  static const String _iosUrl =
      'https://apps.apple.com/us/app/kapi-note/id6752557170';

  bool? _needsUpdate;

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    final info = await PackageInfo.fromPlatform();
    final bool needsUpdate = _isLowerVersion(info.version, _minVersion);
    if (mounted) {
      setState(() {
        _needsUpdate = needsUpdate;
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
    final Uri uri = Uri.parse(Platform.isIOS ? _iosUrl : _androidUrl);
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
            color: Colors.black.withOpacity(0.7),
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
