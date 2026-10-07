class Account {
  final String phone;
  final Map<String, String> headers;
  final DateTime lastUsed;

  Account({
    required this.phone,
    required this.headers,
    required this.lastUsed,
  });

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'headers': headers,
        'last_used': lastUsed.toIso8601String(),
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        phone: json['phone'] ?? '',
        headers: Map<String, String>.from(json['headers'] ?? {}),
        lastUsed: DateTime.tryParse(json['last_used'] ?? '') ?? DateTime.now(),
      );
}

class Task {
  final String id;
  final int coins;
  final String title;
  bool rewarded;

  Task({
    required this.id,
    required this.coins,
    required this.title,
    this.rewarded = false,
  });
}

class Transaction {
  final int date;
  final String direction;
  final int amount;
  final String description;

  Transaction({
    required this.date,
    required this.direction,
    required this.amount,
    required this.description,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        date: json['date'] ?? 0,
        direction: json['direction'] ?? '',
        amount: json['amount'] ?? 0,
        description: json['description'] ?? '',
      );
}

class RedeemPackage {
  final int cost;
  final int units;
  final String code;

  RedeemPackage({required this.cost, required this.units, required this.code});
}
