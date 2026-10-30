import 'package:flutter/material.dart';

class RiderEarningRowData {
  final String date;
  final String reference;
  final String amount;
  final String status;

  const RiderEarningRowData({
    required this.date,
    required this.reference,
    required this.amount,
    required this.status,
  });

  factory RiderEarningRowData.fromApi(Map<String, dynamic> json) {
    return RiderEarningRowData(
      date: (json['date'] ?? '').toString(),
      reference: (json['reference'] ?? '').toString(),
      amount: (json['amount'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }

  String get normalizedStatus =>
      status.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

  double? get numericAmount => double.tryParse(
    amount.replaceAll(RegExp(r'PHP|₱|,|\s', caseSensitive: false), ''),
  );

  bool get isPaid =>
      const {'paid', 'released', 'completed'}.contains(normalizedStatus);
  bool get isVoided => const {
    'void',
    'cancelled',
    'rejected',
    'failed',
  }.contains(normalizedStatus);
}

class RiderEarningsSummary {
  final double total;
  final double paid;
  final double pending;
  final int unallocatedCount;

  const RiderEarningsSummary({
    this.total = 0,
    this.paid = 0,
    this.pending = 0,
    this.unallocatedCount = 0,
  });

  factory RiderEarningsSummary.fromApi(Map<String, dynamic> json) {
    double number(String key) => double.tryParse('${json[key] ?? 0}') ?? 0;
    return RiderEarningsSummary(
      total: number('total'),
      paid: number('paid'),
      pending: number('pending'),
      unallocatedCount: int.tryParse('${json['unallocated_count'] ?? 0}') ?? 0,
    );
  }

  factory RiderEarningsSummary.fromRows(List<RiderEarningRowData> rows) {
    double total = 0;
    double paid = 0;
    int unallocated = 0;
    for (final row in rows) {
      if (row.isVoided) continue;
      final amount = row.numericAmount;
      if (amount == null) {
        unallocated++;
      } else {
        total += amount;
        if (row.isPaid) paid += amount;
      }
    }
    return RiderEarningsSummary(
      total: total,
      paid: paid,
      pending: total - paid,
      unallocatedCount: unallocated,
    );
  }
}

String _pesos(double amount) {
  final parts = amount.toStringAsFixed(2).split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return '₱$whole.${parts.last}';
}

typedef RiderEarningsRefreshCallback = Future<void> Function();

class RiderEarningsScreen extends StatelessWidget {
  final List<RiderEarningRowData> earningsRows;
  final RiderEarningsSummary? summary;
  final String riderName;
  final String earningsNotice;
  final RiderEarningsRefreshCallback? onRefresh;
  final VoidCallback? onOpenRemittances;

  const RiderEarningsScreen({
    super.key,
    this.earningsRows = const [],
    this.summary,
    this.riderName = '',
    this.earningsNotice = '',
    this.onRefresh,
    this.onOpenRemittances,
  });

  static const _background = Color(0xFFFBF7F2);
  static const _surface = Color(0xFFFFFDF9);
  static const _border = Color(0xFFEADCCC);
  static const _maroon = Color(0xFF561C17);
  static const _text = Color(0xFF3B211B);
  static const _muted = Color(0xFF987865);

  @override
  Widget build(BuildContext context) {
    final totals = summary ?? RiderEarningsSummary.fromRows(earningsRows);
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'My Earnings',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: _maroon,
          onRefresh: () async {
            await onRefresh?.call();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
            children: [
              if (onOpenRemittances != null) ...[
                OutlinedButton.icon(
                  onPressed: onOpenRemittances,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Cash remittances'),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_maroon, Color(0xFF793D2F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Color(0xFFEBD5BF),
                          size: 21,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            riderName.trim().isEmpty
                                ? 'YOUR EARNINGS'
                                : riderName,
                            style: const TextStyle(
                              color: Color(0xFFEBD5BF),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Total earned',
                      style: TextStyle(color: Color(0xFFEBD5BF), fontSize: 13),
                    ),
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _pesos(totals.total),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your recorded pickup & delivery income',
                      style: TextStyle(
                        color: Color(0xFFEBD5BF),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wideText =
                      MediaQuery.textScalerOf(context).scale(14) > 22;
                  final width = wideText
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: width,
                        child: _summaryCard(
                          'Paid out',
                          totals.paid,
                          Icons.check_circle_outline_rounded,
                          const Color(0xFF28724D),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _summaryCard(
                          'Awaiting payout',
                          totals.pending,
                          Icons.schedule_rounded,
                          const Color(0xFF946514),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (totals.unallocatedCount > 0) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3DC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.hourglass_top_rounded,
                        color: Color(0xFF946514),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${totals.unallocatedCount} earning record(s) awaiting allocation. These amounts are not included in your total yet.',
                          style: const TextStyle(
                            color: Color(0xFF80581E),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 26),
              const Text(
                'Earnings activity',
                style: TextStyle(
                  color: _text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Pickup and delivery records for your account.',
                style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 14),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                ),
                child: earningsRows.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 34,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              color: _muted,
                              size: 36,
                            ),
                            SizedBox(height: 14),
                            Text(
                              'No earnings recorded yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _text,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 7),
                            Text(
                              'Your earnings will appear here when they are recorded for your rider account.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _muted,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          for (int i = 0; i < earningsRows.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: _border),
                            _record(earningsRows[i]),
                          ],
                        ],
                      ),
              ),
              if (earningsNotice.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  earningsNotice,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(String label, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 14),
          Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _pesos(amount),
              style: const TextStyle(
                color: _text,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _record(RiderEarningRowData row) {
    final amount = row.numericAmount;
    final color = row.isVoided
        ? const Color(0xFFB42318)
        : row.isPaid
        ? const Color(0xFF28724D)
        : const Color(0xFF946514);
    final status = amount == null && !row.isVoided
        ? 'Awaiting allocation'
        : row.status.trim().isEmpty
        ? 'Pending'
        : row.status;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6EFE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: _maroon,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.reference.isEmpty ? 'Earnings record' : row.reference,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      row.date,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 10,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (amount != null)
                Text(
                  _pesos(amount),
                  style: const TextStyle(
                    color: _maroon,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
