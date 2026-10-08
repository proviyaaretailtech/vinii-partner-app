import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/failure.dart';
import '../../l10n/failure_text.dart';
import '../../l10n/l10n.dart';
import '../theme/staff_theme.dart';

/// Sends Supabase's password-reset email. The confirmation never says
/// whether the email has an account.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await AppScope.of(context).session.sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
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
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: _sent
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.mark_email_read_outlined,
                      size: 48,
                      color: t.success,
                    ),
                    const SizedBox(height: 20),
                    Text(l.authResetSentTitle, style: text.headlineMedium),
                    const SizedBox(height: 10),
                    Text(
                      l.authResetSentBody(email: _email.text.trim()),
                      style: text.bodyLarge?.copyWith(
                        color: t.inkSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l.authBackToSignIn),
                      ),
                    ),
                  ],
                )
              : Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.authResetTitle, style: text.headlineMedium),
                      const SizedBox(height: 8),
                      Text(l.authResetIntro, style: text.bodyMedium),
                      const SizedBox(height: 24),
                      if (_failure != null) ...[
                        Text(
                          failureText(l, _failure!),
                          style: TextStyle(color: t.danger),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _email,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
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
                        onFieldSubmitted: (_) => _send(),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _send,
                        child: _busy
                            ? SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: t.onAccent,
                                ),
                              )
                            : Text(l.authSendResetLink),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
