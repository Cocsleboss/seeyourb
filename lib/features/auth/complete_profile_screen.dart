// §4.2 Compléter le profil: required before entering the app without a username.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';
import '../../ui/logo.dart';
import 'username_field.dart';
import '../../core/i18n.dart';
import '../../ui/language.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});
  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  late final TextEditingController _username;
  late final TextEditingController _name;
  DateTime? _birthday;
  UsernameStatus _status = UsernameStatus.idle;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(sessionProvider).profile;
    _name = TextEditingController(text: p?.displayName ?? '');
    _username = TextEditingController(text: suggestUsername(p?.displayName ?? p?.email));
    _birthday = p?.birthday;
  }

  @override
  void dispose() {
    _username.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final session = ref.read(sessionProvider);
    final updated = await guard(() => ref.read(apiProvider).updateProfile({
          'username': _username.text,
          'display_name': _name.text.trim().isEmpty ? _username.text : _name.text.trim(),
          'birthday': _birthday == null ? null : dayIso(_birthday!),
        }));
    if (mounted) setState(() => _busy = false);
    if (updated != null) session.setProfile(updated);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Align(alignment: Alignment.centerRight, child: LanguageButton()),
                const Center(child: SeeULogo(size: 64)),
                const SizedBox(height: 16),
                Text(tr.completeProfileTitle,
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c.text)),
                const SizedBox(height: 6),
                Text(tr.completeProfileSub,
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: c.textMuted)),
                const SizedBox(height: 24),
                UsernameField(controller: _username, onStatus: (s) => setState(() => _status = s)),
                LabeledField(
                  label: tr.displayName,
                  hint: tr.displayNameHint,
                  child: AppTextField(controller: _name, hint: tr.nameExample, maxLength: 60, textCapitalization: TextCapitalization.words),
                ),
                LabeledField(
                  label: tr.birthDate,
                  hint: tr.birthDateHint,
                  child: DateField(value: _birthday, last: today(), clearable: true, onChanged: (d) => setState(() => _birthday = d)),
                ),
                AppButton(tr.continueLabel,
                    size: ButtonSize.lg, full: true, loading: _busy, onPressed: _status == UsernameStatus.available ? _submit : null),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => ref.read(supabaseProvider).auth.signOut(),
                  child: Text(tr.signOut, style: TextStyle(color: c.brandText)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
