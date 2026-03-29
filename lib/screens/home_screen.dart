import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/data_store.dart';
import '../services/app_localizations.dart';
import '../services/database_service.dart';
import '../services/excel_transfer_service.dart';
import '../services/visual_settings.dart';
import '../services/widget_sync_service.dart';
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
  late int currentIndex;
  int _refreshVersion = 0;
  String _appVersion = 'v1.0.0';
  String _username = '';

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _loadPackageInfo();
    _loadUsername();
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

  Future<void> _openEditProfileDialog() async {
    final controller = TextEditingController(text: _username);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, _) => AlertDialog(
          title: const Text('Edit profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Username'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  await _logout();
                },
                icon: const Icon(Icons.logout_outlined),
                label: const Text('Logout'),
              ),
            ],
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
      ),
    );
  }

  List<_NavItem> get _navItems {
    final items = <_NavItem>[
      _NavItem(label: context.tr('Records'), icon: Icons.list, builder: _recordsBuilder),
      _NavItem(label: context.tr('Analysis'), icon: Icons.pie_chart, builder: _analysisBuilder),
      _NavItem(label: context.tr('Budget'), icon: Icons.account_balance, builder: _budgetsBuilder),
      _NavItem(label: context.tr('Accounts'), icon: Icons.account_balance_wallet, builder: _accountsBuilder),
      _NavItem(label: context.tr('Categories'), icon: Icons.category, builder: _categoriesBuilder),
    ];
    if (DataStore.isSmsTabVisible) {
      items.add(_NavItem(label: context.tr('SMSs'), icon: Icons.sms, builder: _smsBuilder));
    }
    return items;
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
    ThemeMode mode = controller.value.themeMode;
    final applied = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeMode.values
                .map(
                  (value) => RadioListTile<ThemeMode>(
                    value: value,
                    groupValue: mode,
                    title: Text(value.name[0].toUpperCase() + value.name.substring(1)),
                    onChanged: (changed) {
                      if (changed == null) return;
                      setState(() => mode = changed);
                    },
                  ),
                )
                .toList(),
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
        builder: (context, setState) => AlertDialog(
          title: const Text('Language'),
          content: SizedBox(
            width: 320,
            child: ListView(
              shrinkWrap: true,
              children: AppLocalizations.languageLabels.entries
                  .map((entry) => RadioListTile<String>(
                        value: entry.key,
                        groupValue: selected,
                        title: Text(entry.value),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => selected = value);
                        },
                      ))
                  .toList(),
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
      await controller.updateSettings(controller.value.copyWith(localeCode: selected));
    }
  }

  Future<void> _openComparisonModeSettings() async {
    final controller = _visualSettingsController(context);
    ComparisonMode mode = controller.value.comparisonMode;
    final applied = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Comparison mode'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ComparisonMode>(
                value: ComparisonMode.budgetVsExpense,
                groupValue: mode,
                title: const Text('Budget vs Expense'),
                onChanged: (changed) {
                  if (changed == null) return;
                  setState(() => mode = changed);
                },
              ),
              RadioListTile<ComparisonMode>(
                value: ComparisonMode.incomeVsExpense,
                groupValue: mode,
                title: const Text('Income vs Expense'),
                onChanged: (changed) {
                  if (changed == null) return;
                  setState(() => mode = changed);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
          ],
        ),
      ),
    );
    if (applied == true) {
      await controller.updateSettings(controller.value.copyWith(comparisonMode: mode));
      if (!mounted) return;
      setState(() => _refreshVersion++);
    }
  }

  Future<void> _openSearchPopup() async {
    final tx = await DatabaseService.getTransactions();
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
        await DatabaseService.deleteAllData();
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
        await DatabaseService.deleteAllTransactions();
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
        await DatabaseService.deleteAllData();
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
      case 'comparison_mode':
        await _openComparisonModeSettings();
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
      case 'edit_profile':
        await _openEditProfileDialog();
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

        Widget tile({
          required IconData icon,
          required String title,
          String? subtitle,
          required VoidCallback onTap,
        }) {
          return ListTile(
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            leading: Icon(icon),
            title: Text(title),
            subtitle: subtitle == null ? null : Text(subtitle),
            onTap: onTap,
          );
        }

        final user = FirebaseAuth.instance.currentUser;
        final phoneNumber = user?.phoneNumber ?? '';
        final displayName = _username.isNotEmpty
            ? '$_username ($phoneNumber)'
            : phoneNumber;

        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
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
                          Text(
                            displayName,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
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
            const _MenuSectionHeader('Account'),
            tile(
              icon: Icons.person_outline,
              title: 'Edit profile',
              subtitle: _username.isEmpty ? null : _username,
              onTap: () => handleSelection('edit_profile'),
            ),
            const Divider(height: 1, thickness: 1),
            const _MenuSectionHeader('Data management'),
            tile(icon: Icons.upload_file_outlined, title: 'Export (Excel)', onTap: () => handleSelection('export')),
            tile(icon: Icons.download_outlined, title: 'Import (Excel)', onTap: () => handleSelection('import')),
            tile(icon: Icons.delete_forever_outlined, title: 'Delete everything', onTap: () => handleSelection('delete_everything')),
            tile(icon: Icons.receipt_long_outlined, title: 'Delete transactions', onTap: () => handleSelection('delete_transactions')),
            tile(icon: Icons.restart_alt_outlined, title: 'Reset app', onTap: () => handleSelection('reset_app')),
            const Divider(height: 1, thickness: 1),
            const _MenuSectionHeader('Visuals & SMSs'),
            ExpansionTile(
              title: const Text('Appearance'),
              leading: const Icon(Icons.palette_outlined),
              children: [
                tile(icon: Icons.dark_mode_outlined, title: 'Theme', subtitle: settings.themeMode.name, onTap: () => handleSelection('theme')),
                tile(icon: Icons.font_download_outlined, title: 'Font', subtitle: '${settings.fontLabel} • ${(settings.textScale * 100).round()}%', onTap: () => handleSelection('customize_visuals')),
                tile(icon: Icons.language_outlined, title: 'Language', subtitle: AppLocalizations.languageLabels[settings.localeCode] ?? 'English', onTap: () => handleSelection('language')),
                tile(
                  icon: Icons.compare_arrows_outlined,
                  title: 'Comparison mode',
                  subtitle: settings.comparisonMode == ComparisonMode.budgetVsExpense
                      ? 'Budget vs Expense'
                      : 'Income vs Expense',
                  onTap: () => handleSelection('comparison_mode'),
                ),
              ],
            ),
            tile(icon: Icons.sms_outlined, title: 'Open SMSs', subtitle: DataStore.isSmsTabVisible ? 'Already enabled' : 'Add SMS tab', onTap: () => handleSelection('open_sms')),
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
        title: Text(
          'WhereIsMyMoney',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
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

  const _MenuSectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
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
