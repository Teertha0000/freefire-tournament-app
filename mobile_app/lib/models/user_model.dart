class UserModel {
  final String id;
  final String phone;
  final String ign;
  final String uid;
  final double bonusBalance;
  final double withdrawableBalance;
  final String status;
  final String role;
  final String referralCode;

  const UserModel({
    required this.id,
    required this.phone,
    required this.ign,
    required this.uid,
    required this.bonusBalance,
    required this.withdrawableBalance,
    required this.status,
    required this.role,
    required this.referralCode,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      ign: json['ign'] as String? ?? '',
      uid: json['uid'] as String? ?? '',
      bonusBalance: (json['bonus_balance'] as num?)?.toDouble() ?? 0.0,
      withdrawableBalance: (json['withdrawable_balance'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'active',
      role: json['role'] as String? ?? 'user', // Default to user if null
      referralCode: json['referral_code'] as String? ?? '',
    );
  }

  double get totalBalance => bonusBalance + withdrawableBalance;
}

