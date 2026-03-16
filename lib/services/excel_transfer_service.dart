import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

class ExcelTransferService {

  static Future<File> exportExpensesToExcel(List<Map<String, dynamic>> expenses) async {

    final excel = Excel.createExcel();
    final Sheet sheet = excel['Expenses'];

    // Header Row
    sheet.appendRow([
      'Date',
      'Category',
      'Amount',
      'Note'
    ]);

    // Data Rows
    for (var expense in expenses) {
      sheet.appendRow([
        expense['date'] ?? '',
        expense
