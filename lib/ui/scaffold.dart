// Page scaffold: top bar (title, back arrow, right action) + the 5-tab bottom bar.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme.dart';
import '../core/i18n.dart';

class TabItem {
  const TabItem(this.path, this._label, this.icon);
  final String path;
  final String Function() _label;
  final IconData icon;
  String get label => _label();
}

final appTabs = [
  TabItem('/', () => tr.tabHome, LucideIcons.house),
  TabItem('/contacts', () => tr.tabContacts, LucideIcons.users),
  TabItem('/history', () => tr.tabHistory, LucideIcons.clock),
  TabItem('/settings', () => tr.tabSettings, LucideIcons.settings),
];

/// Tab highlighted for a location ("/contacts/123" → Contacts, "/rdv/…" → none).
int? tabIndexFor(String location) {
  if (location == '/' || location.isEmpty) return 0;
  for (var i = 1; i < appTabs.length; i++) {
    if (location == appTabs[i].path || location.startsWith('${appTabs[i].path}/') || location.startsWith('${appTabs[i].path}?')) return i;
  }
  return null;
}

class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, required this.current, required this.onTap});
  final int? current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: c.background.withValues(alpha: 0.92),
            border: Border(top: BorderSide(color: c.isDark ? Palette.gray800 : const Color(0xCCE5E7EB))),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  for (var i = 0; i < appTabs.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: i == current,
                        button: true,
                        label: appTabs[i].label,
                        child: InkResponse(
                          onTap: () => onTap(i),
                          radius: 36,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(appTabs[i].icon, size: 25, color: i == current ? c.brandText : c.textMuted),
                              const SizedBox(height: 3),
                              Text(appTabs[i].label,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: i == current ? c.brandText : c.textMuted,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard page: optional top bar with back arrow and actions, scrollable body.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.back = false,
    this.onBack,
    this.actions = const [],
    required this.body,
    this.fab,
    this.showTabs = true,
    this.bottom,
  });

  final String? title;
  final String? subtitle;
  final bool back;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget body;
  final Widget? fab;

  /// Detail pages pushed over the tabs keep the bottom bar visible.
  final bool showTabs;

  /// Optional sticky bottom area (e.g. a form's submit button).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final location = GoRouterState.of(context).uri.path;
    return Scaffold(
      backgroundColor: c.background,
      appBar: title == null
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: subtitle == null ? 58 : 66,
              titleSpacing: back ? 0 : 20,
              leading: back
                  ? IconButton(
                      tooltip: tr.back,
                      icon: Icon(LucideIcons.chevronLeft, color: c.brandText, size: 28),
                      onPressed: onBack ?? () => context.canPop() ? context.pop() : context.go('/'),
                    )
                  : null,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: back ? 20 : 26, fontWeight: FontWeight.w700, color: c.text)),
                  if (subtitle != null)
                    Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: c.textMuted, fontWeight: FontWeight.w400)),
                ],
              ),
              actions: [...actions, const SizedBox(width: 10)],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: c.isDark ? Palette.gray800 : const Color(0xB3E5E7EB)),
              ),
            ),
      body: body,
      floatingActionButton: fab,
      bottomNavigationBar: bottom ??
          (showTabs
              ? AppBottomBar(current: tabIndexFor(location), onTap: (i) => context.go(appTabs[i].path))
              : null),
    );
  }
}

/// Body padding used everywhere (16 px gutter).
class PageList extends StatelessWidget {
  const PageList({super.key, required this.children, this.onRefresh, this.controller, this.bottomPadding = 32});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      // Scrolling closes the keyboard (iOS has no key for it on multi-line fields).
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
      children: children,
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, color: Palette.brand600, child: list);
  }
}

/// Sticky bottom area for forms.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(color: c.background, border: Border(top: BorderSide(color: c.divider))),
      child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: child)),
    );
  }
}
