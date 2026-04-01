import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/data_store.dart';
import '../services/app_localizations.dart';
import '../services/data_service.dart';
import '../services/profile_service.dart';
import '../screens/profile_screen.dart';
import '../services/excel_transfer_service.dart';
import '../services/visual_settings.dart';
import '../services/widget_sync_service.dart';
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
  static const String _firstRunInitPromptedKey = 'first_run_init_prompted';
  late int currentIndex;
  int _refreshVersion = 0;
  String _appVersion = 'v1.0.0';
  String _username = '';
  String? _userRole;
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
    _loadPackageInfo();
    _loadUsername();
    _loadRoleAndProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureFirstRunInitializationPrompt();
    });
  }

  Future<void> _loadRoleAndProfile() async {
    try {
      final role = await DataService.getCurrentUserRole();
      final profileId = await _profileService.getActiveProfileId();
      if (!mounted) return;
      setState(() {
        _userRole = role;
        _activeProfileId = profileId;
      });
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
    final user = FirebaseAuth.instance.currentUser;
    final phone = user?.phoneNumber ?? '';
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
    final subject = Uri.encodeComponent('Feedback-Android-$phone');
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
    await controller.updateSettings(controller.value.copyWith(comparisonMode: mode));
    if (!mounted) return;
    setState(() {
      currentIndex = 0;
      _refreshVersion++;
    });
  }


  Widget _buildCurrentPage() {
    final pageKey = ValueKey('$currentIndex-$_refreshVersion');
    final safeIndex = currentIndex >= 0 && currentIndex < _navItems.length ? currentIndex : 0;
    final item = _navItems[safeIndex];
    return item.builder(pageKey, _refreshVersion);
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
      final supportsSaveDialog = !Platform.isLinux && !Platform.isWindows && !Platform.isMacOS;
      if (supportsSaveDialog) {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export completed: $selectedPath')));
        return;
      }
      final fallbackPath = await ExcelTransferService.exportAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export completed: $fallbackPath')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importData() async {
    try {
      final selected = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
      if (selected == null || selected.files.isEmpty) return;
      final picked = selected.files.first;
      final bytes = picked.bytes ?? (picked.path == null ? null : await File(picked.path!).readAsBytes());
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read selected file.')));
        return;
      }
      final result = await ExcelTransferService.importAllDataFromBytes(bytes);
      if (!mounted) return;
      setState(() => _refreshVersion++);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import summary', textAlign: TextAlign.center),
          content: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Sheet')),
                DataColumn(label: Text('In Excel')),
                DataColumn(label: Text('Imported')),
              ],
              rows: result.stats.map((s) => DataRow(cells: [DataCell(Text(s.name)), DataCell(Text('${s.totalRows}')), DataCell(Text('${s.importedRows}'))])).toList(),
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
          title: const Text('Customize visuals'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: fontKey,
                  decoration: const InputDecoration(labelText: 'Font family'),
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
              shrinkWidth: true,
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
                  shrinkWidth: true,
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

  Future<void> _deleteEverything() async {
    await _confirmAndRun(
      title: 'Delete everything?',
      description: 'This will permanently remove all records, budgets, accounts, and categories. Visual settings will stay unchanged.',
      action: () async {
        await DataService.deleteAllData();
        await DataStore.resetLocalState();
        await WidgetSyncService.syncFromStoredConfiguration();
      },
      successMessage: 'All records, budgets, accounts, and categories were deleted.',
    );
  }

  Future<void> _deleteTransactionsOnly() async {
    await _confirmAndRun(
      title: 'Delete all transactions?',
      description: 'This will remove all transaction records only. Budgets, accounts, categories, and visual settings will remain available.',
      action: () async {
        await DataService.deleteAllTransactions();
        DataStore.replaceSmsTransactions([]);
        await WidgetSyncService.syncFromStoredConfiguration();
      },
      successMessage: 'All transactions were deleted.',
    );
  }

  Future<void> _resetApp() async {
    await _confirmAndRun(
      title: 'Reset app?',
      description: 'This will clear all saved data, hide the SMS tab again, remove imported SMS items, and restore visual settings to their default values.',
      action: () async {
        await DataService.deleteAllData();
        await DataStore.resetLocalState();
        await _visualSettingsController(context).reset();
        await WidgetSyncService.syncFromStoredConfiguration();
      },
      successMessage: 'The app was reset to its original settings.',
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
  }

  Future<void> _ensureFirstRunInitializationPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final prompted = prefs.getBool(_firstRunInitPromptedKey) ?? false;
    if (prompted || !mounted) return;

    await prefs.setBool(_firstRunInitPromptedKey, true);
    await _showInitializeDefaultsDialog(fromMenu: false);
  }

  Future<void> _showInitializeDefaultsDialog({required bool fromMenu}) async {
    if (!mounted) return;
    final shouldInitialize = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Initialize defaults?'),
        content: const Text(
          'Create default categories and accounts now?\n\nYou can still create or initialize them later from Main Menu > Data management.',
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
    if (shouldInitialize != true) return;

    final created = await DataService.initializeDefaultCategoriesAndAccounts();
    if (!mounted) return;
    setState(() => _refreshVersion++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created == 0
              ? 'Defaults are already available.'
              : 'Added $created default categories/accounts.',
        ),
      ),
    );
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

  void _openAppMenu(VisualSettings settings) {
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
          return ListTile(
            enabled: enabled,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            leading: Icon(icon, color: enabled ? null : Theme.of(context).disabledColor),
            title: Text(title, style: enabled ? null : TextStyle(color: Theme.of(context).disabledColor)),
            subtitle: subtitle == null
                ? null
                : Text(subtitle, style: enabled ? null : TextStyle(color: Theme.of(context).disabledColor)),
            onTap: enabled ? onTap : null,
          );
        }

        return Column(
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
                          'WhereIsMyMoney',
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
                  const _MenuSectionHeader('Account'),
                  menuTile(
                    icon: Icons.logout_outlined,
                    title: 'Logout',
                    onTap: () => handleSelection('logout'),
                  ),
                  const Divider(height: 1, thickness: 1),
                  // ---- Profiles section ----
                  const _MenuSectionHeader('Profiles', compact: true),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _profileService.getMyProfiles(),
                    builder: (ctx, snap) {
                      final profiles = snap.data ?? [];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: profiles.map((profile) {
                          final profileId = profile['id']?.toString() ?? '';
                          final profileName = profile['name']?.toString() ?? 'Profile';
                          final members = (profile['members'] as Map<String, dynamic>?) ?? {};
                          final currentPhone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
                          final role = (members[currentPhone] as String?) ?? 'viewer';
                          final isActive = profileId == _activeProfileId;
                          return ListTile(
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                            leading: Icon(
                              Icons.folder_outlined,
                              color: isActive
                                  ? const Color(0xFF4F46E5)
                                  : null,
                            ),
                            title: Text(
                              profileName,
                              style: isActive
                                  ? const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4F46E5),
                                    )
                                  : null,
                            ),
                            subtitle: Text(
                              role,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            trailing: isActive
                                ? const Icon(Icons.check, color: Color(0xFF4F46E5), size: 18)
                                : null,
                            onTap: isActive
                                ? null
                                : () async {
                                    Navigator.of(drawerContext).pop();
                                    await _profileService.switchProfile(profileId);
                                    if (!mounted) return;
                                    setState(() {
                                      _activeProfileId = profileId;
                                      _userRole = role;
                                      _refreshVersion++;
                                    });
                                  },
                          );
                        }).toList(),
                      );
                    },
                  ),
                  menuTile(
                    icon: Icons.add_circle_outline,
                    title: 'New profile',
                    onTap: () async {
                      Navigator.of(drawerContext).pop();
                      final nameController = TextEditingController();
                      final name = await showDialog<String>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('New Profile'),
                          content: TextField(
                            controller: nameController,
                            autofocus: true,
                            decoration: const InputDecoration(hintText: 'Profile name'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
                              child: const Text('Create'),
                            ),
                          ],
                        ),
                      );
                      nameController.dispose();
                      if (name == null || name.isEmpty || !mounted) return;
                      try {
                        final profileId = await _profileService.createProfile(name);
                        setState(() {
                          _activeProfileId = profileId;
                          _userRole = 'owner';
                          _refreshVersion++;
                        });
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                  ),
                  menuTile(
                    icon: Icons.qr_code_outlined,
                    title: 'Join with invite code',
                    onTap: () async {
                      Navigator.of(drawerContext).pop();
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
                            decoration: const InputDecoration(
                              hintText: 'Enter 6-character code',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, codeController.text.trim()),
                              child: const Text('Join'),
                            ),
                          ],
                        ),
                      );
                      codeController.dispose();
                      if (code == null || code.isEmpty || !mounted) return;
                      try {
                        final profileName =
                            await _profileService.joinProfileByCode(code);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Joined "$profileName" as viewer.')),
                        );
                        setState(() {});
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                  ),
                  menuTile(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Manage profile',
                    onTap: () async {
                      Navigator.of(drawerContext).pop();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                      await _loadRoleAndProfile();
                    },
                  ),
                  const Divider(height: 1, thickness: 1),
                  // ---- End Profiles section ----
                  const _MenuSectionHeader('Data management', compact: true),
                  menuTile(icon: Icons.upload_file_outlined, title: 'Export (Excel)', onTap: () => handleSelection('export')),
                  menuTile(icon: Icons.download_outlined, title: 'Import (Excel)', onTap: () => handleSelection('import')),
                  menuTile(icon: Icons.playlist_add_check_circle_outlined, title: 'Initialize defaults', onTap: () => handleSelection('initialize_defaults')),
                  menuTile(icon: Icons.delete_forever_outlined, title: 'Delete everything', onTap: () => handleSelection('delete_everything')),
                  menuTile(icon: Icons.receipt_long_outlined, title: 'Delete transactions', onTap: () => handleSelection('delete_transactions')),
                  menuTile(icon: Icons.restart_alt_outlined, title: 'Reset app', onTap: () => handleSelection('reset_app')),
                  const Divider(height: 1, thickness: 1),
                  const _MenuSectionHeader('Mode'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Budget vs Expense'),
                          selected: settings.comparisonMode == ComparisonMode.budgetVsExpense,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                          onSelected: (_) async {
                            await _setComparisonMode(ComparisonMode.budgetVsExpense);
                            if (!drawerContext.mounted) return;
                            Navigator.of(drawerContext).pop();
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Income vs Expense'),
                          selected: settings.comparisonMode == ComparisonMode.incomeVsExpense,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                          onSelected: (_) async {
                            await _setComparisonMode(ComparisonMode.incomeVsExpense);
                            if (!drawerContext.mounted) return;
                            Navigator.of(drawerContext).pop();
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1),
                  const _MenuSectionHeader('Visuals', compact: true),
                  ExpansionTile(
                    title: const Text('Appearance'),
                    leading: const Icon(Icons.palette_outlined),
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
                            menuTile(
                              icon: Icons.language_outlined,
                              title: 'Language',
                              subtitle: AppLocalizations.languageLabels[settings.localeCode] ?? 'English',
                              onTap: () => handleSelection('language'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  menuTile(
                    icon: Icons.sms_outlined,
                    title: 'Open SMSs',
                    subtitle: DataStore.isSmsTabVisible ? 'Already enabled' : 'Add SMS tab',
                    enabled: false,
                    onTap: () {},
                  ),
                  const Divider(height: 1, thickness: 1),
                  const _MenuSectionHeader('Application'),
                  menuTile(
                    icon: Icons.feedback_outlined,
                    title: 'Feedback',
                    subtitle: 'vivekgoyal.vg29@gmail.com',
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
                ],
              ),
            ),
          ],
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
        leading: IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () => _openAppMenu(controller.value), tooltip: 'Open menu'),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'WhereIsMyMoney',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (_userRole == 'viewer') ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'View only',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
      body: _buildCurrentPage(),
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
            selectedItemColor: const Color(0xFF4F46E5),
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

class _MenuSectionHeader extends StatelessWidget {
  final String title;
  final bool compact;

  const _MenuSectionHeader(this.title, {this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, compact ? 4 : 8, 14, compact ? 0 : 2),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
