// History calendar (month grid with a photo of the day, BeReal-style) and the day review.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/text.dart';
import '../../ui/kit.dart';
import '../../ui/rows.dart';
import '../../ui/scaffold.dart';
import '../photos/photo_section.dart';
import '../../core/i18n.dart';

class HistoryCalendar extends ConsumerStatefulWidget {
  const HistoryCalendar({super.key});
  @override
  ConsumerState<HistoryCalendar> createState() => _HistoryCalendarState();
}

class _HistoryCalendarState extends ConsumerState<HistoryCalendar> {
  late DateTime _month = DateTime(today().year, today().month);

  void _shift(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = ref.watch(historyMonthProvider(_month));
    final rdvs = value.value ?? const <Rendezvous>[];
    final byDay = <DateTime, List<Rendezvous>>{};
    for (final r in rdvs) {
      byDay.putIfAbsent(dayOf(r.appointmentAt), () => []).add(r);
    }
    final met = rdvs.where((r) => r.status == RdvStatus.valide).length;
    final isCurrentMonth = _month.year == today().year && _month.month == today().month;

    // Monday-first grid
    final first = DateTime(_month.year, _month.month);
    final lead = (first.weekday + 6) % 7;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = lead + days;
    final rows = (cells / 7).ceil();
    final weekdays = [for (var i = 0; i < 7; i++) DateFormat('EEEEE').format(DateTime(2024, 1, 1 + i)).toUpperCase()];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        IconButton(tooltip: tr.prevMonth, onPressed: () => _shift(-1), icon: Icon(LucideIcons.chevronLeft, color: c.brandText)),
        Expanded(
          child: Text(monthLabel(_month),
              textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
        ),
        IconButton(
          tooltip: tr.nextMonth,
          onPressed: isCurrentMonth ? null : () => _shift(1),
          icon: Icon(LucideIcons.chevronRight, color: isCurrentMonth ? c.textSubtle : c.brandText),
        ),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        for (final w in weekdays)
          Expanded(child: Text(w, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textMuted))),
      ]),
      const SizedBox(height: 6),
      for (var row = 0; row < rows; row++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            for (var col = 0; col < 7; col++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: AspectRatio(
                    aspectRatio: 0.8,
                    child: () {
                      final index = row * 7 + col - lead;
                      if (index < 0 || index >= days) return const SizedBox();
                      final day = DateTime(_month.year, _month.month, index + 1);
                      return _DayCell(day: day, rdvs: byDay[day] ?? const []);
                    }(),
                  ),
                ),
              ),
          ]),
        ),
      const SizedBox(height: 6),
      if (value.hasError)
        ErrorCard(error: value.error!, onRetry: () => ref.invalidate(historyMonthProvider(_month)))
      else
        Text(
          value.isLoading && !value.hasValue
              ? tr.loading
              : met == 0
                  ? tr.calendarNoneThisMonth
                  : tr.calendarMetInMonth(met, DateFormat.MMMM().format(_month)),
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textMuted, fontSize: 14),
        ),
    ]);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.rdvs});
  final DateTime day;
  final List<Rendezvous> rdvs;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isToday = day == today();
    final future = day.isAfter(today());
    final met = rdvs.where((r) => r.status == RdvStatus.valide).toList();
    final photo = met.expand((r) => r.photos).firstOrNull ?? rdvs.expand((r) => r.photos).firstOrNull;
    final hasEvents = rdvs.isNotEmpty;
    final onlyCancelled = hasEvents && met.isEmpty;

    final number = Text(
      '${day.day}',
      style: TextStyle(
        fontSize: 14,
        fontWeight: hasEvents || isToday ? FontWeight.w700 : FontWeight.w500,
        color: photo != null ? Colors.white : (future ? c.textSubtle : (met.isNotEmpty ? Colors.white : c.text)),
        shadows: photo != null ? const [Shadow(color: Colors.black54, blurRadius: 4)] : null,
      ),
    );

    final Widget body;
    if (photo != null) {
      body = Stack(fit: StackFit.expand, children: [
        StorageImage(photo.previewPath, cacheWidth: 200),
        Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.all(5), child: number)),
        if (rdvs.length > 1)
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: Text('${rdvs.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
      ]);
    } else {
      body = Container(
        color: met.isNotEmpty ? Palette.brand600 : (onlyCancelled ? c.secondaryFill : Colors.transparent),
        alignment: Alignment.center,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          number,
          if (onlyCancelled) Icon(LucideIcons.x, size: 12, color: c.textSubtle),
          if (met.length > 1) Text('×${met.length}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      );
    }

    return Semantics(
      button: hasEvents,
      label: '${formatDayMonth(day)}${hasEvents ? ', ${tr.calendarDayEvents(rdvs.length)}' : ''}',
      child: GestureDetector(
        onTap: hasEvents ? () => context.push('/history/day/${dayIso(day)}') : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isToday ? Border.all(color: c.brandText, width: 2) : null,
          ),
          child: ClipRRect(borderRadius: BorderRadius.circular(isToday ? 8 : 10), child: body),
        ),
      ),
    );
  }
}

/// "Revue du jour": the rendezvous of a day with all their photos.
class DayReviewScreen extends ConsumerWidget {
  const DayReviewScreen({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final value = ref.watch(historyDayProvider(day));
    return AppScaffold(
      title: capitalize(formatDateLong(day)),
      back: true,
      body: AsyncBody(
        value: value,
        onRetry: () => ref.invalidate(historyDayProvider(day)),
        builder: (rdvs) {
          if (rdvs.isEmpty) {
            return PageList(children: [EmptyState(icon: LucideIcons.calendarX, title: tr.dayNoEvents)]);
          }
          return PageList(
            onRefresh: () => ref.refresh(historyDayProvider(day).future),
            children: [
              const SizedBox(height: 4),
              Text(
                tr.dayMetCount(rdvs.where((r) => r.status == RdvStatus.valide).length),
                style: TextStyle(color: c.textMuted, fontSize: 15),
              ),
              for (final r in rdvs) _DayEvent(rdv: r),
            ],
          );
        },
      ),
    );
  }
}

class _DayEvent extends ConsumerWidget {
  const _DayEvent({required this.rdv});
  final Rendezvous rdv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final shared = rdv.isShared ? ref.watch(sharedRdvPhotosProvider(rdv.id)).value ?? const <Photo>[] : const <Photo>[];
    final photos = [...rdv.photos, ...shared]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 16),
      RowsCard(children: [RdvRow(rdv: rdv, dayLabel: false)]),
      if (rdv.notes != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(rdv.notes!, style: TextStyle(color: c.text, fontSize: 15, height: 1.4)),
        ),
      if (photos.isNotEmpty) ...[
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (var i = 0; i < photos.length; i++)
              GestureDetector(
                onTap: () => openPhotoViewer(context, photos, i),
                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: StorageImage(photos[i].previewPath, cacheWidth: 360)),
              ),
          ],
        ),
      ],
    ]);
  }
}
