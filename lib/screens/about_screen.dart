// lib/screens/about_screen.dart
import 'package:flutter/material.dart'; // Import generated localizations
import 'package:package_info_plus/package_info_plus.dart';
import '../legal/legal_content.dart';
import '../l10n/app_localizations.dart';
import '../url_link/link_button.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations appLocalizations = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: appLocalizations.homeScreenTitle,
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/home');
            },
          ),
        ],
        // AppBar color will adapt based on theme
      ),
      body: Stack(
        children: [
          // Background Image (same as home screen)
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage(
                  'assets/image/background.png',
                ), // Your background image
                fit: BoxFit.cover, // Cover the entire container
                colorFilter: ColorFilter.mode(
                  Color.fromARGB(
                    (255 * 0.3).round(),
                    0,
                    0,
                    0,
                  ), // Match Home darken
                  BlendMode.darken, // Match Home
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
          // About content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildLegalCard(
                    context,
                    title: LegalContent.termsTitle,
                    icon: Icons.description_rounded,
                    body: LegalContent.termsBody,
                  ),
                  const SizedBox(height: 20),
                  _buildLegalCard(
                    context,
                    title: LegalContent.privacyTitle,
                    icon: Icons.lock_rounded,
                    body: LegalContent.privacyBody,
                  ),
                  const SizedBox(height: 30),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: Theme.of(context).cardColor.withValues(
                      alpha: 0.9,
                    ), // Card background adapts to theme with slight transparency
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // Wrap content
                        children: [
                          Text(
                            appLocalizations.about,
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context)
                                    .textTheme
                                    .headlineLarge, // Adapt text color and size
                          ),
                          const SizedBox(height: 20),
                          Text(
                            appLocalizations.aboutThisApp,
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context)
                                    .textTheme
                                    .bodyMedium, // Adapt text color and size
                          ),
                          const SizedBox(height: 10),
                          Text(
                            appLocalizations.aboutEnjoy,
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context)
                                    .textTheme
                                    .bodyMedium, // Adapt text color and size
                          ),

                          const SizedBox(height: 30),
                          LinkButton(
                            text: "www.liisgo.com".toUpperCase(),
                            url: 'https://www.liisgo.com',
                          ),
                          Text(
                            "LIISGO LLC",
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context)
                                    .textTheme
                                    .bodyMedium, // Adapt text color and size
                          ),
                          FutureBuilder<PackageInfo>(
                            future: PackageInfo.fromPlatform(),
                            builder: (context, snapshot) {
                              final versionText =
                                  snapshot.hasData
                                      ? 'Version: ${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                                      : 'Version';

                              return Text(
                                versionText,
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context)
                                        .textTheme
                                        .bodyMedium, // Adapt text color and size
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String body,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Theme.of(context).cardColor.withValues(alpha: 0.9),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.start,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
