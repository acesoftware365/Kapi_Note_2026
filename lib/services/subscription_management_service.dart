import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionManagementService {
  SubscriptionManagementService._();

  static const String _androidPackageName = 'com.liisgo.kapi.note';

  static Future<bool> openSubscriptionSettings({String? productId}) async {
    if (kIsWeb) return false;

    final Uri uri;
    if (Platform.isIOS) {
      uri = Uri.parse('https://apps.apple.com/account/subscriptions');
    } else if (Platform.isAndroid) {
      uri = Uri.https('play.google.com', '/store/account/subscriptions', {
        if (productId != null && productId.isNotEmpty) 'sku': productId,
        'package': _androidPackageName,
      });
    } else {
      return false;
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
