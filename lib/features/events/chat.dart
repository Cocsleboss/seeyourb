// Event chat, shown directly on the event page (private & friends events: everyone
// talks; public events: announcements, only the organizer posts). Live through
// Supabase Realtime.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';
import 'moderation.dart';

String chatTitle(EventVisibility v) => v == EventVisibility.public ? tr.announcements : tr.chat;

const _pageSize = 20;

class EventChat extends ConsumerStatefulWidget {
  const EventChat({super.key, required this.rdv, required this.canPost});
  final Rendezvous rdv;
  final bool canPost;

  @override
  ConsumerState<EventChat> createState() => _EventChatState();
}

class _EventChatState extends ConsumerState<EventChat> {
  final _text = TextEditingController();

  /// Newest first.
  final _messages = <ChatMessage>[];
  void Function()? _stopWatching;
  late final Api _api;
  bool _loading = true;
  bool _sending = false;
  bool _hasOlder = false;
  bool _loadingOlder = false;
  Object? _error;

  String get _eventId => widget.rdv.eventId!;

  @override
  void initState() {
    super.initState();
    _api = ref.read(apiProvider);
    _load();
    _stopWatching = _api.watchMessages(_eventId, _onInsert, (id) {
      if (mounted) setState(() => _messages.removeWhere((m) => m.id == id));
    });
    _api.markChatRead(widget.rdv.id).catchError((_) {});
  }

  @override
  void dispose() {
    _stopWatching?.call();
    _api.markChatRead(widget.rdv.id).catchError((_) {});
    _text.dispose();
    super.dispose();
  }

  Future<void> _load({bool older = false}) async {
    if (older) setState(() => _loadingOlder = true);
    try {
      final page = await _api.listMessages(_eventId,
          before: older && _messages.isNotEmpty ? _messages.last.createdAt : null, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        if (!older) _messages.clear();
        _messages.addAll(page.where((m) => !_messages.any((x) => x.id == m.id)));
        if (!older || page.length < _pageSize) _hasOlder = page.length >= _pageSize;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => (_error = e, _loading = false));
    } finally {
      if (mounted && older) setState(() => _loadingOlder = false);
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
      _load(); // unknown author: reload with names and filters applied
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
      await _api.sendMessage(_eventId, body);
      _text.clear();
      await _load();
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
          final ok = await withProgress(() => guard(() async {
                await _api.deleteMessage(m.id);
                return true;
              }));
          if (ok != null && mounted) setState(() => _messages.removeWhere((x) => x.id == m.id));
        }, danger: true)
      else
        ...personActions(context, ref, userId: m.userId, name: m.authorName, muted: false, onBlocked: () {
          if (mounted) _load();
        }),
    ]);
    if (!mine && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final public = widget.rdv.visibility == EventVisibility.public;
    final myId = widget.rdv.userId;
    final shown = _messages.reversed.toList(); // oldest → newest

    Widget body;
    if (_loading) {
      body = const SkeletonList(rows: 2);
    } else if (_error != null && _messages.isEmpty) {
      body = ErrorCard(error: _error!, onRetry: _load);
    } else if (_messages.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(public ? (widget.canPost ? tr.announceEmptyOrganizer : tr.announceEmpty) : tr.chatEmpty,
            style: TextStyle(color: c.textMuted, fontSize: 14.5)),
      );
    } else {
      final items = <Widget>[
        if (_hasOlder)
          Center(
            child: _loadingOlder
                ? const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                : TextButton(onPressed: () => _load(older: true), child: Text(tr.earlierMessages)),
          ),
        for (var i = 0; i < shown.length; i++) ...[
          if (i == 0 || dayOf(shown[i - 1].createdAt) != dayOf(shown[i].createdAt))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(relativeDayLabel(dayOf(shown[i].createdAt)),
                  textAlign: TextAlign.center, style: TextStyle(color: c.textSubtle, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          _Bubble(
            message: shown[i],
            mine: shown[i].userId == myId,
            showName: shown[i].userId != myId && (i == 0 || shown[i - 1].userId != shown[i].userId),
            tight: i > 0 && shown[i - 1].userId == shown[i].userId,
            announcement: public,
            onLongPress: () => _onLongPress(shown[i]),
          ),
        ],
      ];
      // Capped height, scrolls inside; reversed so it opens on the newest message.
      // Older messages fade out under the top edge instead of being cut.
      body = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 255),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black],
            stops: [0, 1],
          ).createShader(Rect.fromLTWH(0, 0, rect.width, 36)),
          child: ListView(
            reverse: true,
            shrinkWrap: true,
            padding: const EdgeInsets.only(top: 12),
            children: items.reversed.toList(),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(chatTitle(widget.rdv.visibility)),
      AppCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          body,
          const SizedBox(height: 10),
          if (widget.canPost)
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
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
            ])
          else
            Text(public ? tr.announceReadOnly : tr.chatJoinToPost, style: TextStyle(color: c.textMuted, fontSize: 13)),
        ]),
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
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
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
                Text(formatTime(message.createdAt), style: TextStyle(fontSize: 11, color: mine ? Colors.white70 : c.textSubtle)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
