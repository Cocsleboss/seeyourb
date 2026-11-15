// Home sections "Entre amis" (events friends opened to their friends) and
// "Explorer" (public events): cards, search (Explorer), "load more", ad tiles.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ads/ads.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../ui/feedback.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';
import '../../ui/scaffold.dart';
import '../events/event_widgets.dart';
import '../friends/add_friend_sheet.dart';

class FeedSection extends ConsumerStatefulWidget {
  const FeedSection({super.key, required this.scope, required this.top});

  /// 'contacts' or 'public'
  final String scope;
  final List<Widget> top;

  @override
  ConsumerState<FeedSection> createState() => _FeedSectionState();
}

class _FeedSectionState extends ConsumerState<FeedSection> {
  final _q = TextEditingController();
  Timer? _debounce;
  String _query = '';
  final _more = <FeedEvent>[];
  bool _loadingMore = false;
  bool _end = false;
  bool _mineOnly = false;

  bool get _public => widget.scope == 'public';

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _query = v.trim();
        _more.clear();
        _end = false;
      });
    });
  }

  Future<void> _loadMore(FeedEvent last) async {
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(apiProvider).listFeed(widget.scope, query: _query, after: last);
      if (!mounted) return;
      setState(() {
        _more.addAll(page);
        _end = page.length < 30;
      });
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final key = (scope: widget.scope, query: _query);
    final feed = ref.watch(feedProvider(key));
    final friends = ref.watch(friendsProvider).value ?? const <Friend>[];
    final hasFriends = friends.any((f) => f.accepted);

    Future<void> refresh() async {
      setState(() {
        _more.clear();
        _end = false;
      });
      ref.invalidate(feedProvider(key));
      await ref.read(feedProvider(key).future);
    }

    final intro = Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Text(_public ? tr.exploreIntro : tr.friendsFeedIntro, style: TextStyle(color: c.textMuted, fontSize: 14.5, height: 1.35)),
    );

    final List<Widget> body;
    if (feed.hasError && !feed.hasValue) {
      body = [ErrorCard(error: feed.error!, onRetry: () => ref.invalidate(feedProvider(key)))];
    } else if (!feed.hasValue) {
      body = [const SkeletonList(rows: 3)];
    } else {
      final all = [...feed.requireValue, ..._more];
      if (all.isEmpty) {
        body = [
          AppCard(
            child: EmptyState(
              icon: _query.isNotEmpty ? LucideIcons.searchX : (_public ? LucideIcons.compass : LucideIcons.partyPopper),
              title: _query.isNotEmpty ? tr.noResults : (_public ? tr.exploreEmptyTitle : tr.friendsFeedEmptyTitle),
              message: _query.isNotEmpty ? tr.tryAnotherSearch : (_public ? tr.exploreEmptyMessage : tr.friendsFeedEmptyMessage),
              actions: [
                if (!_public) AppButton(tr.createFriendsEvent, icon: LucideIcons.calendarPlus, onPressed: () => context.push('/rdv/new?vis=contacts')),
                if (!_public && !hasFriends)
                  AppButton(tr.addSeeuFriendLong,
                      icon: LucideIcons.userPlus, variant: ButtonVariant.secondary, onPressed: () => showAddFriendSheet(context)),
              ],
            ),
          ),
        ];
      } else {
        final first = feed.requireValue;
        final hasMine = all.any((e) => e.isMine);
        final shown = hasMine && _mineOnly ? all.where((e) => e.isMine).toList() : all;
        body = [
          if (hasMine)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ChipWrap(children: [
                AppChip(tr.filterAll, selected: !_mineOnly, onTap: () => setState(() => _mineOnly = false)),
                AppChip(tr.filterMine, icon: LucideIcons.crown, selected: _mineOnly, onTap: () => setState(() => _mineOnly = true)),
              ]),
            ),
          ...withAds([for (final e in shown) EventCard(event: e)], _public ? AdPlacement.exploreFeed : AdPlacement.friendsFeed,
              first: 3, every: 5),
          if (!_end && first.length >= 30)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: AppButton(tr.loadMore,
                  variant: ButtonVariant.secondary, full: true, loading: _loadingMore, onPressed: () => _loadMore(all.last)),
            ),
        ];
      }
    }

    return PageList(
      onRefresh: refresh,
      bottomPadding: 100,
      children: [
        ...widget.top,
        intro,
        if (_public) ...[
          SearchField(controller: _q, hint: tr.exploreSearchHint, onChanged: _onQuery),
          const SizedBox(height: 12),
        ],
        ...body,
      ],
    );
  }
}
