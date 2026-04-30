import 'package:flutter/material.dart';

import '../services/entitlement_service.dart';

/// Button label for toggling shareable on an owned profile: "(Pro)" only when Free.
class MakeSharableActionLabel extends StatelessWidget {
  const MakeSharableActionLabel({
    super.key,
    required this.isCurrentlySharable,
  });

  final bool isCurrentlySharable;

  @override
  Widget build(BuildContext context) {
    if (isCurrentlySharable) {
      return const Text('Make private', style: TextStyle(fontSize: 12));
    }
    return FutureBuilder<UserTier>(
      future: EntitlementService.getCurrentTier(),
      builder: (context, snap) {
        final pro = snap.data == UserTier.pro;
        return Text(
          pro ? 'Make sharable' : 'Make sharable (Pro)',
          style: const TextStyle(fontSize: 12),
        );
      },
    );
  }
}
