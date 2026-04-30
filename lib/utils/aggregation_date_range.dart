import '../screens/analysis_page.dart' show AnalysisMode;

/// Inclusive date bounds for [DataService.getTransactions], matching Analysis / Budget.
(DateTime start, DateTime end) dateRangeInclusiveForAggregation(
  DateTime currentMonth,
  AnalysisMode mode,
) {
  switch (mode) {
    case AnalysisMode.selectedMonth:
      final start = DateTime(currentMonth.year, currentMonth.month, 1);
      final end = DateTime(currentMonth.year, currentMonth.month + 1, 0);
      return (start, end);
    case AnalysisMode.cumulativeToSelectedMonth:
      final start = DateTime(currentMonth.year, 1, 1);
      final end = DateTime(currentMonth.year, currentMonth.month + 1, 0);
      return (start, end);
    case AnalysisMode.cumulativeYear:
      final start = DateTime(currentMonth.year, 1, 1);
      final end = DateTime(currentMonth.year, 12, 31);
      return (start, end);
  }
}

String? aggregationSubtitleForMode(AnalysisMode mode) {
  switch (mode) {
    case AnalysisMode.selectedMonth:
      return null;
    case AnalysisMode.cumulativeToSelectedMonth:
      return 'Till month';
    case AnalysisMode.cumulativeYear:
      return 'Year';
  }
}
