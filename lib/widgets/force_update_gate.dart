import 'package:flutter/material.dart';

import '../services/online_version_service.dart';

class ForceUpdateGate extends StatefulWidget {
  final Widget child;

  const ForceUpdateGate({super.key, required this.child});

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate> {
  bool _messageShown = false;

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    final status = await OnlineVersionService.instance.check(refresh: true);
    if (!mounted) return;
    if (status.requiresUpdate && !_messageShown) {
      _messageShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showOnlineVersionDialog(context, status, allowOffline: true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
