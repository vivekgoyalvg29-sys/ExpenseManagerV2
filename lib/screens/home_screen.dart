import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/data_store.dart';
import '../services/app_localizations.dart';
import '../services/data_service.dart';
import '../services/profile_service.dart';
import '../screens/profile_screen.dart';
import '../services/excel_transfer_service.dart';
import '../services/visual_settings.dart';
import '../services/widget_sync_service.dart';
import '../widgets/budget_income_mode_toggle.dart';
import '../widgets/segmented_toggle.dart';
import '../widgets/section_tile.dart';
import '../widgets/side_overlay_sheet.dart';
import 'accounts_page.dart';
import 'analysis_page.dart';
import 'budgets_page.dart';
import 'categories_page.dart';
import 'records_page.dart';
import 'sms_page.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static String _firstRunKey(String profileId) =>
      'first_run_init_prompted_$profileId';
  late int currentIndex;
  int _refreshVersion = 0;
  String _appVersion = 'v1.0.0';
  String _username = '';
  String? _activeProfileId;
  final ScrollController _menuScrollController = ScrollController();
  final GlobalKey _appearanceExpandedContentKey = GlobalKey();
  final ProfileService _profileService = ProfileService();

  void _scrollMenuAfterAppearanceExpand() {
    void run() {
      final ctx = _appearanceExpandedContentKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 1.0,
        );
      }
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!_menuScrollController.hasClients) return;
        final ctx2 = _appearanceExpandedContentKey.currentContext;
        if (ctx2 != null && ctx2.mounted) {
          Scrollable.ensureVisible(
            ctx2,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: 1.0,
          );
        }
        if (_menuScrollController.hasClients) {
          final maxExtent = _menuScrollController.position.maxScrollExtent;
          if (maxExtent > 0) {
            _menuScrollController.animateTo(
              maxExtent,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            );
          }
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => WidgetsBinding.instance.addPostFrameCallback((_) => run()));
  }

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    // Same deterministic default as _PostLoginInitScreen — avoids a race where
    // prefs are not seeded yet and the drawer shows no active profile tick/name.
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber;
    if (phone != null && phone.isNotEmpty) {
      _activeProfileId = ProfileService.defaultProfileId(phone);
    }
    _loadPackageInfo();
    _loadUsername();
    _loadRoleAndProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureFirstRunInitializationPrompt();
      _checkRevokedProfiles();
    });
  }

  Future<void> _loadRoleAndProfile() async {
    // SharedPreferences read is instant — no retry loop needed.
    try {
      final profileId = await _profileService.getActiveProfileId();
      if (!mounted) return;
      // Do not clear optimistic default when Firestore/prefs are briefly null.
      if (profileId != null && profileId.isNotEmpty) {
        setState(() => _activeProfileId = profileId);
      }
    } catch (_) {}
  }

  Future<void> _checkRevokedProfiles() async {
    try {
      final revoked = await _profileService.checkAndClearRevokedProfiles();
      if (revoked.isEmpty || !mounted) return;
      final names = revoked.join(', ');
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Profile access removed'),
          content: Text(
            'You no longer have access to the following profile(s): $names',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      await _loadRoleAndProfile();
      setState(() => _refreshVersion++);
    } catch (_) {}
  }

  @override
  void dispose() {
    _menuScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = 'v${info.version}${info.buildNumber.isEmpty ? '' : ' (${info.buildNumber})'}';
    });
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _username = prefs.getString('username') ?? '';
    });
  }

  Future<void> _openUsernameEditDialog() async {
    final controller = TextEditingController(text: _username);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Username'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Username'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final updated = controller.text.trim();
              await prefs.setString('username', updated);
              if (!mounted) return;
              setState(() => _username = updated);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _openFeedbackDialog() async {
    final bodyController = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Feedback'),
        content: TextField(
          controller: bodyController,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Describe your feedback…',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (sent != true || !mounted) {
      bodyController.dispose();
      return;
    }
    final body = bodyController.text.trim();
    bodyController.dispose();
    if (body.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback is empty.')));
      return;
    }
    final subject = Uri.encodeComponent('Feedback-Android');
    final bodyEnc = Uri.encodeComponent(body);
    final uri = Uri.parse('mailto:vivekgoyal.vg29@gmail.com?subject=$subject&body=$bodyEnc');
    final ok = await launchUrl(uri);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open email app.')));
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse('https://vivekgoyalvg29-sys.github.io/privacy-policy/');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link.')));
    }
  }

  List<_NavItem> get _navItems {
    final comparisonMode = _visualSettingsController(context).value.comparisonMode;
    final items = <_NavItem>[
      _NavItem(label: context.tr('Records'), icon: Icons.list, builder: _recordsBuilder),
      _NavItem(label: context.tr('Analysis'), icon: Icons.pie_chart, builder: _analysisBuilder),
      _NavItem(label: context.tr('Accounts'), icon: Icons.account_balance_wallet, builder: _accountsBuilder),
      _NavItem(label: context.tr('Categories'), icon: Icons.category, builder: _categoriesBuilder),
    ];
    if (comparisonMode == ComparisonMode.budgetVsExpense) {
      items.insert(2, _NavItem(label: context.tr('Budget'), icon: Icons.account_balance, builder: _budgetsBuilder));
    }
    if (DataStore.isSmsTabVisible) {
      items.add(_NavItem(label: context.tr('SMSs'), icon: Icons.sms, builder: _smsBuilder));
    }
    return items;
  }
  Future<void> _setComparisonMode(ComparisonMode mode) async {
    final controller = _visualSettingsController(context);
    if (controller.value.comparisonMode == mode) return;
    final previous = controller.value.comparisonMode;
    final previousIndex = currentIndex;
    await controller.updateSettings(controller.value.copyWith(comparisonMode: mode));
    unawaited(WidgetSyncService.syncFromStoredConfiguration());
    if (!mounted) return;
    setState(() {
      if (previous == ComparisonMode.budgetVsExpense &&
          mode == ComparisonMode.incomeVsExpense) {
        // Budget tab (index 2) is removed; keep other tabs aligned.
        if (previousIndex == 2) {
          currentIndex = 1;
        } else if (previousIndex > 2) {
          currentIndex = previousIndex - 1;
        }
      } else if (previous == ComparisonMode.incomeVsExpense &&
          mode == ComparisonMode.budgetVsExpense) {
        if (previousIndex >= 2) {
          currentIndex = previousIndex + 1;
        }
      }
      _refreshVersion++;
    });
  }


  Widget _buildIndexedTabBodies(List<_NavItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final maxI = items.length - 1;
    final idx = currentIndex < 0 ? 0 : (currentIndex > maxI ? maxI : currentIndex);
    return IndexedStack(
      index: idx,
      sizing: StackFit.expand,
      children: [
        for (var i = 0; i < items.length; i++)
          items[i].builder(ValueKey('tab-$i-$_refreshVersion'), _refreshVersion),
      ],
    );
  }

  static Widget _recordsBuilder(Key key, int refreshVersion) => RecordsPage(key: key);
  static Widget _analysisBuilder(Key key, int refreshVersion) => AnalysisPage(key: key);
  static Widget _budgetsBuilder(Key key, int refreshVersion) => BudgetsPage(key: key);
  static Widget _accountsBuilder(Key key, int refreshVersion) => AccountsPage(key: key);
  static Widget _categoriesBuilder(Key key, int refreshVersion) => CategoriesPage(key: key);
  static Widget _smsBuilder(Key key, int refreshVersion) => SmsPage(key: ValueKey('sms-${DataStore.smsTransactionsVersion}-$refreshVersion'));

  Future<void> _exportData() async {
  try {
    final exportData = await ExcelTransferService.buildExportFileData();
    final selectedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save exported file',
      fileName: exportData.fileName,
      bytes: Uint8List.fromList(exportData.bytes),
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (!mounted) return;
    if (selectedPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export cancelled.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported: $selectedPath')));
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

  Future<void> _importData() async {
    try {
      // FileType.any avoids Android's MIME-type filter that greys out xlsx files
      // saved via the filesystem. Extension is validated manually below.
      final selected = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      if (selected == null || selected.files.isEmpty) return;
      final picked = selected.files.first;
      if (!picked.name.toLowerCase().endsWith('.xlsx')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an .xlsx file.')),
        );
        return;
      }
      final bytes = picked.bytes ?? (picked.path == null ? null : await File(picked.path!).readAsBytes());
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read selected file.')));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Importing data… This may take a few seconds. You’ll see a summary when it finishes.'),
          duration: Duration(seconds: 5),
        ),
      );
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    'Importing… please wait.',
                    style: Theme.of(dialogCtx).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      late final ImportResult result;
      try {
        result = await ExcelTransferService.importAllDataFromBytes(bytes);
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        rethrow;
      }
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      setState(() => _refreshVersion++);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import summary', textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
              ),
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 12,
                  columns: const [
                    DataColumn(label: Text('Sheet')),
                    DataColumn(label: Text('In Excel')),
                    DataColumn(label: Text('Imported')),
                  ],
                  rows: result.stats
                      .map(
                        (s) => DataRow(
                          cells: [
                            DataCell(Text(s.name)),
                            DataCell(Text('${s.totalRows}')),
                            DataCell(Text('${s.importedRows}')),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _openVisualSettings() async {
    final controller = _visualSettingsController(context);
    final settings = controller.value;
    final hasSelectedFont = VisualSettings.fontOptions.any(
      (option) => option.key == settings.fontKey,
    );
    String fontKey = hasSelectedFont ? settings.fontKey : VisualSettings.defaults.fontKey;
    double textScale = settings.textScale;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Customize visuals',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(fontKey),
                  initialValue: fontKey,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'Font family',
                    labelStyle: Theme.of(context).textTheme.bodyMedium,
                  ),
                  items: VisualSettings.fontOptions.map((option) => DropdownMenuItem<String>(value: option.key, child: Text(option.label))).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => fontKey = value);
                  },
                ),
                const SizedBox(height: 20),
                Text('Text size: ${(textScale * 100).round()}%', style: Theme.of(context).textTheme.titleMedium),
                Slider(
                  value: textScale,
                  min: 0.85,
                  max: 1.35,
                  divisions: 10,
                  label: '${(textScale * 100).round()}%',
                  onChanged: (value) => setDialogState(() => textScale = value),
                ),
                const SizedBox(height: 8),
                Text(
                  'Preview text',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFamily: VisualSettings.fontOptions.firstWhere((option) => option.key == fontKey).fontFamily,
                        fontSize: 16 * textScale,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Apply a font family and overall text scaling across the app.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: VisualSettings.fontOptions.firstWhere((option) => option.key == fontKey).fontFamily,
                        fontSize: 14 * textScale,
                      ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await controller.reset();
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Reset'),
            ),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await controller.updateSettings(settings.copyWith(fontKey: fontKey, textScale: textScale));
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openThemeSettings() async {
    final controller = _visualSettingsController(context);
    var mode = controller.value.themeMode == ThemeMode.system ? ThemeMode.light : controller.value.themeMode;
    final applied = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Theme'),
          content: SizedBox(
            width: 200,
            child: SegmentedToggle<ThemeMode>(
              axis: SegmentedToggleAxis.vertical,
              options: const [
                SegmentedToggleOption(value: ThemeMode.light, label: 'Light'),
                SegmentedToggleOption(value: ThemeMode.dark, label: 'Dark'),
              ],
              selectedValue: mode,
              onChanged: (changed) => setState(() => mode = changed),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
          ],
        ),
      ),
    );
    if (applied == true) {
      await controller.updateSettings(controller.value.copyWith(themeMode: mode));
    }
  }

  Future<void> _openLanguageSettings() async {
    final controller = _visualSettingsController(context);
    String selected = controller.value.localeCode;
    final applied = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final maxW = (MediaQuery.sizeOf(context).width - 96).clamp(220.0, 340.0);
          return AlertDialog(
            title: const Text('Language'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: maxW,
                child: SegmentedToggle<String>(
                  axis: SegmentedToggleAxis.vertical,
                  options: AppLocalizations.languageLabels.entries
                      .map(
                        (entry) => SegmentedToggleOption(
                          value: entry.key,
                          label: entry.value,
                        ),
                      )
                      .toList(),
                  selectedValue: selected,
                  onChanged: (value) => setState(() => selected = value),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
            ],
          );
        },
      ),
    );
    if (applied == true) {
      await controller.updateSettings(controller.value.copyWith(localeCode: selected));
    }
  }

  Future<void> _openSearchPopup() async {
    final tx = await DataService.getTransactions();
    if (!mounted) return;
    final controller = TextEditingController();
    List<Map<String, dynamic>> matches = [];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          child: SizedBox(
            width: 520,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Search Transactions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search comment or amount',
                    ),
                    onChanged: (value) {
                      final needle = value.trim().toLowerCase();
                      setDialogState(() {
                        if (needle.isEmpty) {
                          matches = [];
                        } else {
                          matches = tx.where((item) {
                            final comment = (item['comment'] ?? '').toString().toLowerCase();
                            final amount = (item['amount'] ?? '').toString().toLowerCase();
                            return comment.contains(needle) || amount.contains(needle);
                          }).toList();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 260,
                    child: matches.isEmpty
                        ? const Center(child: Text('No matching transactions'))
                        : ListView.separated(
                            itemCount: matches.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = matches[index];
                              return ListTile(
                                dense: true,
                                title: Text(item['title']?.toString() ?? ''),
                                subtitle: Text('${item['comment'] ?? ''} • ${item['date'] ?? ''}'),
                                trailing: Text('${item['amount'] ?? ''}'),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    controller.dispose();
  }

  VisualSettingsController _visualSettingsController(BuildContext context) => VisualSettingsScope.of(context);

  Future<void> _showSmsTab() async {
    await DataStore.setSmsTabVisibility(true);
    if (!mounted) return;
    setState(() {
      if (currentIndex >= _navItems.length) currentIndex = 0;
      currentIndex = _navItems.length - 1;
    });
  }

  Future<void> _confirmAndRun({required String title, required String description, required Future<void> Function() action, required String successMessage}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text('$description\n\nThis action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('OK')),
        ],
      ),
    );
    if (confirmed != true) return;
    await action();
    if (!mounted) return;
    setState(() {
      currentIndex = 0;
      _refreshVersion++;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
  }

  // ─── Helpers for profile-aware data management ──────────────────────────────

  /// Returns the active profile and the caller's role in it.
  Future<(ProfileModel?, String?)> _fetchActiveProfileContext() async {
    try {
      final profile = await _profileService.getActiveProfile();
      if (profile == null) return (null, null);
      final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
      final role = profile.members[phone];
      return (profile, role);
    } catch (_) {
      return (null, null);
    }
  }

  /// Returns all profiles the user is part of, pre-categorised for the reset flow.
  Future<_ResetContext> _fetchResetContext() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    if (phone.isEmpty) return _ResetContext.empty();
    try {
      final profiles = await _profileService
          .getMyProfiles()
          .first
          .timeout(const Duration(seconds: 8));
      return _ResetContext.from(profiles, phone);
    } catch (_) {
      return _ResetContext.empty();
    }
  }

  // ─── Data management actions ────────────────────────────────────────────────

  Future<void> _deleteEverything() async {
    final (activeProfile, role) = await _fetchActiveProfileContext();
    if (!mounted) return;

    final profileName = activeProfile?.name ?? 'your profile';
    final buffer = StringBuffer(
      'This will permanently remove all records, budgets, accounts, and categories'
      ' in "$profileName". Visual settings will stay unchanged.',
    );

    if (activeProfile != null && activeProfile.isShareable) {
      final memberCount = activeProfile.members.length - 1;
      if (role == 'owner' && memberCount > 0) {
        buffer.write(
          '\n\nThis is a shared profile with $memberCount other member(s). '
          'All of them will see empty data after this.',
        );
      } else if (role != 'owner') {
        buffer.write(
          '\n\nThis is a shared profile. '
          'All members will lose their data.',
        );
      }
    }

    await _confirmAndRun(
      title: 'Delete everything?',
      description: buffer.toString(),
      action: () async {
        await DataService.deleteAllData();
        await DataStore.resetLocalState();
        await WidgetSyncService.syncFromStoredConfiguration();
      },
      successMessage: 'All records, budgets, accounts, and categories were deleted.',
    );
  }

  Future<void> _deleteTransactionsOnly() async {
    final (activeProfile, role) = await _fetchActiveProfileContext();
    if (!mounted) return;

    final profileName = activeProfile?.name ?? 'your profile';
    final buffer = StringBuffer(
      'This will remove all transaction records from "$profileName". '
      'Budgets, accounts, categories, and visual settings will remain.',
    );

    if (activeProfile != null && activeProfile.isShareable) {
      final memberCount = activeProfile.members.length - 1;
      if (role == 'owner' && memberCount > 0) {
        buffer.write(
          '\n\nThis is a shared profile with $memberCount other member(s). '
          'Their transaction history will also be cleared.',
        );
      } else if (role != 'owner') {
        buffer.write(
          '\n\nThis is a shared profile. '
          'All members will lose their transaction history.',
        );
      }
    }

    await _confirmAndRun(
      title: 'Delete all transactions?',
      description: buffer.toString(),
      action: () async {
        await DataService.deleteAllTransactions();
        DataStore.replaceSmsTransactions([]);
        await WidgetSyncService.syncFromStoredConfiguration();
      },
      successMessage: 'All transactions were deleted.',
    );
  }

  Future<void> _resetApp() async {
    // Fetch all profile context before showing the dialog.
    final ctx = await _fetchResetContext();
    if (!mounted) return;

    // Build a bullet-point list of consequences.
    final bullets = <String>[
      '• Clear all saved data, SMS items, and visual settings',
      '• Reset your default profile to empty',
    ];

    if (ctx.ownedShareable.isNotEmpty) {
      final names = ctx.ownedShareable.map((p) => '"${p.name}"').join(', ');
      bullets.add(
        '• DELETE your shared profile(s) $names — '
        'all members will lose access immediately',
      );
    }
    if (ctx.ownedPrivate.isNotEmpty) {
      final names = ctx.ownedPrivate.map((p) => '"${p.name}"').join(', ');
      bullets.add('• Delete your private profile(s) $names and all their data');
    }
    if (ctx.joined.isNotEmpty) {
      final names = ctx.joined.map((p) => '"${p.name}"').join(', ');
      bullets.add(
        '• Leave the shared profile(s) $names — '
        'you will lose access to their data',
      );
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reset app?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will:'),
              const SizedBox(height: 8),
              ...bullets.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(b),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This action cannot be undone.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(dialogCtx).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogCtx).colorScheme.error,
              foregroundColor: Theme.of(dialogCtx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show a non-dismissible progress dialog while operations run.
    // Capture the dialog's own context so we can dismiss it reliably even if
    // the parent widget tree rebuilds during the async operations below.
    BuildContext? progressCtx;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        progressCtx = ctx;
        return const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Resetting…'),
            ],
          ),
        );
      },
    );

    try {
      // 1. Leave all profiles where the user is NOT the owner.
      for (final p in ctx.joined) {
        try {
          await _profileService.leaveProfile(p.id);
        } catch (_) {}
      }

      // 2. Delete all owned non-default profiles — this runs the full delete
      //    workflow (member notifications, subcollection cleanup) for each.
      for (final p in [...ctx.ownedShareable, ...ctx.ownedPrivate]) {
        try {
          await _profileService.deleteProfile(p.id);
        } catch (_) {}
      }

      // 3. Wipe data in the default / active profile and reset local state.
      await DataService.deleteAllData();
      await DataStore.resetLocalState();
      if (mounted) await _visualSettingsController(context).reset();
      await WidgetSyncService.syncFromStoredConfiguration();
    } finally {
      // Dismiss using the dialog's own context — more reliable than the parent
      // context after state changes triggered by the reset operations above.
      final dlg = progressCtx;
      if (dlg != null && dlg.mounted) {
        Navigator.of(dlg).pop();
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    }

    if (!mounted) return;
    setState(() {
      currentIndex = 0;
      _refreshVersion++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The app has been reset.')),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to verify your phone number again to sign back in.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed != true) return;
    await FirebaseAuth.instance.signOut();
    await ProfileService().clearProfilePrefsForLogout();
  }

  Future<void> _ensureFirstRunInitializationPrompt() async {
    final profileId = await _profileService.getActiveProfileId();
    if (profileId == null || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _firstRunKey(profileId);
    final prompted = prefs.getBool(key) ?? false;
    if (prompted || !mounted) return;

    await prefs.setBool(key, true);
    await _showInitializeDefaultsDialog(fromMenu: false, targetProfileId: profileId);
  }

  Future<void> _showInitializeDefaultsDialog({
    required bool fromMenu,
    String? targetProfileId,
  }) async {
    if (!mounted) return;
    final shouldInitialize = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create General Categories and Accounts?'),
        content: const Text(
          'Create general categories and accounts now?\n\nYou can still add them later from Main Menu > Data management.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(fromMenu ? 'Cancel' : 'Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (shouldInitialize != true) {
      if (!fromMenu && !mounted) return;
      if (!fromMenu) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You can create general categories and accounts later from Main Menu > Data management.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;

    BuildContext? progressCtx;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        progressCtx = ctx;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  Text(
                    'Creating general categories and accounts…',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    int created = 0;
    try {
      if (targetProfileId != null) {
        created = await DataService.initializeDefaultCategoriesAndAccountsForProfile(
            targetProfileId);
      } else {
        created = await DataService.initializeDefaultCategoriesAndAccounts();
      }
    } finally {
      final dlg = progressCtx;
      if (dlg != null && dlg.mounted) {
        Navigator.of(dlg).pop();
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    }

    if (!mounted) return;
    setState(() => _refreshVersion++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created == 0
              ? 'General categories and accounts are already available.'
              : 'Added $created general categories/accounts.',
        ),
      ),
    );
  }

  Future<void> _showNewProfileDialog() async {
    final nameController = TextEditingController();
    bool isShareable = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          title: const Text('New Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Profile name'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sharable'),
                subtitle: const Text('Allow others to join with a code'),
                value: isShareable,
                onChanged: (v) => setDlg(() => isShareable = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    final name = nameController.text.trim();
    nameController.dispose();
    if (confirmed != true || name.isEmpty || !mounted) return;

    try {
      final profileId = await _profileService.createProfile(
        name,
        isShareable: isShareable,
      );
      if (!mounted) return;
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      final shouldSwitch = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Switch Profile?'),
          content: Text('Profile "$name" created. Switch to it now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Switch'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (shouldSwitch == true) {
        try {
          await _profileService.switchProfile(profileId);
        } catch (_) {}
        if (!mounted) return;
        setState(() {
          _activeProfileId = profileId;
          _refreshVersion++;
        });
      } else {
        // Still on the previous profile — no switch ran during create.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile "$name" created.')),
        );
      }

      // Step 2: offer to initialize defaults for the newly created profile
      if (!mounted) return;
      await _showInitializeDefaultsDialog(
        fromMenu: false,
        targetProfileId: profileId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showJoinProfileDialog() async {
    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Profile'),
        content: TextField(
          controller: codeController,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          decoration:
              const InputDecoration(hintText: 'Enter 6-character code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, codeController.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    codeController.dispose();
    if (code == null || code.isEmpty || !mounted) return;
    try {
      final profile = await _profileService.joinProfileByCode(code);
      if (!mounted) return;
      final role =
          profile.members[FirebaseAuth.instance.currentUser?.phoneNumber ?? ''] ??
              'viewer';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Joined "${profile.name}" as ${role == 'editor' ? 'editor' : 'viewer'}.'),
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleAppBarAction(String action) async {
    switch (action) {
      case 'export':
        await _exportData();
        return;
      case 'import':
        await _importData();
        return;
      case 'customize_visuals':
        await _openVisualSettings();
        return;
      case 'theme':
        await _openThemeSettings();
        return;
      case 'language':
        await _openLanguageSettings();
        return;
      case 'open_sms':
        await _showSmsTab();
        return;
      case 'delete_everything':
        await _deleteEverything();
        return;
      case 'delete_transactions':
        await _deleteTransactionsOnly();
        return;
      case 'reset_app':
        await _resetApp();
        return;
      case 'logout':
        await _logout();
        return;
      case 'initialize_defaults':
        await _showInitializeDefaultsDialog(fromMenu: true);
        return;
      case 'edit_username':
        await _openUsernameEditDialog();
        return;
    }
  }

  Future<void> _openAppMenu(VisualSettings settings) async {
    if (!mounted) return;

    showSideOverlaySheet<void>(
      context: context,
      direction: SideOverlayDirection.left,
      builder: (drawerContext) {
        Future<void> handleSelection(String action) async {
          Navigator.of(drawerContext).pop();
          await _handleAppBarAction(action);
        }

        final user = FirebaseAuth.instance.currentUser;
        final phoneNumber = user?.phoneNumber ?? '';
        final displayName = _username.isNotEmpty
            ? '$_username ($phoneNumber)'
            : phoneNumber;
        final themeLabel = settings.themeMode == ThemeMode.dark ? 'Dark' : 'Light';

        Widget menuTile({
          required IconData icon,
          required String title,
          String? subtitle,
          VoidCallback? onTap,
          bool enabled = true,
        }) {
          final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: enabled ? null : Theme.of(context).disabledColor,
              );
          return ListTile(
            enabled: enabled,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            minVerticalPadding: 8,
            leading: Icon(icon, size: 20, color: enabled ? null : Theme.of(context).disabledColor),
            title: Text(title, style: titleStyle),
            subtitle: subtitle == null
                ? null
                : Text(subtitle, style: enabled ? null : TextStyle(color: Theme.of(context).disabledColor)),
            onTap: enabled ? onTap : null,
          );
        }

        bool profilesExpanded = false;
        bool dataExpanded = false;

        return StatefulBuilder(
          builder: (_, setMenuState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kharcha Book',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _appVersion,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (displayName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Edit username',
                                onPressed: () async {
                                  Navigator.of(drawerContext).pop();
                                  await _openUsernameEditDialog();
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.of(drawerContext).pop(), icon: const Icon(Icons.close), tooltip: 'Close menu'),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: ListView(
                controller: _menuScrollController,
                padding: const EdgeInsets.only(bottom: 36),
                children: [
                  // ---- Profiles section ----
                  StreamBuilder<List<ProfileModel>>(
                    stream: _profileService.getMyProfiles(),
                    builder: (ctx, snap) {
                      final profiles = snap.data ?? [];
                      final myPhone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

                      // Active profile — used to label the header
                      final activeProfile = profiles.cast<ProfileModel?>().firstWhere(
                        (p) => p?.id == _activeProfileId,
                        orElse: () => null,
                      );
                      final activeLabel = activeProfile != null
                          ? ' (${activeProfile.name} · ${activeProfile.isShareable ? 'Shared' : 'Private'})'
                          : '';

                      // My Profiles: default + owned non-shareable
                      final myProfiles = profiles
                          .where((p) => p.isDefault || (!p.isShareable && p.members[myPhone] == 'owner'))
                          .toList();
                      // Shared Profiles: owned shareable + joined as member
                      final sharedProfiles = profiles
                          .where((p) => p.isShareable || p.members[myPhone] == 'member')
                          .toList();

                      Widget subHeader(String label) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 14, 6),
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                letterSpacing: 0.2,
                              ),
                        ),
                      );

                      Widget profileTile(ProfileModel profile) {
                        final isActive = profile.id == _activeProfileId;
                        return ListTile(
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                          leading: Icon(
                            profile.isDefault ? Icons.folder_special_outlined : Icons.folder_outlined,
                            size: 20,
                            color: isActive ? Theme.of(context).colorScheme.primary : null,
                          ),
                          title: Text(
                            profile.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                              color: isActive ? Theme.of(context).colorScheme.primary : null,
                            ),
                          ),
                          trailing: isActive
                              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary, size: 18)
                              : null,
                          onTap: isActive
                              ? null
                              : () async {
                                  Navigator.of(drawerContext).pop();
                                  try {
                                    await _profileService.switchProfile(profile.id);
                                  } catch (_) {}
                                  if (!mounted) return;
                                  setState(() {
                                    _activeProfileId = profile.id;
                                    _refreshVersion++;
                                  });
                                },
                        );
                      }

                      Widget actionTile({required IconData icon, required String title, required VoidCallback onTap}) =>
                          ListTile(
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                            leading: Icon(icon, size: 20),
                            title: Text(
                              title,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
                            ),
                            onTap: onTap,
                          );

                      Future<void> openManageProfiles() async {
                        Navigator.of(drawerContext).pop();
                        await showGeneralDialog<void>(
                          context: context,
                          barrierDismissible: true,
                          barrierLabel: 'Close',
                          barrierColor: const Color(0x66000000),
                          transitionDuration: const Duration(milliseconds: 220),
                          transitionBuilder: (ctx, anim, _, child) => FadeTransition(
                            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                            child: child,
                          ),
                          pageBuilder: (ctx, _, __) {
                            final h = MediaQuery.sizeOf(context).height;
                            return BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                              child: Center(
                                child: Dialog(
                                  insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                  clipBehavior: Clip.antiAlias,
                                  backgroundColor: Theme.of(context).colorScheme.surface,
                                  surfaceTintColor: Colors.transparent,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: 460,
                                      maxHeight: h * 0.72,
                                    ),
                                    child: const ManageProfilesScreen(),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                        await _loadRoleAndProfile();
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: InkWell(
                              onTap: () => setMenuState(() => profilesExpanded = !profilesExpanded),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                          children: [
                                            const TextSpan(text: 'Profiles'),
                                            if (activeLabel.isNotEmpty)
                                              TextSpan(
                                                text: activeLabel,
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  fontSize: 13,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      profilesExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      size: 20,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          ListTile(
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                            leading: const Icon(Icons.manage_accounts_outlined, size: 20),
                            title: const Text(
                              'Manage profiles',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
                            ),
                            onTap: openManageProfiles,
                          ),
                          if (profilesExpanded) ...[
                            if (myProfiles.isNotEmpty) ...[
                              subHeader('My Profiles'),
                              ...myProfiles.map(profileTile),
                            ],
                            if (sharedProfiles.isNotEmpty) ...[
                              subHeader('Shared Profiles'),
                              ...sharedProfiles.map(profileTile),
                            ],
                            actionTile(
                              icon: Icons.add_circle_outline,
                              title: 'New profile',
                              onTap: () async {
                                Navigator.of(drawerContext).pop();
                                await _showNewProfileDialog();
                              },
                            ),
                            actionTile(
                              icon: Icons.qr_code_outlined,
                              title: 'Join with invite code',
                              onTap: () async {
                                Navigator.of(drawerContext).pop();
                                await _showJoinProfileDialog();
                              },
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const Divider(height: 1, thickness: 1),
                  // ---- End Profiles section ----
                  // ---- Data management section ----
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: InkWell(
                      onTap: () => setMenuState(() => dataExpanded = !dataExpanded),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Data management',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                            Icon(
                              dataExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              size: 20,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (dataExpanded) ...[
                    menuTile(icon: Icons.upload_file_outlined, title: 'Export (Excel)', onTap: () => handleSelection('export')),
                    menuTile(icon: Icons.download_outlined, title: 'Import (Excel)', onTap: () => handleSelection('import')),
                    menuTile(icon: Icons.playlist_add_check_circle_outlined, title: 'Create General Categories and Accounts', onTap: () => handleSelection('initialize_defaults')),
                    menuTile(icon: Icons.delete_forever_outlined, title: 'Delete everything', onTap: () => handleSelection('delete_everything')),
                    menuTile(icon: Icons.receipt_long_outlined, title: 'Delete transactions', onTap: () => handleSelection('delete_transactions')),
                    menuTile(icon: Icons.restart_alt_outlined, title: 'Reset app', onTap: () => handleSelection('reset_app')),
                  ],
                  const Divider(height: 1, thickness: 1),
                  const _MenuSectionHeader('Visuals', compact: true),
                  ExpansionTile(
                    title: Text(
                      'Appearance',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    leading: const Icon(Icons.palette_outlined, size: 22),
                    onExpansionChanged: (expanded) {
                      if (!expanded) return;
                      _scrollMenuAfterAppearanceExpand();
                    },
                    children: [
                      KeyedSubtree(
                        key: _appearanceExpandedContentKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            menuTile(
                              icon: Icons.dark_mode_outlined,
                              title: 'Theme',
                              subtitle: themeLabel,
                              onTap: () => handleSelection('theme'),
                            ),
                            menuTile(
                              icon: Icons.font_download_outlined,
                              title: 'Font',
                              subtitle: '${settings.fontLabel} • ${(settings.textScale * 100).round()}%',
                              onTap: () => handleSelection('customize_visuals'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1, thickness: 1),
                  const _MenuSectionHeader('Application'),
                  menuTile(
                    icon: Icons.feedback_outlined,
                    title: 'Feedback',
                    onTap: () async {
                      Navigator.of(drawerContext).pop();
                      await _openFeedbackDialog();
                    },
                  ),
                  menuTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy policy',
                    onTap: () async {
                      Navigator.of(drawerContext).pop();
                      await _openPrivacyPolicy();
                    },
                  ),
                  menuTile(
                    icon: Icons.logout_outlined,
                    title: 'Logout',
                    onTap: () => handleSelection('logout'),
                  ),
                ],
              ),
            ),
          ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _visualSettingsController(context);
    final items = _navItems;
    if (currentIndex >= items.length) currentIndex = 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 88,
        leading: IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () => _openAppMenu(controller.value), tooltip: 'Open menu'),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Kharcha Book',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
            ),
            const SizedBox(height: 6),
            BudgetIncomeModeToggle(
              mode: controller.value.comparisonMode,
              onChanged: (m) => unawaited(_setComparisonMode(m)),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openSearchPopup,
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: 'Search',
          ),
        ],
      ),
      body: _buildIndexedTabBodies(items),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SectionTile(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            backgroundColor: Colors.transparent,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
            onTap: (index) => setState(() => currentIndex = index),
            items: [for (final item in items) BottomNavigationBarItem(icon: Icon(item.icon), label: item.label)],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final Widget Function(Key key, int refreshVersion) builder;

  const _NavItem({required this.label, required this.icon, required this.builder});
}

/// Categorised snapshot of the user's profiles used by the reset flow.
class _ResetContext {
  final List<ProfileModel> ownedShareable; // non-default, owned, shareable
  final List<ProfileModel> ownedPrivate;   // non-default, owned, not shareable
  final List<ProfileModel> joined;         // any profile where role != 'owner'

  const _ResetContext({
    required this.ownedShareable,
    required this.ownedPrivate,
    required this.joined,
  });

  factory _ResetContext.empty() => const _ResetContext(
    ownedShareable: [],
    ownedPrivate: [],
    joined: [],
  );

  factory _ResetContext.from(List<ProfileModel> profiles, String phone) {
    return _ResetContext(
      ownedShareable: profiles
          .where((p) => !p.isDefault && p.members[phone] == 'owner' && p.isShareable)
          .toList(),
      ownedPrivate: profiles
          .where((p) => !p.isDefault && p.members[phone] == 'owner' && !p.isShareable)
          .toList(),
      joined: profiles
          .where((p) => p.members[phone] != 'owner')
          .toList(),
    );
  }
}

class _MenuSectionHeader extends StatelessWidget {
  final String title;
  final bool compact;

  const _MenuSectionHeader(this.title, {this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, compact ? 8 : 12, 14, compact ? 6 : 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
