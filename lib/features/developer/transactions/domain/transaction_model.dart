class TransactionItem {
  final int id;
  final String orderId;
  final String orderNumber;
  final String payerName;
  final String serviceName;
  final String journalName;
  final num amount;
  final num devNetShare;
  final String status;
  final DateTime? createdAt;
  final DateTime? paidAt;

  final int manuscriptCount;
  final bool isBulk;
  final String type;

  const TransactionItem({
    required this.id,
    this.orderId = '',
    this.orderNumber = '',
    required this.payerName,
    this.serviceName = 'Publikasi Naskah',
    this.journalName = 'LOA Journal',
    required this.amount,
    required this.devNetShare,
    required this.status,
    this.createdAt,
    this.paidAt,
    this.manuscriptCount = 1,
    this.isBulk = false,
    this.type = '',
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    num parseNum(dynamic val) {
      if (val is num) return val;
      if (val is String) return num.tryParse(val) ?? 0;
      return 0;
    }

    final idVal = json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0;

    final orderIdVal = json['order_id']?.toString() ?? 'ORD-#$idVal';

    final orderNumVal = json['invoice_number']?.toString() ??
        json['order_number']?.toString() ??
        json['invoice_no']?.toString() ??
        'TRX-#$idVal';

    final type = json['type']?.toString().toLowerCase() ?? '';
    final orderIdUpper = orderIdVal.toUpperCase();
    final invoiceUpper = orderNumVal.toUpperCase();

    final isBulkVal = type == 'bulk_submission' ||
        orderIdUpper.contains('BULK') ||
        invoiceUpper.contains('BULK');

    int resolveManuscriptCount() {
      // 1. Array submission_ids from backend
      if (json['submission_ids'] is List) {
        final list = json['submission_ids'] as List;
        if (list.isNotEmpty) return list.length;
      }

      // 2. Count of items if multiple
      if (json['items'] is List) {
        final items = json['items'] as List;
        if (items.length > 1) return items.length;
      }

      // 3. Regex from order_id (e.g. BYR-BULK-2SUB-8230-...)
      final match = RegExp(r'BULK-(\d+)SUB', caseSensitive: false).firstMatch(orderIdVal);
      if (match != null && match.group(1) != null) {
        final count = int.tryParse(match.group(1)!);
        if (count != null && count > 0) return count;
      }

      // 4. Fallback from developer net share (Rp 5.000 per naskah)
      if (isBulkVal) {
        final devShare = parseNum(json['developer_net_share'] ?? json['dev_share']);
        if (devShare > 0 && devShare % 5000 == 0) {
          final count = devShare ~/ 5000;
          if (count > 0) return count;
        }
      }

      return 1;
    }

    final manuscriptCountVal = resolveManuscriptCount();

    // Resolve Jenis Layanan (Service Name)
    String resolveServiceName() {
      // 1. Bulk / Kolektif has priority
      if (isBulkVal) {
        return manuscriptCountVal > 1
            ? 'Publikasi Kolektif ($manuscriptCountVal Naskah)'
            : 'Publikasi Kolektif';
      }

      // 2. Explicit service name in payload
      if (json['service_name'] != null && json['service_name'].toString().trim().isNotEmpty) {
        return json['service_name'].toString().trim();
      }
      if (json['item_name'] != null && json['item_name'].toString().trim().isNotEmpty) {
        return json['item_name'].toString().trim();
      }

      // 3. Check items array from payment_items relation
      if (json['items'] is List && (json['items'] as List).isNotEmpty) {
        final firstItem = (json['items'] as List).first;
        if (firstItem is Map) {
          final itemName = firstItem['item_name']?.toString().trim() ?? '';
          final itemType = firstItem['item_type']?.toString().toLowerCase().trim() ?? '';

          // A. Explicit DOI Add-on check
          if (itemType == 'doi_addon' || itemType == 'doi' || type == 'doi_addon' || type == 'doi') {
            return 'Tambah DOI';
          }

          // B. Explicit Replace PDF check
          if (itemType == 'replace_pdf' || itemType == 'ganti_pdf' || type == 'replace_pdf' || type == 'ganti_pdf') {
            return 'Ganti PDF';
          }

          if (itemName.isNotEmpty) {
            final lower = itemName.toLowerCase();
            if (lower == 'tambah doi' || lower == 'add-on doi' || lower == 'doi addon') {
              return 'Tambah DOI';
            }
            if (lower == 'ganti pdf' || lower == 'ubah pdf' || lower == 'replace pdf') {
              return 'Ganti PDF';
            }
            if (lower.contains('fast track')) return 'Fast Track';
            if (lower.contains('sertifikat')) return 'Sertifikat';

            // Return full item/package name (e.g. "ISSN + DOI (11-15 Author) - Triwikrama...")
            return itemName;
          }

          if (itemType.isNotEmpty) {
            switch (itemType) {
              case 'publication':
              case 'submission':
                return 'Publikasi Naskah';
              default:
                return itemType;
            }
          }
        }
      }

      // 4. Fallback based on payment 'type' field
      switch (type) {
        case 'doi_addon':
        case 'doi':
          return 'Tambah DOI';
        case 'replace_pdf':
        case 'ganti_pdf':
          return 'Ganti PDF';
        case 'fast_track':
          return 'Fast Track';
        case 'bulk_submission':
          return manuscriptCountVal > 1
              ? 'Publikasi Kolektif ($manuscriptCountVal Naskah)'
              : 'Publikasi Kolektif';
        case 'submission':
        case 'publication':
          return 'Publikasi Naskah';
      }

      // 5. Fallback based on raw journal_name if it contains clues
      final journal = json['journal_name']?.toString() ?? '';
      if (journal.isNotEmpty && journal.toLowerCase() != 'loa journal') {
        return journal;
      }

      return 'Publikasi Naskah';
    }

    final dateVal = json['paid_at'] != null
        ? DateTime.tryParse(json['paid_at'].toString())
        : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null);

    num resolveAmount() {
      final direct = parseNum(
        json['gross_amount'] ??
            json['amount'] ??
            json['total_amount'] ??
            json['original_amount'],
      );
      if (direct > 0) return direct;

      // Fallback: calculate sum from items if present
      if (json['items'] is List && (json['items'] as List).isNotEmpty) {
        num itemsSum = 0;
        for (final it in json['items']) {
          if (it is Map) {
            itemsSum += parseNum(it['gross_amount'] ?? it['amount'] ?? it['price']);
          }
        }
        if (itemsSum > 0) return itemsSum;
      }

      return direct;
    }

    return TransactionItem(
      id: idVal,
      orderId: orderIdVal,
      orderNumber: orderNumVal,
      payerName: json['payer_name']?.toString() ?? json['customer_name']?.toString() ?? 'Pembayar LOA',
      serviceName: resolveServiceName(),
      journalName: json['journal_name']?.toString() ?? json['journal']?.toString() ?? 'LOA Journal',
      amount: resolveAmount(),
      devNetShare: parseNum(json['developer_net_share'] ?? json['dev_share'] ?? json['developer_gross_share']),
      status: json['payment_status']?.toString() ?? json['status']?.toString() ?? 'paid',
      createdAt: dateVal,
      paidAt: dateVal,
      manuscriptCount: manuscriptCountVal,
      isBulk: isBulkVal,
      type: type,
    );
  }
}

class PaginatedTransactionsResponse {
  final List<TransactionItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int totalDevShare;
  final bool hasMore;

  const PaginatedTransactionsResponse({
    required this.items,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.totalDevShare = 0,
    this.hasMore = false,
  });

  factory PaginatedTransactionsResponse.fromJson(Map<String, dynamic> json) {
    List<TransactionItem> itemsList = [];
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
            .map((e) => TransactionItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } else if (dataObj is List) {
      itemsList = dataObj
          .map((e) => TransactionItem.fromJson(e as Map<String, dynamic>))
          .toList();
      totalCount = itemsList.length;
    }

    final summary = json['summary'] is Map<String, dynamic>
        ? json['summary'] as Map<String, dynamic>
        : <String, dynamic>{};

    final devShareSum = summary['total_dev_share'] is num
        ? (summary['total_dev_share'] as num).toInt()
        : int.tryParse(summary['total_dev_share']?.toString() ?? '0') ??
            itemsList.fold<int>(0, (sum, it) => sum + it.devNetShare.toInt());

    final totalSummary = summary['total_transactions'] is num
        ? (summary['total_transactions'] as num).toInt()
        : totalCount;

    return PaginatedTransactionsResponse(
      items: itemsList,
      currentPage: current,
      lastPage: last,
      total: totalSummary > 0 ? totalSummary : itemsList.length,
      totalDevShare: devShareSum,
      hasMore: current < last,
    );
  }
}
