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
