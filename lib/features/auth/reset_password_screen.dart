// "Nouveau mot de passe": opened from the reset email link (§4.1).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../ui/feedback.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';
import '../../ui/logo.dart';
import '../../core/i18n.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  bool get _valid => _p1.text.length >= 6 && _p1.text == _p2.text;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(supabaseProvider).auth.updateUser(UserAttributes(password: _p1.text));
      showToast(tr.passwordUpdated);
      ref.read(sessionProvider).endPasswordRecovery();
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Center(child: SeeULogo(size: 64)),
                const SizedBox(height: 16),
                Text(tr.newPassword,
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c.text)),
                const SizedBox(height: 24),
                if (!session.signedIn) ...[
                  InfoBox(tone: Tone.red, child: Text(tr.errLinkExpired)),
                  const SizedBox(height: 16),
                  AppButton(tr.backToLogin, variant: ButtonVariant.secondary, onPressed: () => context.go('/login')),
                ] else ...[
                  LabeledField(
                    label: tr.newPassword,
                    hint: tr.passwordMin,
                    child: AppTextField(controller: _p1, obscure: true, onChanged: (_) => setState(() {})),
                  ),
                  LabeledField(
                    label: tr.confirmPassword,
                    error: _p2.text.isNotEmpty && _p1.text != _p2.text ? tr.passwordsDiffer : null,
                    child: AppTextField(controller: _p2, obscure: true, onChanged: (_) => setState(() {})),
                  ),
                  AppButton(tr.save, size: ButtonSize.lg, full: true, loading: _busy, onPressed: _valid ? _submit : null),
                  if (_error != null) ...[const SizedBox(height: 14), InfoBox(tone: Tone.red, child: Text(_error!))],
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
