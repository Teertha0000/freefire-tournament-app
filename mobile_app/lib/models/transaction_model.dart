class TransactionModel {
  final String id;
  final double amount;
  final String type;
  final String? description;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    this.description,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
