import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';
import '../../data/sources/http_manga_source.dart';
import '../../data/sources/source_auth.dart';
import '../../data/sources/source_registry.dart';

// Allows the user to log in to a source that supports account auth.
// Route: /source-credentials/:sourceId
//
// Flow:
//   - User enters email + password → taps "Sign in"
//   - App calls source.login() → stores credentials + token in DB
//   - On 401 in any screen, SheepApp shows a dialog → user taps → pushed here
class SourceCredentialsScreen extends ConsumerStatefulWidget {
  const SourceCredentialsScreen({super.key, required this.sourceId});

  final String sourceId;

  @override
  ConsumerState<SourceCredentialsScreen> createState() =>
      _SourceCredentialsScreenState();
}

class _SourceCredentialsScreenState
    extends ConsumerState<SourceCredentialsScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  HttpMangaSource? get _source {
    final s = sourceById(widget.sourceId);
    return s is HttpMangaSource ? s : null;
  }

  bool get _hasAuth => _source is SourceAuth;

  Future<void> _signIn() async {
    final source = _source;
    if (source == null || source is! SourceAuth) return;
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in both fields.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final db = ref.read(databaseProvider);
    try {
      final auth = source as SourceAuth;
      await auth.login(source.client, email, password);
      // Persist credentials and token so they survive app restart.
      await db.saveCredentials(
        sourceId: widget.sourceId,
        username: email,
        password: password,
        extraJson: auth.tokenAsJson,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    final db = ref.read(databaseProvider);
    await db.clearCredentials(widget.sourceId);
    if (mounted) setState(() {});
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.toLowerCase().contains('unauthorized')) {
      return 'Wrong email or password.';
    }
    if (msg.contains('SocketException') || msg.contains('connection')) {
      return 'No internet connection.';
    }
    return 'Login failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final credsAsync = ref.watch(_credentialsProvider(widget.sourceId));

    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        backgroundColor: paper,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back, color: ink),
        ),
        title: const Text(
          'Source Login',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: ink,
          ),
        ),
      ),
      body: source == null || !_hasAuth
          ? const Center(
              child: Text(
                'This source does not require login.',
                style: TextStyle(fontFamily: fontMono, color: slate),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source header
                  Row(
                    children: [
                      SvgPicture.asset(
                        source.iconAsset,
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source.name,
                            style: const TextStyle(
                              fontFamily: fontDisplay,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: ink,
                            ),
                          ),
                          Text(
                            source.baseUrl.replaceFirst('https://', ''),
                            style: const TextStyle(
                              fontFamily: fontMono,
                              fontSize: 12,
                              color: slate,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // Login status
                  credsAsync.when(
                    data: (creds) => creds != null
                        ? _LoggedInBanner(
                            username: creds.username ?? '',
                            onSignOut: _signOut,
                          )
                        : _LoginForm(
                            emailCtrl: _emailCtrl,
                            passCtrl: _passCtrl,
                            obscure: _obscure,
                            loading: _loading,
                            error: _error,
                            onToggleObscure: () =>
                                setState(() => _obscure = !_obscure),
                            onSignIn: _signIn,
                          ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => _LoginForm(
                      emailCtrl: _emailCtrl,
                      passCtrl: _passCtrl,
                      obscure: _obscure,
                      loading: _loading,
                      error: _error,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      onSignIn: _signIn,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Provider for credentials of a specific source.
final _credentialsProvider =
    StreamProvider.autoDispose.family<SourceCredential?, String>(
  (ref, sourceId) => ref.watch(databaseProvider).watchCredentials(sourceId),
);

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _LoggedInBanner extends StatelessWidget {
  const _LoggedInBanner({
    required this.username,
    required this.onSignOut,
  });

  final String username;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: paper,
        border: Border.all(color: wool),
        borderRadius: BorderRadius.circular(radiusCard),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Logged in',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: ink,
                  ),
                ),
                Text(
                  username,
                  style: const TextStyle(
                    fontFamily: fontMono,
                    fontSize: 12,
                    color: slate,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onSignOut,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: wool,
                borderRadius: BorderRadius.circular(radiusCard),
              ),
              child: const Text(
                'Sign out',
                style: TextStyle(
                  fontFamily: fontMono,
                  fontSize: 12,
                  color: ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.onToggleObscure,
    required this.onSignIn,
  });

  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscure;
  final bool loading;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email
        const Text(
          'Email',
          style: TextStyle(
            fontFamily: fontMono,
            fontSize: 12,
            color: slate,
          ),
        ),
        const SizedBox(height: 6),
        _TextField(
          controller: emailCtrl,
          hint: 'your@email.com',
          keyboardType: TextInputType.emailAddress,
          obscure: false,
        ),
        const SizedBox(height: 16),
        // Password
        const Text(
          'Password',
          style: TextStyle(
            fontFamily: fontMono,
            fontSize: 12,
            color: slate,
          ),
        ),
        const SizedBox(height: 6),
        _TextField(
          controller: passCtrl,
          hint: '••••••••',
          obscure: obscure,
          suffix: GestureDetector(
            onTap: onToggleObscure,
            child: Icon(
              obscure ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: slate,
            ),
          ),
        ),
        // Error message
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            style: const TextStyle(
              fontFamily: fontMono,
              fontSize: 12,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
        const SizedBox(height: 24),
        // Sign in button
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: loading ? null : onSignIn,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: ink,
                borderRadius: BorderRadius.circular(radiusCard),
              ),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: paper,
                      ),
                    )
                  : const Text(
                      'Sign in',
                      style: TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: paper,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.hint,
    required this.obscure,
    this.keyboardType,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: paper,
        border: Border.all(color: wool),
        borderRadius: BorderRadius.circular(radiusCard),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontFamily: fontMono,
          fontSize: 14,
          color: ink,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontFamily: fontMono,
            fontSize: 14,
            color: slate,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: InputBorder.none,
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffix,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        ),
      ),
    );
  }
}
