import 'package:flutter/material.dart';

/// Result of [showFeatureComparisonForShareable].
enum ShareComparisonResult {
  /// User closed the dialog (Cancel or X).
  dismissed,

  /// User chose Become a Pro — caller should run email auth then continue.
  proContinue,
}

/// Pro upgrade comparison for sharing and related gates. Shown as a sized dialog (not full screen).
Future<ShareComparisonResult?> showFeatureComparisonForShareable(
  BuildContext context,
) {
  return showDialog<ShareComparisonResult>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final cs = theme.colorScheme;

      Widget cellIcon(bool included) {
        return Icon(
          included ? Icons.check_circle : Icons.cancel_outlined,
          size: 20,
          color: included ? cs.primary : cs.outline,
        );
      }

      TableRow featureRow(String label, bool free, bool pro) {
        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(label, style: theme.textTheme.bodyMedium),
            ),
            Center(child: cellIcon(free)),
            Center(child: cellIcon(pro)),
          ],
        );
      }

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Kharcha Manager Pro',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          Navigator.pop(ctx, ShareComparisonResult.dismissed),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.42,
                  ),
                  child: SingleChildScrollView(
                    child: Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2.4),
                            1: FlexColumnWidth(0.65),
                            2: FlexColumnWidth(0.65),
                          },
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Feature',
                                    style: theme.textTheme.labelLarge
                                        ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Text(
                                    'Free',
                                    style: theme.textTheme.labelLarge
                                        ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Text(
                                    'Pro',
                                    style: theme.textTheme.labelLarge
                                        ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            featureRow(
                              'Multiple local expense profiles',
                              true,
                              true,
                            ),
                            featureRow(
                              'Create shared profile (invite code)',
                              false,
                              true,
                            ),
                            featureRow(
                              'Set up recurring expenses',
                              false,
                              true,
                            ),
                            featureRow(
                              'Advanced insights',
                              false,
                              true,
                            ),
                            featureRow(
                              'Smart Budget Copy',
                              false,
                              true,
                            ),
                            featureRow(
                              'Aggregated expense/budget analysis',
                              false,
                              true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Next step: complete purchase in Google Play.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(ctx, ShareComparisonResult.proContinue),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Continue to Google Play'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx, ShareComparisonResult.dismissed),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Brief notice when Firebase Auth succeeds but there is no Pro / Firestore user data yet,
/// then opens [showFeatureComparisonForShareable] for the normal upgrade flow.
Future<ShareComparisonResult?> showNonProCloudAccountNoticeThenComparison(
  BuildContext context,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogCtx) {
      Future<void>.delayed(const Duration(milliseconds: 3600), () {
        if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
      });
      return AlertDialog(
        title: const Text('Kharcha Manager Pro'),
        content: const Text(
          'Only Pro users are allowed to create an account. '
          'Subscribe with Become a Pro to enable your cloud books.',
        ),
      );
    },
  );
  if (!context.mounted) return null;
  return showFeatureComparisonForShareable(context);
}
