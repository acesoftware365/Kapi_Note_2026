import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkButton extends StatelessWidget {
  final String text;
  final String url;
  final bool compact;

  const LinkButton({
    super.key,
    required this.text,
    required this.url,
    this.compact = false,
  });

  // Function to launch the URL
  Future<void> _launchUrl() async {
    if (!await launchUrl(Uri.parse(url))) {
      // You can add better error handling here, like a Snackbar
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: compact
          ? TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : null,
      onPressed: _launchUrl,
      child: Text(text),
    );
  }
}
