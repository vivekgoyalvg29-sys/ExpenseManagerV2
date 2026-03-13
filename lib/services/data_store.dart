class DataStore {

  static List<Map<String, dynamic>> categories = [];

  static List<Map<String, dynamic>> accounts = [];

  static List<Map<String, dynamic>> transactions = [];

  static List<Map<String, dynamic>> budgets = [];

  static List<Map<String, dynamic>> smsTransactions = [];

  static int smsTransactionsVersion = 0;

  static void replaceSmsTransactions(List<Map<String, dynamic>> transactions) {
    smsTransactions = List<Map<String, dynamic>>.from(transactions);
    smsTransactionsVersion++;
  }

}
