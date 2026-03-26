class TransactionModel {

  int? id;

  String type;
  String account;
  String category;
  String comment;

  double amount;

  String date;

  TransactionModel({
    this.id,
    required this.type,
    required this.account,
    required this.category,
    required this.comment,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toMap() {

    return {
      "id": id,
      "type": type,
      "account": account,
      "category": category,
      "comment": comment,
      "amount": amount,
      "date": date
    };
  }
}

class Account {

  int? id;
  String name;

  Account({
    this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {

    return {
      "id": id,
      "name": name,
    };
  }
}

class Category {

  int? id;
  String name;

  String type; // income or expense

  Category({
    this.id,
    required this.name,
    required this.type,
  });

  Map<String, dynamic> toMap() {

    return {
      "id": id,
      "name": name,
      "type": type,
    };
  }
}

class Budget {

  int? id;

  String category;

  double amount;

  int month;

  int year;

  Budget({
    this.id,
    required this.category,
    required this.amount,
    required this.month,
    required this.year,
  });

  Map<String, dynamic> toMap() {

    return {
      "id": id,
      "category": category,
      "amount": amount,
      "month": month,
      "year": year,
    };
  }
}
