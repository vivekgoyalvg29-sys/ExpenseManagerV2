import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/data_store.dart';
import '../services/excel_transfer_service.dart';
import '../services/visual_settings.dart';
import '../widgets/section_tile.dart';
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
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int currentIndex;
  int _refreshVersion = 0;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  Widget _buildCurrentPage() {
    final pageKey = ValueKey('$currentIndex-$_refreshVersion');

    switch (currentIndex) {
      case 0:
        return RecordsPage(key: pageKey);
      case 1:
        return AnalysisPage(key: pageKey);
      case 2:
        return BudgetsPage(key: pageKey);
      case 3:
        return AccountsPage(key: pageKey);
      case 4:
        return CategoriesPage(key: pageKey);
      case 5:
        return SmsPage(key: ValueKey('sms-${DataStore.smsTransactionsVersion}-$_refreshVersion'));
      default:
        return RecordsPage(key: pageKey);
    }
  }

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export cancelled.')),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export completed: $selectedPath')),
        );
        return;
      }

      final fallbackPath = await ExcelTransferService.exportAllData();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export completed: $fallbackPath')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _importData() async {
    try {
      final selected = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (selected == null || selected.files.isEmpty) {
        return;
      }

      final picked = selected.files.first;
      final bytes = picked.bytes ??
          (picked.path == null ? null : await File(picked.path!).readAsBytes());

      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read selected file.')),
        );
        return;
      }

      final result = await ExcelTransferService.importAllDataFromBytes(bytes);

      if (!mounted) return;
      setState(() {
        _refreshVersion++;
      });

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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  Future<void> _openVisualSettings() async {
    final controller = _visualSettingsController(context);
    final settings = controller.value;
    String fontKey = settings.fontKey;
    double textScale = settings.textScale;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
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
                      items: VisualSettings.fontOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.key,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          fontKey = value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Text size: ${(textScale * 100).round()}%',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Slider(
                      value: textScale,
                      min: 0.85,
                      max: 1.35,
                      divisions: 10,
                      label: '${(textScale * 100).round()}%',
                      onChanged: (value) {
                        setDialogState(() {
                          textScale = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Preview text',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontFamily: VisualSettings.fontOptions
                                .firstWhere((option) => option.key == fontKey)
                                .fontFamily,
                            fontSize: 16 * textScale,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Apply a font family and overall text scaling across the app.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: VisualSettings.fontOptions
                                .firstWhere((option) => option.key == fontKey)
                                .fontFamily,
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
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Reset'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    await controller.updateSettings(
                      settings.copyWith(fontKey: fontKey, textScale: textScale),
                    );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  VisualSettingsController _visualSettingsController(BuildContext context) {
    return VisualSettingsScope.of(context);
  }

  Future<void> _handleAppBarAction(String action) async {
    if (action == 'export') {
      await _exportData();
      return;
    }

    if (action == 'import') {
      await _importData();
      return;
    }

    if (action == 'customize_visuals') {
      await _openVisualSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _visualSettingsController(context);

    return Scaffold(
        backgroundColor: const Color(0xFFF3F5F9),
        appBar: AppBar(
          leading: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: Colors.white,
            onSelected: _handleAppBarAction,
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'export',
                child: Text('Export data (Excel)'),
              ),
              const PopupMenuItem<String>(
                value: 'import',
                child: Text('Import data (Excel)'),
              ),
              PopupMenuItem<String>(
                enabled: false,
                padding: EdgeInsets.zero,
                child: _CustomizeVisualsMenuItem(
                  currentSettings: controller.value,
                  onSelected: () => _handleAppBarAction('customize_visuals'),
                ),
              ),
            ],
          ),
          title: const Text('FinTrack', textAlign: TextAlign.center),
          actions: const [
            SizedBox(width: kToolbarHeight),
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
              selectedItemColor: Colors.green,
              unselectedItemColor: Colors.black54,
              onTap: (index) {
                setState(() {
                  currentIndex = index;
                });
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Records'),
                BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: 'Analysis'),
                BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: 'Budgets'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_balance_wallet),
                  label: 'Accounts',
                ),
                BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Categories'),
                BottomNavigationBarItem(icon: Icon(Icons.sms), label: 'SMSs'),
              ],
            ),
          ),
        ),
    );
  }
}

class _CustomizeVisualsMenuItem extends StatelessWidget {
  final VisualSettings currentSettings;
  final VoidCallback onSelected;

  const _CustomizeVisualsMenuItem({
    required this.currentSettings,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Customize visuals',
      padding: EdgeInsets.zero,
      offset: const Offset(160, 0),
      onSelected: (_) => onSelected(),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'open',
          child: SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Open visual settings'),
                const SizedBox(height: 4),
                Text(
                  '${currentSettings.fontLabel} • ${(currentSettings.textScale * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: const [
            Expanded(child: Text('Customize visuals')),
            Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}
