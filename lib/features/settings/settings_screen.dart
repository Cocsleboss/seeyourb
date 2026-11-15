// §4.13 Réglages: profil, notifications, application, données, compte.
import 'dart:convert';
import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
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
import '../../domain/text.dart';
import '../../domain/models.dart';
import '../../ui/feedback.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';
import '../../ui/scaffold.dart';
import '../auth/username_field.dart';
import '../friends/friend_sheets.dart';
import '../home/push_banner.dart';
import '../../core/i18n.dart';
import '../../ads/ads.dart';
import '../../ui/language.dart';

String kindLabel(String kind) => switch (kind) {
      'due_digest' => tr.kindDueDigest,
      'birthday' => tr.kindBirthday,
      'rdv_reminder' => tr.kindRdvReminder,
      'rdv_followup' => tr.kindRdvFollowup,
      'friend_request' => tr.kindFriendRequest,
      'friend_accept' => tr.kindFriendAccept,
      'rdv_invite' => tr.kindRdvInvite,
      'rdv_response' => tr.kindRdvResponse,
      'rdv_change' => tr.kindRdvChange,
      'wave' => tr.kindWave,
      'test' => tr.kindTest,
      'event_new' => tr.kindEventNew,
      'event_join' => tr.kindEventJoin,
      'event_message' => tr.kindEventMessage,
      'event_announcement' => tr.kindEventAnnouncement,
      _ => kind,
    };

final _packageInfoProvider = FutureProvider((ref) => PackageInfo.fromPlatform());

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return AppScaffold(
      title: tr.settings,
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
                const _LanguageSection(),
                const _AppSection(),
                const _DataSection(),
                const _AccountSection(),
                const SizedBox(height: 20),
                Text(
                  tr.privacyFooter,
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
        if (widget.profile.username == null) 'username': _username.text,
        'birthday': _birthday == null ? null : dayIso(_birthday!),
      }),
      success: tr.profileUpdated,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (p != null) ref.read(sessionProvider).setProfile(p);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(tr.profile),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LabeledField(
            label: tr.displayName,
            required: true,
            child: AppTextField(controller: _name, hint: tr.yourFirstName, maxLength: 60, onChanged: (_) => setState(() {})),
          ),
          // The username is chosen once (it's how friends find you), then fixed.
          if (p.username == null)
            UsernameField(
              controller: _username,
              current: p.username,
              onStatus: (s) => setState(() => _status = s),
            )
          else
            _ReadOnly(label: tr.usernameLabel, value: handle(p.username), hint: tr.usernameFixed),
          LabeledField(
            label: tr.birthDate,
            hint: tr.birthDateFriendsHint,
            child: DateField(value: _birthday, last: today(), clearable: true, onChanged: (d) => setState(() => _birthday = d)),
          ),
          AppButton(tr.save, full: true, loading: _busy, onPressed: _changed && _valid ? _save : null),
          if (p.username != null) ...[
            const SizedBox(height: 10),
            AppButton(tr.shareMyHandle,
                icon: LucideIcons.share2, variant: ButtonVariant.secondary, full: true, onPressed: () => shareMyHandle(p.username!)),
          ],
          const SizedBox(height: 16),
          _ReadOnly(label: tr.timezone, value: p.timezone, hint: tr.timezoneHint),
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
      showToast(tr.pushDisabledDevice, kind: ToastKind.info);
    } else if (perm == PushPermission.denied) {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    } else {
      final res = await push.enable(api);
      if (res == PushPermission.granted) {
        showToast(tr.pushEnabledDevice);
      } else if (res == PushPermission.denied) {
        showToast(tr.pushPermissionDenied, kind: ToastKind.error);
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
    }, success: tr.testSent);
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
      PushPermission.unsupported => (tr.pushUnsupported, null),
      PushPermission.denied => (tr.pushBlockedSettings, tr.openPhoneSettings),
      PushPermission.granted when on => (tr.pushOnDevice, tr.disable),
      _ => (tr.pushOffDevice, tr.enable),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(tr.notifications),
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
            title: tr.pushReminders,
            subtitle: tr.pushRemindersSub,
            value: p.notifyPush,
            onChanged: (v) => _set('notify_push', v),
          ),
          ToggleRow(
            title: tr.emailReminders,
            subtitle: tr.emailRemindersSub,
            value: p.notifyEmail,
            onChanged: (v) => _set('notify_email', v),
          ),
          const SizedBox(height: 12),
          LabeledField(
            label: tr.dailyHour,
            hint: tr.dailyHourHint,
            child: AppDropdown<int>(
              value: p.dailyHour,
              items: [for (var h = 0; h < 24; h++) (h, formatTime(DateTime(2000, 1, 1, h)))],
              onChanged: (v) => _set('daily_hour', v),
            ),
          ),
          LabeledField(
            label: tr.notifyLead,
            child: AppDropdown<int>(
              value: [0, 1, 3, 7, 14].contains(p.dueLeadDays) ? p.dueLeadDays : 0,
              items: [(0, tr.leadSameDay), (1, tr.leadDays(1)), (3, tr.leadDays(3)), (7, tr.leadWeeks(1)), (14, tr.leadWeeks(2))],
              onChanged: (v) => _set('due_lead_days', v),
            ),
          ),
          LabeledField(
            label: tr.rdvReminderLead,
            child: AppDropdown<int>(
              value: [15, 30, 60, 120, 1440].contains(p.rdvReminderMinutes) ? p.rdvReminderMinutes : 30,
              items: [
                (15, tr.leadMinutes(15)),
                (30, tr.leadMinutes(30)),
                (60, tr.leadHours(1)),
                (120, tr.leadHours(2)),
                (1440, tr.leadEve),
              ],
              onChanged: (v) => _set('rdv_reminder_minutes', v),
            ),
          ),
          AppButton(tr.sendTestNotification,
              icon: LucideIcons.send, variant: ButtonVariant.secondary, full: true, loading: _testing, onPressed: _test),
          const SizedBox(height: 18),
          Text(tr.lastNotifications, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: c.text)),
          const SizedBox(height: 6),
          AsyncBody(
            value: log,
            skeletonRows: 2,
            onRetry: () => ref.invalidate(notificationLogProvider),
            builder: (list) => list.isEmpty
                ? Text(tr.noNotificationsYet, style: TextStyle(color: c.textMuted, fontSize: 14))
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
      _ => (tr.channelNone, Tone.gray),
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
            Text('${kindLabel(n.kind)} · ${formatDate(n.createdAt)} ${formatTime(n.createdAt)}',
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

class _LanguageSection extends ConsumerWidget {
  const _LanguageSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final choice = ref.watch(languageChoiceProvider);
    final lang = ref.watch(languageProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(tr.languageTitle),
      RowsCard(children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(LucideIcons.globe, color: c.brandText),
          title: Text(appLanguages[lang] ?? lang, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
          subtitle: choice == null ? Text(tr.languageSystem, style: TextStyle(color: c.textMuted, fontSize: 13.5)) : null,
          trailing: Icon(LucideIcons.chevronRight, color: c.textMuted),
          onTap: () => pickLanguage(context, ref),
        ),
      ]),
    ]);
  }
}

class _AppSection extends ConsumerWidget {
  const _AppSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(_packageInfoProvider).value;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(tr.application),
      AppCard(child: _ReadOnly(label: tr.version, value: info == null ? '…' : '${info.version} (${info.buildNumber})')),
      if (kDebugMode) ...[
        const SizedBox(height: 10),
        AppCard(
          child: ToggleRow(
            title: tr.demoAds,
            subtitle: tr.demoAdsHelp,
            value: ref.watch(adsDemoProvider),
            onChanged: ref.read(adsDemoProvider.notifier).set,
          ),
        ),
      ],
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
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/json')], subject: tr.exportSubject));
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
      SectionTitle(tr.data),
      RowsCard(children: [
        row(LucideIcons.bookUser, tr.importFromPhoneLong, tr.importFromPhoneSub,
            () => context.push('/contacts/import')),
        row(LucideIcons.download, tr.exportData, tr.exportDataSub, _export, loading: _exporting),
        row(LucideIcons.shieldBan, tr.mutedAndBlocked, tr.mutedAndBlockedSub, () => context.push('/settings/moderation')),
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
      title: tr.deleteAccountTitle,
      message: tr.deleteAccountMessage,
      confirmLabel: tr.deleteMyAccount,
    );
    if (!ok) return;
    final api = ref.read(apiProvider);
    await PushService.instance.unregister(api);
    await guard(() async {
      await withProgress(() => api.deleteAccount());
      return true;
    }, success: tr.accountDeleted);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(tr.account),
      AppButton(tr.changePassword,
          icon: LucideIcons.keyRound, variant: ButtonVariant.secondary, full: true, onPressed: () => _changePassword(context)),
      const SizedBox(height: 10),
      AppButton(tr.signOut, icon: LucideIcons.logOut, variant: ButtonVariant.outline, full: true, onAsync: () => _signOut(ref)),
      const SizedBox(height: 10),
      AppButton(tr.deleteMyAccount,
          icon: LucideIcons.trash2, variant: ButtonVariant.danger, full: true, onPressed: () => _delete(context, ref)),
    ]);
  }

  void _changePassword(BuildContext context) =>
      showAppSheet(context, title: tr.changePassword, builder: (_) => const _PasswordSheet());
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
    if (_p1.text.length < 6) return setState(() => _error = tr.errWeakPassword);
    if (_p1.text != _p2.text) return setState(() => _error = tr.passwordsNoMatch);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(supabaseProvider).auth.updateUser(UserAttributes(password: _p1.text));
      showToast(tr.passwordUpdated);
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
      LabeledField(label: tr.newPassword, hint: tr.passwordMin, child: AppTextField(controller: _p1, obscure: true)),
      LabeledField(label: tr.confirm, error: _error, child: AppTextField(controller: _p2, obscure: true)),
      AppButton(tr.save, size: ButtonSize.lg, full: true, loading: _busy, onPressed: _save),
    ]);
  }
}
