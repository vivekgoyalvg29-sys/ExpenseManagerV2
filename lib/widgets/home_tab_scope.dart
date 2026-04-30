import 'package:flutter/material.dart';

/// Provided by [HomeScreen] for child tabs to switch the bottom bar or run
/// "initialize defaults" for the active profile.
class HomeTabScope extends InheritedWidget {
  const HomeTabScope({
    super.key,
    required this.openCategoriesTab,
    required this.runInitializeDefaultsForActiveProfile,
    required super.child,
  });

  final VoidCallback openCategoriesTab;
  final Future<void> Function() runInitializeDefaultsForActiveProfile;

  static HomeTabScope? maybeOf(BuildContext context) {
    return context.findAncestorWidgetOfExactType<HomeTabScope>();
  }

  @override
  bool updateShouldNotify(HomeTabScope oldWidget) {
    return openCategoriesTab != oldWidget.openCategoriesTab ||
        runInitializeDefaultsForActiveProfile != oldWidget.runInitializeDefaultsForActiveProfile;
  }
}
