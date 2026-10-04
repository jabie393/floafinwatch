class PayoutItem {
  final int id;
  final String payoutNo;
  final num amount;
  final String status;
  final String? notes;
  final String? referenceNo;
  final String? rejectionReason;
  final String? proofFile;
  final String? bankName;
  final String? accountNo;
  final DateTime? createdAt;

  const PayoutItem({
    required this.id,
    required this.payoutNo,
    required this.amount,
    required this.status,
    this.notes,
    this.referenceNo,
    this.rejectionReason,
    this.proofFile,
    this.bankName,
    this.accountNo,
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
      referenceNo: json['reference_no']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      proofFile: json['proof_file']?.toString(),
      bankName: json['bank_name']?.toString(),
      accountNo: json['account_no']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  PayoutItem copyWith({
    int? id,
    String? payoutNo,
    num? amount,
    String? status,
    String? notes,
    String? referenceNo,
    String? rejectionReason,
    String? proofFile,
    String? bankName,
    String? accountNo,
    DateTime? createdAt,
  }) {
    return PayoutItem(
      id: id ?? this.id,
      payoutNo: payoutNo ?? this.payoutNo,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      referenceNo: referenceNo ?? this.referenceNo,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      proofFile: proofFile ?? this.proofFile,
      bankName: bankName ?? this.bankName,
      accountNo: accountNo ?? this.accountNo,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class PaginatedPayoutsResponse {
  final List<PayoutItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final num totalCompletedAmount;
  final num totalPendingAmount;
  final int completedCount;
  final bool hasMore;

  const PaginatedPayoutsResponse({
    required this.items,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.totalCompletedAmount = 0,
    this.totalPendingAmount = 0,
    this.completedCount = 0,
    this.hasMore = false,
  });

  factory PaginatedPayoutsResponse.fromJson(Map<String, dynamic> json) {
    List<PayoutItem> itemsList = [];
    int current = 1;
    int last = 1;
    int totalCount = 0;

    final dataObj = json['data'];
    if (dataObj is Map<String, dynamic>) {
      current = dataObj['current_page'] is int
          ? dataObj['current_page'] as int
          : int.tryParse(dataObj['current_page']?.toString() ?? '1') ?? 1;
      last = dataObj['last_page'] is int
          ? dataObj['last_page'] as int
          : int.tryParse(dataObj['last_page']?.toString() ?? '1') ?? 1;
      totalCount = dataObj['total'] is int
          ? dataObj['total'] as int
          : int.tryParse(dataObj['total']?.toString() ?? '0') ?? 0;

      final rawList = dataObj['data'];
      if (rawList is List) {
        itemsList = rawList
            .map((e) => PayoutItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } else if (dataObj is List) {
      itemsList = dataObj
          .map((e) => PayoutItem.fromJson(e as Map<String, dynamic>))
          .toList();
      totalCount = itemsList.length;
    }

    final summary = json['summary'] is Map<String, dynamic>
        ? json['summary'] as Map<String, dynamic>
        : <String, dynamic>{};

    num parseNum(dynamic val) {
      if (val is num) return val;
      if (val is String) return num.tryParse(val) ?? 0;
      return 0;
    }

    final totalCompleted = summary['total_completed_amount'] != null
        ? parseNum(summary['total_completed_amount'])
        : itemsList
            .where((p) => p.status == 'confirmed' || p.status == 'completed')
            .fold<num>(0, (sum, p) => sum + p.amount);

    final totalPending = summary['total_pending_amount'] != null
        ? parseNum(summary['total_pending_amount'])
        : itemsList
            .where((p) => p.status != 'confirmed' && p.status != 'completed')
            .fold<num>(0, (sum, p) => sum + p.amount);

    final completedCount = summary['completed_count'] is int
        ? summary['completed_count'] as int
        : (int.tryParse(summary['completed_count']?.toString() ?? '') ??
            itemsList
                .where((p) => p.status == 'confirmed' || p.status == 'completed')
                .length);

    final totalSummary = summary['total_payouts'] is int
        ? summary['total_payouts'] as int
        : (int.tryParse(summary['total_payouts']?.toString() ?? '') ?? totalCount);

    return PaginatedPayoutsResponse(
      items: itemsList,
      currentPage: current,
      lastPage: last,
      total: totalSummary > 0 ? totalSummary : itemsList.length,
      totalCompletedAmount: totalCompleted,
      totalPendingAmount: totalPending,
      completedCount: completedCount,
      hasMore: current < last,
    );
  }
}
