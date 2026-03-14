import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/data_store.dart';
import '../services/excel_transfer_service.dart';
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
      final path = await ExcelTransferService.exportAllData();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export completed: $path')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'FinTrack',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Menu',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.file_download),
                title: const Text('Export data (Excel)'),
                onTap: () async {
                  Navigator.pop(context);
                  await _exportData();
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_upload),
                title: const Text('Import data (Excel)'),
                onTap: () async {
                  Navigator.pop(context);
                  await _importData();
                },
              ),
            ],
          ),
        ),
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
