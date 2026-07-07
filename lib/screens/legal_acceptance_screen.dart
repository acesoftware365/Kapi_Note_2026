import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../legal/legal_content.dart';
import '../legal_acceptance_notifier.dart';

class LegalAcceptanceScreen extends StatefulWidget {
  const LegalAcceptanceScreen({super.key});

  @override
  State<LegalAcceptanceScreen> createState() => _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends State<LegalAcceptanceScreen> {
  bool _isChecked = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/image/background.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Color.fromARGB((255 * 0.48).round(), 0, 0, 0),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          Container(color: const Color(0xAA081524)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Card(
                    elevation: 10,
                    color: theme.cardColor.withValues(alpha: 0.94),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.privacy_tip_rounded,
                            color: theme.colorScheme.primary,
                            size: 42,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Before you continue',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Please review and accept the legal terms for Kapi Note.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 18),
                          _buildLegalLinks(context),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            value: _isChecked,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (value) {
                              setState(() {
                                _isChecked = value ?? false;
                              });
                            },
                            title: _AcceptanceText(onOpen: _showLegalSheet),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _continue,
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Continue'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalLinks(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed:
              () => _showLegalSheet(
                LegalContent.termsTitle,
                LegalContent.termsBody,
              ),
          icon: const Icon(Icons.description_rounded),
          label: const Text(LegalContent.termsTitle),
        ),
        OutlinedButton.icon(
          onPressed:
              () => _showLegalSheet(
                LegalContent.privacyTitle,
                LegalContent.privacyBody,
              ),
          icon: const Icon(Icons.lock_rounded),
          label: const Text(LegalContent.privacyTitle),
        ),
      ],
    );
  }

  Future<void> _continue() async {
    if (!_isChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please accept the Terms & Conditions and Privacy Policy to continue.',
          ),
        ),
      );
      return;
    }

    await context.read<LegalAcceptanceNotifier>().accept();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
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
}

class _AcceptanceText extends StatelessWidget {
  const _AcceptanceText({required this.onOpen});

  final void Function(String title, String body) onOpen;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final baseStyle = Theme.of(context).textTheme.bodyMedium;
    final linkStyle = baseStyle?.copyWith(
      color: color,
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.underline,
    );

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'I agree to the '),
          TextSpan(
            text: LegalContent.termsTitle,
            style: linkStyle,
            recognizer:
                TapGestureRecognizer()
                  ..onTap =
                      () => onOpen(
                        LegalContent.termsTitle,
                        LegalContent.termsBody,
                      ),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: LegalContent.privacyTitle,
            style: linkStyle,
            recognizer:
                TapGestureRecognizer()
                  ..onTap =
                      () => onOpen(
                        LegalContent.privacyTitle,
                        LegalContent.privacyBody,
                      ),
          ),
        ],
      ),
    );
  }
}
