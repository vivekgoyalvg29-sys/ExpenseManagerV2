/// PNG seed icons under [root], one folder per slug (lowercase, spaces → `_`), files `1.png` … `3.png`.
/// On-disk folders use the same slugs so asset lookup works on case-sensitive devices (e.g. Android).
class DefaultSeedIcons {
  static const String root = 'assets/seed_icons';

  static const List<String> incomeCategoryNames = [
    'Salary',
    'Bonus',
    'Interest',
    'Rental',
  ];

  static const List<String> expenseCategoryNames = [
    'Housing',
    'Utilities',
    'Groceries',
    'Dining',
    'Transport',
    'Health',
    'Insurance',
    'Education',
    'Entertainment',
    'Shopping',
    'Subscriptions',
    'EMIs',
    'Savings',
    'Donations',
  ];

  static const List<String> accountNames = [
    'Cash',
    'Savings',
    'Credit Card',
    'UPI',
  ];

  /// Folder segment used under [root] (stable across platforms).
  static String folderSlug(String displayName) =>
      displayName.trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase();

  static String pngPath(String displayName, int variant) =>
      '$root/${folderSlug(displayName)}/$variant.png';

  /// Rewrites legacy stored paths (mixed case / spaces) to current slug form for [Image.asset].
  static String? normalizeBundledSeedIconPath(String? path) {
    if (path == null || path.isEmpty) return path;
    if (!path.startsWith('$root/')) return path;
    final parts = path.split('/');
    if (parts.length < 4) return path;
    final folderRaw = parts[2];
    final file = parts[3];
    final slug = folderSlug(folderRaw.replaceAll('_', ' '));
    return '$root/$slug/$file';
  }

  /// Default icon when seeding (`1.png`).
  static String? categoryIconPathFor(String name, String type) {
    final names = type == 'income' ? incomeCategoryNames : expenseCategoryNames;
    if (!names.contains(name)) return null;
    return pngPath(name, 1);
  }

  /// Default icon when seeding (`1.png`).
  static String? accountIconPathFor(String name) {
    if (!accountNames.contains(name)) return null;
    return pngPath(name, 1);
  }

  static String? _matchSeedCategoryName(String type, String? typed, String? original) {
    final list = type == 'income' ? incomeCategoryNames : expenseCategoryNames;
    for (final candidate in [typed, original]) {
      if (candidate == null || candidate.trim().isEmpty) continue;
      final t = candidate.trim();
      for (final n in list) {
        if (n.toLowerCase() == t.toLowerCase()) return n;
      }
    }
    return null;
  }

  static String? _matchSeedAccountName(String? typed, String? original) {
    for (final candidate in [typed, original]) {
      if (candidate == null || candidate.trim().isEmpty) continue;
      final t = candidate.trim();
      for (final n in accountNames) {
        if (n.toLowerCase() == t.toLowerCase()) return n;
      }
    }
    return null;
  }

  /// Sample PNGs for category dialog: three for a known seed name (including rename-before-save via [originalName]); otherwise full sets.
  static List<String> categorySamplePathsForEditor({
    required String type,
    String? typedName,
    String? originalName,
  }) {
    final hit = _matchSeedCategoryName(type, typedName, originalName);
    if (hit != null) {
      return [for (var v = 1; v <= 3; v++) pngPath(hit, v)];
    }
    return type == 'income'
        ? List<String>.from(allIncomeCategorySampleIconPaths)
        : List<String>.from(allExpenseCategorySampleIconPaths);
  }

  /// Sample PNGs for account dialog: three for a known seed name or full set.
  static List<String> accountSamplePathsForEditor({
    String? typedName,
    String? originalName,
  }) {
    final hit = _matchSeedAccountName(typedName, originalName);
    if (hit != null) {
      return [for (var v = 1; v <= 3; v++) pngPath(hit, v)];
    }
    return List<String>.from(allAccountSampleIconPaths);
  }

  static final List<String> allIncomeCategorySampleIconPaths = [
    for (final n in incomeCategoryNames)
      for (var v = 1; v <= 3; v++) pngPath(n, v),
  ];

  static final List<String> allExpenseCategorySampleIconPaths = [
    for (final n in expenseCategoryNames)
      for (var v = 1; v <= 3; v++) pngPath(n, v),
  ];

  static final List<String> allAccountSampleIconPaths = [
    for (final n in accountNames)
      for (var v = 1; v <= 3; v++) pngPath(n, v),
  ];
}
