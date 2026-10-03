class PayoutItem {
  final int id;
  final String payoutNo;
  final num amount;
  final String status;
  final String? notes;
  final DateTime? createdAt;

  const PayoutItem({
    required this.id,
    required this.payoutNo,
    required this.amount,
    required this.status,
    this.notes,
    this.createdAt,
  });

  factory PayoutItem.fromJson(Map<String, dynamic> json) {
    num parseNum(dynamic val) {
      if (val is num) return val;
      if (val is String) return num.tryParse(val) ?? 0;
      return 0;
    }

    return PayoutItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      payoutNo: json['payout_no']?.toString() ?? 'PO-${json['id'] ?? '0'}',
      amount: parseNum(json['amount']),
      status: json['status']?.toString() ?? 'waiting_payout',
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}
