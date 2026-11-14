// §4.1 Connexion / Inscription / Lien magique / Mot de passe oublié.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../core/errors.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/text.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';
import '../../ui/logo.dart';
import 'username_field.dart';

enum _Mode { login, signup, magic, forgot }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _Mode _mode = _Mode.login;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _username = TextEditingController();
  UsernameStatus _usernameStatus = UsernameStatus.idle;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;
  ({String title, String text})? _sent;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  String get _cleanEmail => _email.text.trim().toLowerCase();

  bool get _valid => switch (_mode) {
        _Mode.login => isValidEmail(_cleanEmail) && _password.text.isNotEmpty,
        _Mode.signup => isValidEmail(_cleanEmail) && _password.text.length >= 6 && _usernameStatus == UsernameStatus.available,
        _Mode.magic || _Mode.forgot => isValidEmail(_cleanEmail),
      };

  void _setMode(_Mode m) => setState(() {
        _mode = m;
        _error = null;
        _sent = null;
      });

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(supabaseProvider).auth;
    final email = _cleanEmail;
    try {
      switch (_mode) {
        case _Mode.login:
          await auth.signInWithPassword(email: email, password: _password.text);
        case _Mode.signup:
          final res = await auth.signUp(
            email: email,
            password: _password.text,
            emailRedirectTo: Config.authRedirect,
            data: {'username': _username.text, if (_name.text.trim().isNotEmpty) 'display_name': _name.text.trim()},
          );
          // Supabase returns a user without identities when the email is already registered.
          if (res.user != null && (res.user!.identities?.isEmpty ?? false)) {
            throw AppException('Un compte existe déjà avec cet email. Connectez-vous ou utilisez « Mot de passe oublié ».');
          }
          if (res.session == null) {
            _sent = (
              title: 'Vérifiez votre boîte mail',
              text: 'Un lien de confirmation a été envoyé à $email. Ouvrez-le pour activer votre compte (pensez aux spams).',
            );
          }
        case _Mode.magic:
          await auth.signInWithOtp(email: email, emailRedirectTo: Config.authRedirect);
          _sent = (title: 'Lien envoyé', text: 'Ouvrez le lien reçu à $email pour vous connecter (pensez aux spams).');
        case _Mode.forgot:
          await auth.resetPasswordForEmail(email, redirectTo: Config.authRedirect);
          _sent = (
            title: 'Email envoyé',
            text: 'Si un compte existe pour $email, vous recevrez un lien pour choisir un nouveau mot de passe.',
          );
      }
    } on AuthException catch (e) {
      _error = translateAuthError(e.message);
    } catch (e) {
      _error = errorMessage(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: SeeULogo(size: 76)),
                  const SizedBox(height: 14),
                  Text('SeeU', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: c.text)),
                  const SizedBox(height: 6),
                  Text(
                    "Ne plus oublier les personnes qu'on aimerait revoir.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: c.textMuted),
                  ),
                  const SizedBox(height: 28),
                  if (!Config.isConfigured) _configMissing(c) else _sent != null ? _sentCard(c) : _form(c),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _configMissing(AppColors c) => ErrorCard(
        error: AppException(
            'Configuration manquante : lancez l\'app avec --dart-define-from-file=config/env.json (SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY).'),
      );

  Widget _sentCard(AppColors c) => AppCard(
        child: Column(children: [
          Icon(LucideIcons.mailCheck, size: 40, color: c.brandText),
          const SizedBox(height: 12),
          Text(_sent!.title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 8),
          Text(_sent!.text, textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, fontSize: 15, height: 1.4)),
          const SizedBox(height: 18),
          AppButton('Retour', variant: ButtonVariant.secondary, icon: LucideIcons.arrowLeft, onPressed: () => _setMode(_Mode.login)),
        ]),
      );

  Widget _form(AppColors c) {
    final isAlt = _mode == _Mode.magic || _mode == _Mode.forgot;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isAlt)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: SegmentedControl<_Mode>(
                options: const [(_Mode.login, 'Connexion'), (_Mode.signup, 'Inscription')],
                value: _mode,
                onChanged: _setMode,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  IconButton(
                    onPressed: () => _setMode(_Mode.login),
                    icon: Icon(LucideIcons.chevronLeft, color: c.brandText),
                    tooltip: 'Retour',
                  ),
                  Text(_mode == _Mode.magic ? 'Lien magique' : 'Mot de passe oublié',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: c.text)),
                ]),
                Text(
                  _mode == _Mode.magic
                      ? 'Recevez un lien de connexion par email, sans mot de passe.'
                      : 'Indiquez votre email : vous recevrez un lien pour choisir un nouveau mot de passe.',
                  style: TextStyle(color: c.textMuted, fontSize: 15, height: 1.4),
                ),
              ]),
            ),
          if (_mode == _Mode.signup) ...[
            LabeledField(
              label: 'Prénom (nom affiché)',
              child: AppTextField(
                controller: _name,
                hint: 'Ex. Andrea',
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.givenName],
              ),
            ),
            UsernameField(controller: _username, onStatus: (s) => setState(() => _usernameStatus = s)),
          ],
          LabeledField(
            label: 'Email',
            required: true,
            child: AppTextField(
              controller: _email,
              hint: 'vous@exemple.com',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) => setState(() {}),
              textInputAction: isAlt ? TextInputAction.done : TextInputAction.next,
              onSubmitted: (_) => isAlt ? _submit() : null,
            ),
          ),
          if (!isAlt)
            LabeledField(
              label: 'Mot de passe',
              required: true,
              hint: _mode == _Mode.signup ? '6 caractères minimum' : null,
              child: AppTextField(
                controller: _password,
                obscure: !_showPassword,
                autofillHints: [_mode == _Mode.signup ? AutofillHints.newPassword : AutofillHints.password],
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                suffix: IconButton(
                  tooltip: _showPassword ? 'Masquer le mot de passe' : 'Afficher le mot de passe',
                  icon: Icon(_showPassword ? LucideIcons.eyeOff : LucideIcons.eye, size: 20, color: c.textMuted),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
          const SizedBox(height: 4),
          AppButton(
            switch (_mode) {
              _Mode.login => 'Se connecter',
              _Mode.signup => 'Créer mon compte',
              _Mode.magic => 'Recevoir le lien',
              _Mode.forgot => 'Envoyer le lien',
            },
            size: ButtonSize.lg,
            full: true,
            loading: _busy,
            onPressed: _valid ? _submit : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            InfoBox(tone: Tone.red, child: Text(_error!)),
          ],
          if (_mode == _Mode.login) ...[
            const SizedBox(height: 18),
            TextButton(onPressed: () => _setMode(_Mode.forgot), child: Text('Mot de passe oublié ?', style: TextStyle(color: c.brandText))),
            TextButton(
              onPressed: () => _setMode(_Mode.magic),
              child: Text('Recevoir un lien magique par email', style: TextStyle(color: c.brandText)),
            ),
          ],
        ],
      ),
    );
  }
}
