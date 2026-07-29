import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/kapi_cosmetics_service.dart';
import '../services/player_account_service.dart';
import '../widgets/anchored_adaptive_banner_ad.dart';
import 'domino_player_profile.dart';

class PlayerAccountScreen extends StatefulWidget {
  const PlayerAccountScreen({
    super.key,
    this.recoverOnly = false,
    this.purchaseGate = false,
    this.returnOnSuccess = false,
  });

  final bool recoverOnly;
  final bool purchaseGate;
  final bool returnOnSuccess;

  @override
  State<PlayerAccountScreen> createState() => _PlayerAccountScreenState();
}

class _PlayerAccountScreenState extends State<PlayerAccountScreen> {
  static const _burgundy = Color(0xFF720B09);
  static const _navy = Color(0xFF071524);
  static const _panel = Color(0xEE171C24);
  static const _gold = Color(0xFFFFD36A);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  DominoPlayerProfile? _profile;
  bool _working = false;
  bool _createEmailAccount = true;
  bool _obscurePassword = true;

  bool get _spanish => Localizations.localeOf(context).languageCode == 'es';
  bool get _isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    _createEmailAccount = !widget.recoverOnly;
    _reload();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final profile = await DominoPlayerProfile.load();
    final email = PlayerAccountService.instance.accountEmail;
    if (!mounted) return;
    setState(() {
      _profile = profile;
      if (email != null && _emailController.text.isEmpty) {
        _emailController.text = email;
      }
    });
  }

  Future<void> _finishAccount(PlayerAccountResult result) async {
    await KapiCosmeticsService.instance.connectAuthenticatedAccount(
      recovered: result.recovered,
    );
    if (!mounted) return;
    setState(() => _profile = result.profile);
    final account = PlayerAccountService.instance;
    if (widget.returnOnSuccess && account.canPurchaseCoins) {
      Navigator.pop(context, true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 7),
        content: Text(
          account.requiresEmailVerification
              ? (_spanish
                  ? 'Te enviamos un correo de verificación. Si no aparece en tu bandeja de entrada, revisa Spam o Correo no deseado.'
                  : 'We sent you a verification email. If it is not in your inbox, check Spam or Junk.')
              : result.recovered
              ? (_spanish
                  ? 'Cuenta recuperada. Tus Kapi Coins y ranking ya están sincronizados.'
                  : 'Account recovered. Your Kapi Coins and ranking are now synced.')
              : (_spanish
                  ? 'Cuenta protegida. Tus Kapi Coins y ranking se guardarán aquí.'
                  : 'Account protected. Your Kapi Coins and ranking will be saved here.'),
        ),
      ),
    );
  }

  Future<void> _use(PlayerAccountProvider provider) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final result = await PlayerAccountService.instance.protectOrRecover(
        provider,
        createIfMissing: !widget.recoverOnly,
      );
      await _finishAccount(result);
    } on PlayerAccountNotFoundException {
      if (mounted) {
        _showError(
          _spanish
              ? 'Esta cuenta no tiene un perfil protegido.'
              : 'This account does not have a protected profile.',
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(_firebaseMessage(error));
    } catch (error) {
      if (!mounted) return;
      if (!error.toString().toLowerCase().contains('cancel')) {
        _showError(
          _spanish
              ? 'No se pudo conectar la cuenta. Inténtalo otra vez.'
              : 'Could not connect the account. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _useEmail() async {
    if (_working) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!email.contains('@') || !email.contains('.')) {
      _showError(
        _spanish ? 'Escribe un correo válido.' : 'Enter a valid email.',
      );
      return;
    }
    if (password.length < 6) {
      _showError(
        _spanish
            ? 'La contraseña debe tener por lo menos 6 caracteres.'
            : 'Password must contain at least 6 characters.',
      );
      return;
    }
    setState(() => _working = true);
    try {
      final service = PlayerAccountService.instance;
      final result =
          _createEmailAccount
              ? await service.registerWithEmail(
                email: email,
                password: password,
              )
              : await service.signInWithEmail(
                email: email,
                password: password,
                createIfMissing: !widget.recoverOnly,
              );
      await _finishAccount(result);
    } on PlayerAccountNotFoundException {
      if (mounted) {
        _showError(
          _spanish
              ? 'Ese correo no tiene un perfil de Kapi Note guardado.'
              : 'That email has no saved Kapi Note profile.',
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(_firebaseMessage(error));
    } catch (_) {
      if (mounted) {
        _showError(
          _spanish
              ? 'No se pudo conectar el correo. Inténtalo otra vez.'
              : 'Could not connect the email. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _checkVerification() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final verified =
          await PlayerAccountService.instance.reloadEmailVerification();
      if (!mounted) return;
      setState(() {});
      if (verified) {
        await PlayerAccountService.instance.syncCurrentProfile();
        if (!mounted) return;
        if (widget.returnOnSuccess) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _spanish
                    ? 'Correo verificado. Tu cuenta y monedas están protegidas.'
                    : 'Email verified. Your account and coins are protected.',
              ),
            ),
          );
        }
      } else {
        _showError(
          _spanish
              ? 'Todavía no aparece verificado. Abre el enlace del correo primero.'
              : 'Not verified yet. Open the link in your email first.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _resendVerification() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await PlayerAccountService.instance.resendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 7),
          content: Text(
            _spanish
                ? 'Enviamos otro correo de verificación. Si no aparece, revisa Spam o Correo no deseado.'
                : 'Another verification email was sent. If it does not appear, check Spam or Junk.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(_firebaseMessage(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_working) return;
    final email = _emailController.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      _showError(
        _spanish
            ? 'Escribe primero el correo de tu cuenta Kapi Note.'
            : 'Enter your Kapi Note account email first.',
      );
      return;
    }
    setState(() => _working = true);
    try {
      await PlayerAccountService.instance.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            _spanish
                ? 'Te enviamos un enlace para cambiar tu contraseña. Si no aparece, revisa Spam o Correo no deseado.'
                : 'We sent you a link to reset your password. If it does not appear, check Spam or Junk.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(_firebaseMessage(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _firebaseMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' =>
        _spanish ? 'El correo no es válido.' : 'The email is not valid.',
      'weak-password' =>
        _spanish
            ? 'Usa una contraseña más segura.'
            : 'Use a stronger password.',
      'email-already-in-use' =>
        _spanish
            ? 'Ese correo ya está registrado. Usa “Entrar”.'
            : 'That email is already registered. Use “Sign in”.',
      'invalid-credential' || 'wrong-password' || 'user-not-found' =>
        _spanish
            ? 'Correo o contraseña de Kapi Note incorrectos.'
            : 'Incorrect Kapi Note email or password.',
      'too-many-requests' =>
        _spanish
            ? 'Demasiados intentos. Espera un momento.'
            : 'Too many attempts. Wait a moment.',
      'account-exists-with-different-credential' =>
        _spanish
            ? 'Este correo ya usa otro método de acceso.'
            : 'This email already uses another sign-in method.',
      'operation-not-allowed' =>
        _spanish
            ? 'El acceso por correo todavía no está activado en Firebase.'
            : 'Email sign-in is not enabled in Firebase yet.',
      _ =>
        _spanish
            ? 'No se pudo conectar la cuenta (${error.code}).'
            : 'Could not connect the account (${error.code}).',
    };
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB3261E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = PlayerAccountService.instance;
    final protected = account.isProtected;
    final profile = _profile;
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        backgroundColor: _navy,
        appBar: AppBar(
          title: Text(
            widget.purchaseGate
                ? (_spanish ? 'Protege tus monedas' : 'Protect your coins')
                : (_spanish ? 'Cuenta Kapi' : 'Kapi account'),
          ),
          centerTitle: true,
          backgroundColor: _burgundy,
          foregroundColor: Colors.white,
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_burgundy, Color(0xFF24171D), _navy],
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _gold.withValues(alpha: 0.7)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: _gold,
                        size: 46,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        profile?.publicId ?? '...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        protected
                            ? '${account.providerLabel ?? 'Kapi'} · ${account.accountEmail ?? (_spanish ? 'Cuenta protegida' : 'Protected account')}'
                            : (_spanish
                                ? 'Regístrate para guardar y recuperar tu ranking y Kapi Coins, y comprar monedas de forma segura.'
                                : 'Register to save and recover your ranking and Kapi Coins, and purchase coins securely.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFD7D9DF),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!protected) ...[
                  _buildEmailCard(),
                  if (!_isMacOS) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Colors.white24)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            _spanish ? 'o continúa con' : 'or continue with',
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ),
                        const Expanded(child: Divider(color: Colors.white24)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (account.providerAvailable(PlayerAccountProvider.apple))
                      _AccountButton(
                        icon: Icons.apple,
                        label:
                            _spanish
                                ? 'Continuar con Apple'
                                : 'Continue with Apple',
                        onTap:
                            _working
                                ? null
                                : () => _use(PlayerAccountProvider.apple),
                      ),
                    if (account.providerAvailable(PlayerAccountProvider.apple))
                      const SizedBox(height: 10),
                    _AccountButton(
                      icon: Icons.g_mobiledata_rounded,
                      label:
                          _spanish
                              ? 'Continuar con Google'
                              : 'Continue with Google',
                      onTap:
                          _working
                              ? null
                              : () => _use(PlayerAccountProvider.google),
                    ),
                  ],
                ] else if (account.requiresEmailVerification) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF342516),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _gold),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.mark_email_unread_rounded,
                          color: _gold,
                          size: 38,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _spanish
                              ? 'Verifica tu correo antes de comprar Kapi Coins.'
                              : 'Verify your email before buying Kapi Coins.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _spanish
                              ? 'Si no ves el mensaje, revisa las carpetas Spam o Correo no deseado.'
                              : 'If you do not see the message, check your Spam or Junk folders.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFE5CFA5),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _AccountButton(
                          icon: Icons.verified_rounded,
                          label:
                              _spanish
                                  ? 'Ya verifiqué mi correo'
                                  : 'I verified my email',
                          onTap: _working ? null : _checkVerification,
                        ),
                        TextButton(
                          onPressed: _working ? null : _resendVerification,
                          child: Text(
                            _spanish
                                ? 'Reenviar verificación'
                                : 'Resend verification',
                            style: const TextStyle(color: _gold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  _AccountButton(
                    icon: Icons.cloud_done_rounded,
                    label:
                        _spanish
                            ? 'Ranking y monedas protegidos'
                            : 'Ranking and coins protected',
                    onTap:
                        widget.returnOnSuccess
                            ? () => Navigator.pop(context, true)
                            : _syncNow,
                  ),
                if (_working) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator(color: _gold)),
                ],
                const SizedBox(height: 18),
                Text(
                  _spanish
                      ? 'Tu correo es privado y nunca se muestra a otros jugadores.'
                      : 'Your email is private and is never shown to other players.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFBCC1C9)),
                ),
                const SizedBox(height: 18),
                const AnchoredAdaptiveBannerAd(
                  adUnitId: 'ca-app-pub-8588489900323524/9168815834',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _createEmailAccount
                ? (_spanish ? 'Crear cuenta con email' : 'Create email account')
                : (_spanish ? 'Entrar con email' : 'Sign in with email'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isMacOS
                ? (_spanish
                    ? 'Crea o inicia sesión con el correo de tu cuenta Kapi Note.'
                    : 'Create or sign in with your Kapi Note account email.')
                : (_spanish
                    ? 'Estos campos son para una cuenta Kapi Note. Para entrar con tu cuenta de iCloud, usa “Continuar con Apple” abajo.'
                    : 'These fields are for a Kapi Note account. To sign in with your iCloud account, use “Continue with Apple” below.'),
            style: const TextStyle(
              color: Color(0xFFBCC1C9),
              height: 1.3,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              labelText: _spanish ? 'Correo electrónico' : 'Email',
              prefixIcon: const Icon(Icons.email_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            onSubmitted: (_) => _useEmail(),
            decoration: InputDecoration(
              labelText: _spanish ? 'Contraseña' : 'Password',
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                onPressed:
                    () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AccountButton(
            icon:
                _createEmailAccount
                    ? Icons.person_add_alt_1_rounded
                    : Icons.login_rounded,
            label:
                _createEmailAccount
                    ? (_spanish ? 'Registrarme' : 'Register')
                    : (_spanish ? 'Entrar' : 'Sign in'),
            onTap: _working ? null : _useEmail,
          ),
          if (!_createEmailAccount)
            TextButton.icon(
              onPressed: _working ? null : _resetPassword,
              icon: const Icon(Icons.key_rounded, size: 18),
              label: Text(
                _spanish
                    ? '¿Olvidaste tu contraseña?'
                    : 'Forgot your password?',
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          TextButton(
            onPressed:
                _working
                    ? null
                    : () => setState(
                      () => _createEmailAccount = !_createEmailAccount,
                    ),
            child: Text(
              _createEmailAccount
                  ? (_spanish
                      ? 'Ya tengo cuenta · Entrar'
                      : 'I have an account · Sign in')
                  : (_spanish
                      ? 'Crear una cuenta nueva'
                      : 'Create a new account'),
              style: const TextStyle(color: _gold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncNow() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await PlayerAccountService.instance.syncCurrentProfile();
      await KapiCosmeticsService.instance.connectAuthenticatedAccount(
        recovered: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _spanish
                ? 'Perfil y monedas sincronizados.'
                : 'Profile and coins synced.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 25),
        label: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFF13A37),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFFFD36A)),
          ),
        ),
      ),
    );
  }
}
