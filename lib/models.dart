/// Represents a Firestore profile document.
class ProfileModel {
  final String id;
  final String name;
  final bool isDefault;
  final bool isShareable;

  /// Always generated at profile creation. Persists even when sharable is off.
  final String shareCode;

  /// True only when the profile is currently sharable and the code is active.
  final bool shareCodeActive;

  final String createdBy;

  /// Map of phone → role ('owner' | 'member').
  final Map<String, String> members;

  const ProfileModel({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.isShareable,
    required this.shareCode,
    required this.shareCodeActive,
    required this.createdBy,
    required this.members,
  });

  factory ProfileModel.fromMap(String id, Map<String, dynamic> data) {
    final rawMembers = (data['members'] as Map<String, dynamic>?) ?? {};
    final members = rawMembers.map((k, v) => MapEntry(k, v.toString()));
    return ProfileModel(
      id: id,
      name: data['name']?.toString() ?? 'Profile',
      isDefault: data['isDefault'] as bool? ?? false,
      isShareable: data['isShareable'] as bool? ?? false,
      // Fall back to legacy 'inviteCode' field for backward compat
      shareCode: data['shareCode']?.toString() ??
          data['inviteCode']?.toString() ??
          '',
      shareCodeActive: data['shareCodeActive'] as bool? ?? false,
      createdBy: data['createdBy']?.toString() ?? '',
      members: members,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'isDefault': isDefault,
        'isShareable': isShareable,
        'shareCode': shareCode,
        'shareCodeActive': shareCodeActive,
        'createdBy': createdBy,
        'members': members,
      };

  ProfileModel copyWith({
    String? name,
    bool? isDefault,
    bool? isShareable,
    String? shareCode,
    bool? shareCodeActive,
    String? createdBy,
    Map<String, String>? members,
  }) =>
      ProfileModel(
        id: id,
        name: name ?? this.name,
        isDefault: isDefault ?? this.isDefault,
        isShareable: isShareable ?? this.isShareable,
        shareCode: shareCode ?? this.shareCode,
        shareCodeActive: shareCodeActive ?? this.shareCodeActive,
        createdBy: createdBy ?? this.createdBy,
        members: members ?? this.members,
      );
}

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
