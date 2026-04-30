import 'package:flutter/material.dart';

import '../services/entitlement_service.dart';
import '../services/recurring_expense_service.dart';

bool _recurringExpensePreviewShowing = false;

Future<void> maybeShowRecurringExpensePreview(BuildContext context) async {
  if (_recurringExpensePreviewShowing) return;
  try {
    if (!await EntitlementService.isPro) return;
    if (!await canUserRunRecurringEngine()) return;
    final items = await computePendingOccurrences();
    if (items.isEmpty || !context.mounted) return;
    _recurringExpensePreviewShowing = true;
    try {
      if (!context.mounted) return;
      await showRecurringExpensePreviewDialog(context: context, initial: items);
    } finally {
      _recurringExpensePreviewShowing = false;
    }
  } catch (_) {
    _recurringExpensePreviewShowing = false;
  }
}

Future<void> showRecurringExpensePreviewDialog({
  required BuildContext context,
  required List<PendingRecurringOccurrence> initial,
}) async {
  if (initial.isEmpty) return;
  final remaining = List<PendingRecurringOccurrence>.from(initial);

  Future<void> confirmDismissOuter(BuildContext dialogCtx) async {
    if (remaining.isEmpty) {
      if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
      return;
    }
    final ok = await showDialog<bool>(
      context: dialogCtx,
      builder: (c) => AlertDialog(
        title: const Text('Skip all?'),
        content: Text(
          'All ${remaining.length} remaining item(s) will be marked skipped and will not be executed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await skipAllRecurringOccurrences(remaining);
      if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
    }
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setDlg) {
          void removeO(PendingRecurringOccurrence o) {
            setDlg(() {
              remaining.removeWhere(
                (x) =>
                    x.masterId == o.masterId && x.scheduledDateKey == o.scheduledDateKey,
              );
            });
          }

          Widget row(PendingRecurringOccurrence o) {
            final line = formatRuleSummaryLine(o);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    line,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await deferRecurringOccurrence(o);
                          removeO(o);
                        },
                        child: const Text('Not now'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await skipRecurringOccurrence(o);
                          removeO(o);
                        },
                        child: const Text('Skip'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          await runRecurringOccurrence(o);
                          removeO(o);
                        },
                        child: const Text('Run'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          final card = AlertDialog(
            title: Text(
              'Run Rules',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: remaining.isEmpty
                  ? Text(
                      'No rules to run.',
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: remaining.map(row).toList(),
                      ),
                    ),
            ),
            actions: [
              if (remaining.isEmpty)
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
            ],
          );

          return Material(
            color: Colors.black54,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => confirmDismissOuter(ctx),
                  ),
                ),
                Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 420,
                        maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
                      ),
                      child: card,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
