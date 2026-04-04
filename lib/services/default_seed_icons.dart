class DefaultSeedIcons {
  static const Map<String, String> incomeCategory = {
    'Salary': 'assets/sample_icons/income_category/salary.svg',
    'Bonus': 'assets/sample_icons/income_category/bonus.svg',
    'Freelance': 'assets/sample_icons/income_category/freelance.svg',
    'Interest': 'assets/sample_icons/income_category/interest.svg',
    'Dividends': 'assets/sample_icons/income_category/dividends.svg',
    'Gifts': 'assets/sample_icons/income_category/gifts.svg',
    'Reimbursements': 'assets/sample_icons/income_category/reimbursements.svg',
    'Rental': 'assets/sample_icons/income_category/rental.svg',
    'Other': 'assets/sample_icons/income_category/other.svg',
  };

  static const Map<String, String> expenseCategory = {
    'Housing': 'assets/sample_icons/expense_category/housing.svg',
    'Utilities': 'assets/sample_icons/expense_category/utilities.svg',
    'Groceries': 'assets/sample_icons/expense_category/groceries.svg',
    'Dining': 'assets/sample_icons/expense_category/dining.svg',
    'Transport': 'assets/sample_icons/expense_category/transport.svg',
    'Health': 'assets/sample_icons/expense_category/health.svg',
    'Insurance': 'assets/sample_icons/expense_category/insurance.svg',
    'Education': 'assets/sample_icons/expense_category/education.svg',
    'Entertainment': 'assets/sample_icons/expense_category/entertainment.svg',
    'Shopping': 'assets/sample_icons/expense_category/shopping.svg',
    'Subscriptions': 'assets/sample_icons/expense_category/subscriptions.svg',
    'Debt': 'assets/sample_icons/expense_category/debt.svg',
    'Savings': 'assets/sample_icons/expense_category/savings.svg',
    'Donations': 'assets/sample_icons/expense_category/donations.svg',
    'Misc': 'assets/sample_icons/expense_category/misc.svg',
  };

  static const Map<String, String> account = {
    'Cash': 'assets/sample_icons/account/cash.svg',
    'Bank': 'assets/sample_icons/account/bank.svg',
    'Savings': 'assets/sample_icons/account/savings.svg',
    'Credit Card': 'assets/sample_icons/account/credit_card.svg',
    'Wallet': 'assets/sample_icons/account/wallet.svg',
  };

  static String? categoryIconPathFor(String name, String type) {
    if (type == 'income') return incomeCategory[name];
    return expenseCategory[name];
  }

  static String? accountIconPathFor(String name) => account[name];
}
