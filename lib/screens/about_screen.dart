// lib/screens/about_screen.dart
import 'package:flutter/material.dart'; // Import generated localizations
import 'package:package_info_plus/package_info_plus.dart';
import '../l10n/app_localizations.dart';
import '../url_link/link_button.dart'; // Import font size notifier

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
                  //Privacy card ////////////////////////////////////////////////////////////////////////
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: Theme.of(context).cardColor.withOpacity(
                      0.9,
                    ), // Card background adapts to theme with slight transparency
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // Wrap content
                        children: [
                          Text(
                            appLocalizations.privacyPolicy,
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context)
                                    .textTheme
                                    .headlineLarge, // Adapt text color and size
                          ),
                          const SizedBox(height: 20),
                          Text(
                            appLocalizations.privacyPolicyTitle,
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context)
                                    .textTheme
                                    .bodyMedium, // Adapt text color and size
                          ),
                          const SizedBox(height: 10),
                          Text(
                            appLocalizations.privacyPolicyDescription,
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context)
                                    .textTheme
                                    .bodyMedium, // Adapt text color and size
                          ),
                          const SizedBox(height: 10),

                          ///TODO: add privacy policy button for link
                          Text(
                            appLocalizations.privacyGoogleLink,
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context)
                                    .textTheme
                                    .bodyMedium, // Adapt text color and size
                          ),
                          LinkButton(
                            text: appLocalizations.privacyGoogleLink,
                            url:
                                'https://policies.google.com/privacy?utm_source=chatgpt.com',
                          ),
                          const SizedBox(height: 10),
                          Text(
                            appLocalizations.privacyGoogleUseDataInApps,
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context)
                                    .textTheme
                                    .bodyMedium, // Adapt text color and size
                          ),
                          LinkButton(
                            text: appLocalizations.privacyGoogleUseDataInApps,
                            url:
                                'https://policies.google.com/technologies/partner-sites?utm_source=chatgpt.com',
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // About card
                  const SizedBox(height: 20),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: Theme.of(context).cardColor.withOpacity(
                      0.9,
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
                            url: 'https:www.liisgo.com',
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
}
