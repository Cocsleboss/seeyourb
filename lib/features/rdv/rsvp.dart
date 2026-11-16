// Answer to a friend's invitation: Refuser / À confirmer / Accepter.
// "À confirmer" is the default and never notifies the organizer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';
import '../../core/i18n.dart';

Tone rsvpTone(Rsvp r) => switch (r) {
  Rsvp.pending => Tone.orange,
  Rsvp.accepted => Tone.green,
  Rsvp.declined => Tone.red,
};

/// Sends the answer; returns my copy's id (null on error).
Future<String?> answerInvitation(
  WidgetRef ref,
  String inviteId,
  Rsvp answer,
) async {
  final id = await guard(
    () => ref.read(apiProvider).respondRdvInvite(inviteId, answer),
    success: switch (answer) {
      Rsvp.accepted => tr.rsvpToastAccepted,
      Rsvp.declined => tr.rsvpToastDeclined,
      Rsvp.pending => tr.rsvpToastPending,
    },
  );
  refreshData(ref);
  return id;
}

class RsvpSelector extends StatelessWidget {
  const RsvpSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.busy,
  });

  /// null = no answer yet.
  final Rsvp? value;
  final ValueChanged<Rsvp>? onChanged;

  /// Option currently being sent (shows a spinner).
  final Rsvp? busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const order = [Rsvp.declined, Rsvp.pending, Rsvp.accepted];
    const icons = {
      Rsvp.declined: LucideIcons.x,
      Rsvp.pending: LucideIcons.clock,
      Rsvp.accepted: LucideIcons.check,
    };
    return LayoutBuilder(
      builder: (context, box) {
        // Narrow (small phones, inside cards): text only, so labels stay whole.
        final showIcons = box.maxWidth / 3 > 118;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: c.secondaryFill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              for (final r in order)
                Expanded(
                  child: Pressable(
                    onTap: onChanged == null || r == value || busy != null
                        ? null
                        : () => onChanged!(r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 40,
                      decoration: BoxDecoration(
                        color: c
                            .tone(rsvpTone(r))
                            .solid
                            .withValues(alpha: r == value ? 1 : 0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (busy == r)
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: r == value ? Colors.white : c.textMuted,
                              ),
                            )
                          else if (showIcons)
                            Icon(
                              icons[r],
                              size: 16,
                              color: r == value ? Colors.white : c.textMuted,
                            ),
                          if (busy == r || showIcons) const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              r == Rsvp.declined
                                  ? tr.rsvpDecline
                                  : (r == Rsvp.accepted
                                        ? tr.rsvpAccept
                                        : tr.rsvpMaybe),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: r == value ? Colors.white : c.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Small pill shown on tentative rendezvous in lists.
class TentativePill extends StatelessWidget {
  const TentativePill({super.key});
  @override
  Widget build(BuildContext context) =>
      Pill(Rsvp.pending.label, tone: Tone.orange, dot: true);
}
