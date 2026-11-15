// Event chat (private & friends events: everyone talks) / announcements (public
// events: only the organizer posts). Live through Supabase Realtime.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';
import '../../ui/scaffold.dart';
import '../misc/fallback_screens.dart';
import 'moderation.dart';

String chatTitle(EventVisibility v) => v == EventVisibility.public ? tr.announcements : tr.chat;

/// Last messages on the event page + button to open the chat.
class ChatPreview extends ConsumerWidget {
  const ChatPreview({super.key, required this.rdv});
  final Rendezvous rdv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final value = ref.watch(chatPreviewProvider(rdv.eventId!));
    final messages = value.value ?? const <ChatMessage>[];
    final unread = messages.where((m) => m.userId != rdv.userId && (rdv.chatReadAt == null || m.createdAt.isAfter(rdv.chatReadAt!))).length;
    final public = rdv.visibility == EventVisibility.public;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(chatTitle(rdv.visibility)),
      AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => context.push('/rdv/${rdv.id}/chat'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (messages.isEmpty)
            Text(public ? (rdv.isOrganizer ? tr.announceEmptyOrganizer : tr.announceEmpty) : tr.chatEmpty,
                style: TextStyle(color: c.textMuted, fontSize: 14.5))
          else
            for (final m in messages.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${m.authorName}  ', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                    TextSpan(text: m.body),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, color: c.text),
                ),
              ),
          const SizedBox(height: 6),
          Row(children: [
            Icon(public ? LucideIcons.megaphone : LucideIcons.messageCircle, size: 18, color: c.brandText),
            const SizedBox(width: 6),
            Expanded(
              child: Text(public && !rdv.isOrganizer ? tr.openAnnouncements : tr.openChat,
                  style: TextStyle(color: c.brandText, fontWeight: FontWeight.w600)),
            ),
            if (unread > 0) Pill(tr.nNew(unread), tone: Tone.brand),
          ]),
        ]),
      ),
    ]);
  }
}

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key, required this.rdvId});
  final String rdvId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rdv = ref.watch(rdvProvider(rdvId));
    if (rdv.hasValue && (rdv.value == null || rdv.value!.eventId == null)) {
      return MissingItem(title: tr.errRdvNotFound, backLabel: tr.backToHome, backPath: '/');
    }
    final r = rdv.value;
    final event = r == null ? null : ref.watch(eventProvider(r.eventId!)).value;
    return AppScaffold(
      title: r == null ? tr.chat : '${chatTitle(r.visibility)} · ${r.displayTitle}',
      back: true,
      body: r == null || event == null
          ? Padding(padding: const EdgeInsets.all(16), child: AsyncBody(value: rdv, builder: (_) => const SizedBox()))
          : _Chat(rdv: r, event: event),
    );
  }
}

class _Chat extends ConsumerStatefulWidget {
  const _Chat({required this.rdv, required this.event});
  final Rendezvous rdv;
  final FeedEvent event;
  @override
  ConsumerState<_Chat> createState() => _ChatState();
}

class _ChatState extends ConsumerState<_Chat> {
  final _text = TextEditingController();
  final _messages = <ChatMessage>[];
  RealtimeChannel? _channel;
  late final Api _api;
  bool _loading = true;
  bool _sending = false;
  bool _hasOlder = true;
  Object? _error;

  String get _eventId => widget.rdv.eventId!;

  @override
  void initState() {
    super.initState();
    _api = ref.read(apiProvider);
    _load();
    _channel = _api.watchMessages(_eventId, _onInsert, (id) {
      if (mounted) setState(() => _messages.removeWhere((m) => m.id == id));
    });
    _api.markChatRead(widget.rdv.id).catchError((_) {});
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _api.markChatRead(widget.rdv.id).catchError((_) {});
    _text.dispose();
    super.dispose();
  }

  Future<void> _load({bool older = false}) async {
    try {
      final page = await ref.read(apiProvider).listMessages(_eventId, before: older && _messages.isNotEmpty ? _messages.last.createdAt : null);
      if (!mounted) return;
      setState(() {
        if (!older) _messages.clear();
        _messages.addAll(page.where((m) => !_messages.any((x) => x.id == m.id)));
        _hasOlder = page.length >= 50;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => (_error = e, _loading = false));
    }
  }

  /// Realtime insert: the row has no author name; resolve it from participants.
  void _onInsert(Map<String, dynamic> row) {
    if (!mounted) return;
    final id = row['id'] as String?;
    if (id == null || _messages.any((m) => m.id == id)) return;
    final userId = row['user_id'] as String? ?? '';
    final participants = ref.read(participantsProvider(_eventId)).value ?? const <Participant>[];
    final me = ref.read(profileProvider);
    final name = userId == me?.id ? me!.name : participants.where((p) => p.userId == userId).firstOrNull?.name;
    if (name == null) {
      _load(); // unknown author (new participant / muted…): reload with names and filters applied
      return;
    }
    setState(() => _messages.insert(
        0, ChatMessage(id: id, userId: userId, authorName: name, body: row['body'] as String? ?? '', createdAt: DateTime.now())));
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(apiProvider).sendMessage(_eventId, body);
      _text.clear();
      await _load();
      ref.invalidate(chatPreviewProvider(_eventId));
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _onLongPress(ChatMessage m) async {
    final mine = m.userId == widget.rdv.userId;
    await showModerationSheet(context, title: m.authorName, actions: [
      if (mine)
        ModerationAction(LucideIcons.trash2, tr.deleteMessage, () async {
          final ok = await guard(() async {
            await ref.read(apiProvider).deleteMessage(m.id);
            return true;
          });
          if (ok != null && mounted) setState(() => _messages.removeWhere((x) => x.id == m.id));
        }, danger: true)
      else
        ...personActions(context, ref, userId: m.userId, name: m.authorName, muted: false),
    ]);
    if (!mine && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final canPost = widget.event.canPost;
    final public = widget.event.visibility == EventVisibility.public;
    final myId = widget.rdv.userId;

    Widget list;
    if (_loading) {
      list = const Padding(padding: EdgeInsets.all(16), child: SkeletonList(rows: 4));
    } else if (_error != null && _messages.isEmpty) {
      list = Padding(padding: const EdgeInsets.all(16), child: ErrorCard(error: _error!, onRetry: _load));
    } else if (_messages.isEmpty) {
      list = EmptyState(
        icon: public ? LucideIcons.megaphone : LucideIcons.messagesSquare,
        title: public ? tr.announcements : tr.chat,
        message: public ? (canPost ? tr.announceEmptyOrganizer : tr.announceEmpty) : tr.chatEmpty,
      );
    } else {
      list = ListView.builder(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        itemCount: _messages.length + (_hasOlder ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _messages.length) {
            return Center(child: TextButton(onPressed: () => _load(older: true), child: Text(tr.loadMore)));
          }
          final m = _messages[i];
          final mine = m.userId == myId;
          final newer = i > 0 ? _messages[i - 1] : null;
          final older = i + 1 < _messages.length ? _messages[i + 1] : null;
          final showName = !mine && (older == null || older.userId != m.userId);
          final showDay = older == null || dayOf(older.createdAt) != dayOf(m.createdAt);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (showDay)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(relativeDayLabel(dayOf(m.createdAt)),
                    textAlign: TextAlign.center, style: TextStyle(color: c.textSubtle, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            _Bubble(
              message: m,
              mine: mine,
              showName: showName,
              tight: newer != null && newer.userId == m.userId,
              announcement: public,
              onLongPress: () => _onLongPress(m),
            ),
          ]);
        },
      );
    }

    return Column(children: [
      Expanded(child: list),
      if (canPost)
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.border))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: public ? tr.announceHint : tr.messageHint,
                    counterText: '',
                    filled: true,
                    fillColor: c.secondaryFill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: tr.send,
                onPressed: _sending ? null : _send,
                style: IconButton.styleFrom(backgroundColor: Palette.brand600, foregroundColor: Colors.white),
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.sendHorizontal, size: 20),
              ),
            ]),
          ),
        )
      else
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(public ? tr.announceReadOnly : tr.chatJoinToPost,
                textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, fontSize: 13.5)),
          ),
        ),
    ]);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.showName,
    required this.tight,
    required this.announcement,
    required this.onLongPress,
  });
  final ChatMessage message;
  final bool mine;
  final bool showName;
  final bool tight;
  final bool announcement;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = mine ? Palette.brand600 : (announcement ? c.tone(Tone.brand).bg : c.secondaryFill);
    final fg = mine ? Colors.white : c.text;
    return Padding(
      padding: EdgeInsets.only(top: tight ? 2 : 8),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          child: GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (showName)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(message.authorName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: c.brandText)),
                  ),
                Text(message.body, style: TextStyle(color: fg, fontSize: 15.5, height: 1.3)),
                const SizedBox(height: 2),
                Text(formatTime(message.createdAt),
                    style: TextStyle(fontSize: 11, color: mine ? Colors.white70 : c.textSubtle)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
