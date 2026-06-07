import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../l10n/app_localizations.dart';
import '../url_link/link_button.dart';

class AppFooter extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const AppFooter({
    super.key,
    this.padding = const EdgeInsets.only(bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle? textStyle = Theme.of(context).textTheme.bodySmall ??
        Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: padding,
      child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final String languageCode =
              Localizations.localeOf(context).languageCode;
          final String appTitle =
              AppLocalizations.of(context)?.appTitle ?? 'App';
          final String versionValue = snapshot.hasData
              ? '${snapshot.data!.version}+${snapshot.data!.buildNumber}'
              : '';
          final String subjectValue = '$appTitle need support';
          final String bodyValue = () {
            switch (languageCode) {
              case 'es':
                return 'Hola equipo de soporte,\n\n'
                    'Necesito ayuda con la app.\n'
                    'Version: $versionValue\n\n'
                    'Detalles del problema:\n'
                    '- \n';
              case 'pt':
                return 'Olá equipe de suporte,\n\n'
                    'Preciso de ajuda com o app.\n'
                    'Versão: $versionValue\n\n'
                    'Detalhes do problema:\n'
                    '- \n';
              case 'fr':
                return 'Bonjour équipe support,\n\n'
                    'J\'ai besoin d\'aide avec l\'app.\n'
                    'Version : $versionValue\n\n'
                    'Détails du problème :\n'
                    '- \n';
              case 'it':
                return 'Ciao team di supporto,\n\n'
                    'Ho bisogno di aiuto con l\'app.\n'
                    'Versione: $versionValue\n\n'
                    'Dettagli del problema:\n'
                    '- \n';
              case 'ru':
                return 'Здравствуйте, команда поддержки,\n\n'
                    'Мне нужна помощь с приложением.\n'
                    'Версия: $versionValue\n\n'
                    'Описание проблемы:\n'
                    '- \n';
              case 'ar':
                return 'مرحبًا فريق الدعم،\n\n'
                    'أحتاج مساعدة مع التطبيق.\n'
                    'الإصدار: $versionValue\n\n'
                    'تفاصيل المشكلة:\n'
                    '- \n';
              case 'hi':
                return 'नमस्ते सपोर्ट टीम,\n\n'
                    'मुझे ऐप में मदद चाहिए।\n'
                    'संस्करण: $versionValue\n\n'
                    'समस्या का विवरण:\n'
                    '- \n';
              case 'bn':
                return 'হ্যালো সাপোর্ট টিম,\n\n'
                    'আমি অ্যাপ নিয়ে সাহায্য চাই।\n'
                    'ভার্সন: $versionValue\n\n'
                    'সমস্যার বিবরণ:\n'
                    '- \n';
              case 'ur':
                return 'سلام سپورٹ ٹیم,\n\n'
                    'مجھے ایپ کے ساتھ مدد چاہیے۔\n'
                    'ورژن: $versionValue\n\n'
                    'مسئلے کی تفصیل:\n'
                    '- \n';
              case 'zh':
                return '你好，支持团队，\n\n'
                    '我需要应用方面的帮助。\n'
                    '版本：$versionValue\n\n'
                    '问题描述：\n'
                    '- \n';
              default:
                return 'Hello support team,\n\n'
                    'I need help with the app.\n'
                    'Version: $versionValue\n\n'
                    'Issue details:\n'
                    '- \n';
            }
          }();
          final String versionText = versionValue.isNotEmpty
              ? 'Version $versionValue'
              : 'Version';
          final emailLink = LinkButton(
            text: 'sales@liisgo.com',
            url:
                'mailto:sales@liisgo.com?subject=${Uri.encodeComponent(subjectValue)}&body=${Uri.encodeComponent(bodyValue)}',
            compact: true,
          );
          final siteLink = const LinkButton(
            text: 'www.liisgo.com',
            url: 'https://liisgo.com/',
            compact: true,
          );
          final companyText = Text(
            'LIISGO LCC',
            textAlign: TextAlign.center,
            style: textStyle,
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final bool wide = constraints.maxWidth >= 520;
              final versionWidget = Text(
                versionText,
                textAlign: TextAlign.center,
                style: textStyle,
              );

              if (wide) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    versionWidget,
                    const SizedBox(width: 10),
                    const Text('•'),
                    const SizedBox(width: 10),
                    emailLink,
                    const SizedBox(width: 10),
                    const Text('•'),
                    const SizedBox(width: 10),
                    siteLink,
                    const SizedBox(width: 10),
                    const Text('•'),
                    const SizedBox(width: 10),
                    companyText,
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  versionWidget,
                  const SizedBox(height: 2),
                  emailLink,
                  siteLink,
                  companyText,
                ],
              );
            },
          );
        },
      ),
    );
  }
}
