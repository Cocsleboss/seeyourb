// §4.13 Réglages: profil, notifications, application, données, compte.
import 'dart:convert';
import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../core/push.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../ui/feedback.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';
import '../../ui/scaffold.dart';
import '../auth/username_field.dart';
import '../friends/friend_sheets.dart';
import '../home/push_banner.dart';

const kindLabels = {
  'due_digest': 'Contacts à recontacter',
  'birthday': 'Anniversaire',
  'rdv_reminder': 'Rappel de rendez-vous',
  'rdv_followup': 'Suivi de rendez-vous',
  'friend_request': "Demande d'ami",
  'friend_accept': 'Ami accepté',
  'rdv_invite': 'Invitation à un rendez-vous',
  'rdv_response': 'Réponse à une invitation',
  'rdv_change': 'Rendez-vous partagé modifié',
  'wave': 'Envie de se voir',
  'test': 'Test',
};

final _packageInfoProvider = FutureProvider((ref) => PackageInfo.fromPlatform());

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return AppScaffold(
      title: 'Réglages',
      body: profile == null
          ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList())
          : PageList(
              onRefresh: () async {
                ref.invalidate(notificationLogProvider);
                ref.invalidate(pushPermissionProvider);
                await ref.read(sessionProvider).reloadProfile();
              },
              children: [
                _ProfileSection(profile: profile, key: ValueKey(profile.id)),
                _NotificationSection(profile: profile),
                const _AppSection(),
                const _DataSection(),
                const _AccountSection(),
                const SizedBox(height: 20),
                Text(
                  'SeeU · Vos données restent privées : seuls les rendez-vous que vous envoyez à un ami sont partagés avec lui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textMuted, fontSize: 13),
                ),
              ],
            ),
    );
  }
}

/* ------------------------------- Profile ------------------------------ */

class _ProfileSection extends ConsumerStatefulWidget {
  const _ProfileSection({super.key, required this.profile});
  final Profile profile;
  @override
  ConsumerState<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends ConsumerState<_ProfileSection> {
  late final _name = TextEditingController(text: widget.profile.displayName ?? '');
  late final _username = TextEditingController(text: widget.profile.username ?? '');
  late DateTime? _birthday = widget.profile.birthday;
  UsernameStatus _status = UsernameStatus.available;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  bool get _changed =>
      _name.text.trim() != (widget.profile.displayName ?? '') ||
      _username.text != (widget.profile.username ?? '') ||
      _birthday != widget.profile.birthday;

  bool get _valid => _name.text.trim().isNotEmpty && _status == UsernameStatus.available;

  Future<void> _save() async {
    setState(() => _busy = true);
    final p = await guard(
      () => ref.read(apiProvider).updateProfile({
        'display_name': _name.text.trim(),
        'username': _username.text,
        'birthday': _birthday == null ? null : dayIso(_birthday!),
      }),
      success: 'Profil mis à jour',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (p != null) ref.read(sessionProvider).setProfile(p);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Profil'),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LabeledField(
            label: 'Nom affiché',
            required: true,
            child: AppTextField(controller: _name, hint: 'Votre prénom', maxLength: 60, onChanged: (_) => setState(() {})),
          ),
          UsernameField(
            controller: _username,
            current: p.username,
            onStatus: (s) => setState(() => _status = s),
          ),
          LabeledField(
            label: 'Date de naissance',
            hint: 'Visible par vos amis SeeU uniquement : leur fiche à votre nom se remplit toute seule.',
            child: DateField(value: _birthday, last: today(), clearable: true, onChanged: (d) => setState(() => _birthday = d)),
          ),
          Row(children: [
            Expanded(child: AppButton('Enregistrer', full: true, loading: _busy, onPressed: _changed && _valid ? _save : null)),
            const SizedBox(width: 10),
            if (p.username != null)
              Expanded(
                child: AppButton('Partager mon @',
                    icon: LucideIcons.share2, variant: ButtonVariant.secondary, full: true, onPressed: () => shareMyHandle(p.username!)),
              ),
          ]),
          const SizedBox(height: 16),
          _ReadOnly(label: 'Email', value: p.email ?? '—', hint: "Jamais affiché aux autres utilisateurs avant qu'ils soient vos amis"),
          _ReadOnly(label: 'Fuseau horaire', value: p.timezone, hint: "Détecté automatiquement, utilisé pour l'heure des rappels"),
        ]),
      ),
    ]);
  }
}

class _ReadOnly extends StatelessWidget {
  const _ReadOnly({required this.label, required this.value, this.hint});
  final String label;
  final String value;
  final String? hint;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: c.textMuted, fontSize: 14.5))),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, color: c.text))),
        ]),
        if (hint != null) Text(hint!, style: TextStyle(color: c.textSubtle, fontSize: 12.5)),
      ]),
    );
  }
}

/* ---------------------------- Notifications --------------------------- */

class _NotificationSection extends ConsumerStatefulWidget {
  const _NotificationSection({required this.profile});
  final Profile profile;
  @override
  ConsumerState<_NotificationSection> createState() => _NotificationSectionState();
}

class _NotificationSectionState extends ConsumerState<_NotificationSection> {
  bool _busy = false;
  bool _testing = false;

  /// Saved as soon as touched, without a submit button.
  Future<void> _set(String field, Object value) async {
    final p = await guard(() => ref.read(apiProvider).updateProfile({field: value}));
    if (p != null) ref.read(sessionProvider).setProfile(p);
  }

  Future<void> _toggleDevice(PushPermission perm) async {
    setState(() => _busy = true);
    final push = PushService.instance;
    final api = ref.read(apiProvider);
    if (perm == PushPermission.granted && push.registered) {
      await push.unregister(api);
      showToast('Notifications désactivées sur cet appareil', kind: ToastKind.info);
    } else if (perm == PushPermission.denied) {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    } else {
      final res = await push.enable(api);
      if (res == PushPermission.granted) {
        showToast('Notifications activées sur cet appareil');
      } else if (res == PushPermission.denied) {
        showToast("Permission refusée : autorisez les notifications dans les réglages de l'appareil.", kind: ToastKind.error);
      }
    }
    ref.invalidate(pushPermissionProvider);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    await guard(() async {
      await ref.read(apiProvider).sendTestNotification();
      return true;
    }, success: 'Notification de test envoyée');
    await Future<void>.delayed(const Duration(seconds: 3));
    ref.invalidate(notificationLogProvider);
    if (mounted) setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = widget.profile;
    final perm = ref.watch(pushPermissionProvider).value ?? PushPermission.unsupported;
    final log = ref.watch(notificationLogProvider);
    final on = perm == PushPermission.granted && PushService.instance.registered;
    final (String status, String? action) = switch (perm) {
      PushPermission.unsupported => ('Notifications push indisponibles sur cette version ; les rappels partiront par email.', null),
      PushPermission.denied => ('Notifications bloquées : autorisez-les dans les réglages du téléphone.', 'Ouvrir les réglages'),
      PushPermission.granted when on => ('Activées sur cet appareil', 'Désactiver'),
      _ => ('Non activées sur cet appareil', 'Activer'),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Notifications'),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(on ? LucideIcons.bellRing : LucideIcons.bellOff, color: on ? c.tone(Tone.green).text : c.textMuted),
            const SizedBox(width: 10),
            Expanded(child: Text(status, style: TextStyle(color: c.text, fontSize: 15))),
            if (action != null) ...[
              const SizedBox(width: 8),
              AppButton(action,
                  size: ButtonSize.sm,
                  variant: on ? ButtonVariant.secondary : ButtonVariant.primary,
                  loading: _busy,
                  onPressed: () => _toggleDevice(perm)),
            ],
          ]),
          const Divider(height: 28),
          ToggleRow(
            title: 'Rappels push',
            subtitle: 'Sur tous les appareils où vous les avez activées',
            value: p.notifyPush,
            onChanged: (v) => _set('notify_push', v),
          ),
          ToggleRow(
            title: 'Rappels par email',
            subtitle: "Utilisés si aucun appareil n'a les notifications push activées",
            value: p.notifyEmail,
            onChanged: (v) => _set('notify_email', v),
          ),
          const SizedBox(height: 12),
          LabeledField(
            label: 'Heure du rappel quotidien',
            hint: 'Un seul récapitulatif par jour des contacts à recontacter',
            child: AppDropdown<int>(
              value: p.dailyHour,
              items: [for (var h = 0; h < 24; h++) (h, '${h.toString().padLeft(2, '0')}:00')],
              onChanged: (v) => _set('daily_hour', v),
            ),
          ),
          LabeledField(
            label: 'Prévenir',
            child: AppDropdown<int>(
              value: [0, 1, 3, 7, 14].contains(p.dueLeadDays) ? p.dueLeadDays : 0,
              items: const [(0, "Le jour de l'échéance"), (1, '1 jour avant'), (3, '3 jours avant'), (7, '1 semaine avant'), (14, '2 semaines avant')],
              onChanged: (v) => _set('due_lead_days', v),
            ),
          ),
          LabeledField(
            label: 'Rappel avant un rendez-vous',
            child: AppDropdown<int>(
              value: [15, 30, 60, 120, 1440].contains(p.rdvReminderMinutes) ? p.rdvReminderMinutes : 30,
              items: const [
                (15, '15 minutes avant'),
                (30, '30 minutes avant'),
                (60, '1 heure avant'),
                (120, '2 heures avant'),
                (1440, 'La veille (24 h avant)'),
              ],
              onChanged: (v) => _set('rdv_reminder_minutes', v),
            ),
          ),
          AppButton('Envoyer une notification de test',
              icon: LucideIcons.send, variant: ButtonVariant.secondary, full: true, loading: _testing, onPressed: _test),
          const SizedBox(height: 18),
          Text('Dernières notifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: c.text)),
          const SizedBox(height: 6),
          AsyncBody(
            value: log,
            skeletonRows: 2,
            onRetry: () => ref.invalidate(notificationLogProvider),
            builder: (list) => list.isEmpty
                ? Text("Aucune notification envoyée pour l'instant.", style: TextStyle(color: c.textMuted, fontSize: 14))
                : Column(children: [for (final n in list) _LogRow(n)]),
          ),
        ]),
      ),
    ]);
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow(this.n);
  final NotificationEntry n;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (String channel, Tone tone) = switch (n.channel) {
      'push' => ('push', Tone.green),
      'email' => ('email', Tone.brand),
      _ => ('aucun', Tone.gray),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: c.text)),
            if (n.body != null && n.body!.isNotEmpty)
              Text(n.body!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textMuted, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text('${kindLabels[n.kind] ?? n.kind} · ${formatDate(n.createdAt)} ${formatTime(n.createdAt)}',
                style: TextStyle(color: c.textSubtle, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(width: 8),
        Pill(channel, tone: tone),
      ]),
    );
  }
}

/* --------------------------------- App -------------------------------- */

class _AppSection extends ConsumerWidget {
  const _AppSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(_packageInfoProvider).value;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Application'),
      AppCard(child: _ReadOnly(label: 'Version', value: info == null ? '…' : '${info.version} (${info.buildNumber})')),
    ]);
  }
}

/* -------------------------------- Data -------------------------------- */

class _DataSection extends ConsumerStatefulWidget {
  const _DataSection();
  @override
  ConsumerState<_DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends ConsumerState<_DataSection> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final data = await ref.read(apiProvider).exportData();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/seeu-export-${dayIso(DateTime.now())}.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/json')], subject: 'Export SeeU'));
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget row(IconData icon, String title, String subtitle, VoidCallback onTap, {bool loading = false}) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(icon, color: c.brandText),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
          subtitle: Text(subtitle, style: TextStyle(color: c.textMuted, fontSize: 13.5)),
          trailing: loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(LucideIcons.chevronRight, color: c.textMuted),
          onTap: loading ? null : onTap,
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Données'),
      RowsCard(children: [
        row(LucideIcons.bookUser, 'Importer des contacts du téléphone', 'Depuis le carnet d\'adresses, avec revue contact par contact.',
            () => context.push('/contacts/import')),
        row(LucideIcons.download, 'Exporter mes données', 'Profil, contacts, rendez-vous et liste des photos.', _export, loading: _exporting),
      ]),
    ]);
  }
}

/* ------------------------------- Account ------------------------------ */

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  Future<void> _signOut(WidgetRef ref) async {
    final api = ref.read(apiProvider);
    await PushService.instance.unregister(api);
    await ref.read(supabaseProvider).auth.signOut();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmSheet(
      context,
      title: 'Supprimer définitivement votre compte ?',
      message: 'Tous vos contacts, rendez-vous et photos seront effacés. Cette action est irréversible.',
      confirmLabel: 'Supprimer mon compte',
    );
    if (!ok) return;
    final api = ref.read(apiProvider);
    await PushService.instance.unregister(api);
    await guard(() async {
      await api.deleteAccount();
      return true;
    }, success: 'Compte supprimé');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Compte'),
      AppButton('Changer le mot de passe',
          icon: LucideIcons.keyRound, variant: ButtonVariant.secondary, full: true, onPressed: () => _changePassword(context)),
      const SizedBox(height: 10),
      AppButton('Se déconnecter', icon: LucideIcons.logOut, variant: ButtonVariant.outline, full: true, onPressed: () => _signOut(ref)),
      const SizedBox(height: 10),
      AppButton('Supprimer mon compte',
          icon: LucideIcons.trash2, variant: ButtonVariant.danger, full: true, onPressed: () => _delete(context, ref)),
    ]);
  }

  void _changePassword(BuildContext context) =>
      showAppSheet(context, title: 'Changer le mot de passe', builder: (_) => const _PasswordSheet());
}

class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet();
  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
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

  Future<void> _save() async {
    if (_p1.text.length < 6) return setState(() => _error = 'Le mot de passe doit contenir au moins 6 caractères.');
    if (_p1.text != _p2.text) return setState(() => _error = 'Les deux mots de passe ne correspondent pas.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(supabaseProvider).auth.updateUser(UserAttributes(password: _p1.text));
      showToast('Mot de passe mis à jour');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LabeledField(label: 'Nouveau mot de passe', hint: '6 caractères minimum', child: AppTextField(controller: _p1, obscure: true)),
      LabeledField(label: 'Confirmer', error: _error, child: AppTextField(controller: _p2, obscure: true)),
      AppButton('Enregistrer', size: ButtonSize.lg, full: true, loading: _busy, onPressed: _save),
    ]);
  }
}
