import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({
    super.key,
    this.padding = EdgeInsets.zero,
    this.color,
    this.fontSize = 11,
  });

  final EdgeInsetsGeometry padding;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }

          final info = snapshot.data!;
          return Text(
            'Version ${info.version}+${info.buildNumber}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color ?? Colors.white.withValues(alpha: 0.72),
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          );
        },
      ),
    );
  }
}
