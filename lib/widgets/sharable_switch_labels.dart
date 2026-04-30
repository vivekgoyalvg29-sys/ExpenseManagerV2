import 'package:flutter/material.dart';

import '../services/entitlement_service.dart';

/// Title for Sharable switch: shows "(Pro)" only while user is Free.
class SharableSwitchTitle extends StatelessWidget {
  const SharableSwitchTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserTier>(
      future: EntitlementService.getCurrentTier(),
      builder: (context, snap) {
        final pro = snap.data == UserTier.pro;
        return Text(pro ? 'Sharable' : 'Sharable (Pro)');
      },
    );
  }
}
