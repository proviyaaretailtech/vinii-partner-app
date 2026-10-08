import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/failure.dart';
import '../../l10n/failure_text.dart';
import '../../l10n/l10n.dart';
import '../boot/brand_mark.dart';
import '../settings/language_screen.dart';
import '../theme/staff_theme.dart';

/// Staff sign in with the email and password they already use for the POS.
/// There is no sign-up here: organizations add their staff from the OS.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _hide = true;
  bool _busy = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    // "You were signed out" etc. from the session.
    _failure = AppScope.of(context).session.bootFailure;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await AppScope.of(context).session.signIn(_email.text, _password.text);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _failure = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    final config = AppScope.of(context).config;
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The language can be chosen before anyone has signed in.
                      const Row(
                        children: [
                          BrandMark(size: 52, inverted: true),
                          Spacer(),
                          LanguageButton(),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(l.commonSignIn, style: text.headlineLarge),
                      const SizedBox(height: 8),
                      Text(l.authSignInIntro, style: text.bodyMedium),
                      const SizedBox(height: 28),
                      if (_failure != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: t.tint(t.danger),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: t.danger,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  failureText(l, _failure!),
                                  style: TextStyle(color: t.ink, height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.email,
                          AutofillHints.username,
                        ],
                        autocorrect: false,
                        enabled: !_busy,
                        decoration: InputDecoration(
                          labelText: l.commonEmail,
                          prefixIcon: const Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return l.authEmailRequired;
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(s)) {
                            return l.authEmailInvalid;
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        focusNode: _passwordFocus,
                        obscureText: _hide,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        enabled: !_busy,
                        decoration: InputDecoration(
                          labelText: l.commonPassword,
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _hide
                                ? l.authShowPassword
                                : l.authHidePassword,
                            icon: Icon(
                              _hide
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(() => _hide = !_hide),
                          ),
                        ),
                        validator: (v) =>
                            (v ?? '').isEmpty ? l.authPasswordRequired : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => context.push(Routes.resetPassword),
                          child: Text(l.authForgotPassword),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: t.onAccent,
                                ),
                              )
                            : Text(l.commonSignIn),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        l.authNoAccountNote,
                        textAlign: TextAlign.center,
                        style: text.bodySmall,
                      ),
                      if (config.appEnv != 'production') ...[
                        const SizedBox(height: 6),
                        Text(
                          // i18n-ignore: debug environment line
                          '${config.appEnv} · ${config.databaseHost}',
                          textAlign: TextAlign.center,
                          style: text.bodySmall?.copyWith(fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
