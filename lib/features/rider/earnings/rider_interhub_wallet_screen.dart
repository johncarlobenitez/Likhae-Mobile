import 'package:flutter/material.dart';

import '../../../services/workspace_mobile_service.dart';
import '../../../shared/formatting/money_formatting.dart';
import '../../../shared/widgets/workflow_ui.dart' show openWorkflowProof;

class RiderInterhubWalletScreen extends StatefulWidget {
  const RiderInterhubWalletScreen({
    super.key,
    required this.onBackToDashboard,
  });

  final VoidCallback onBackToDashboard;

  @override
  State<RiderInterhubWalletScreen> createState() =>
      _RiderInterhubWalletScreenState();
}

class _RiderInterhubWalletScreenState extends State<RiderInterhubWalletScreen> {
  static const Color _background = Color(0xFFFBF7F2);
  static const Color _surface = Color(0xFFFFFDF9);
  static const Color _border = Color(0xFFEADCCC);
  static const Color _maroon = Color(0xFF561C17);
  static const Color _text = Color(0xFF3B211B);
  static const Color _muted = Color(0xFF987865);
  static const Color _green = Color(0xFF28724D);
  static const Color _amber = Color(0xFF946514);
  static const Color _danger = Color(0xFFB42318);

  List<Map<String, dynamic>> _rows = const <Map<String, dynamic>>[];
  DateTime? _fromDate;
  DateTime? _toDate;
  DateTime? _appliedFromDate;
  DateTime? _appliedToDate;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  Future<void> _loadRows() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final List<Map<String, dynamic>> rows = await WorkspaceMobileService.rows(
        'rider/attendance',
      );
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _shiftDate(Map<String, dynamic> row) {
    final String value = (row['clock_in_at'] ?? '').toString();
    return DateTime.tryParse(value)?.toLocal();
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  List<Map<String, dynamic>> get _filteredRows {
    return _rows
        .where((Map<String, dynamic> row) {
          final DateTime? shiftDate = _shiftDate(row);
          if (shiftDate == null) return false;
          final DateTime day = _dateOnly(shiftDate);
          if (_appliedFromDate != null &&
              day.isBefore(_dateOnly(_appliedFromDate!))) {
            return false;
          }
          if (_appliedToDate != null &&
              day.isAfter(_dateOnly(_appliedToDate!))) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic>? _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  String _money(double value) => formatPesoCurrency(value);

  String _formatDate(DateTime? value) {
    if (value == null) return 'mm/dd/yyyy';
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '$month/$day/${value.year}';
  }

  String _formatShiftDate(dynamic value) {
    final DateTime? date = value is DateTime
        ? value
        : DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Date unavailable';
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _hours(dynamic minutes) =>
      '${(_number(minutes) / 60).toStringAsFixed(2)} h';

  String _statusLabel(Map<String, dynamic> row) {
    final Map<String, dynamic>? payroll = _map(row['payroll']);
    if (payroll == null) {
      return (row['clock_out_at'] == null ||
              row['clock_out_at'].toString().isEmpty)
          ? 'On shift'
          : 'Awaiting payroll';
    }
    switch ((payroll['status'] ?? '').toString().trim().toUpperCase()) {
      case 'PAID':
        return 'Paid';
      case 'REVIEW_REQUIRED':
        return 'Hold for review';
      case 'PENDING':
        return 'Pending payment';
      default:
        return (payroll['status'] ?? 'Payroll recorded').toString();
    }
  }

  Color _statusColor(String label) {
    if (label == 'Paid') return _green;
    if (label == 'Hold for review') return _danger;
    if (label == 'Pending payment' || label == 'Awaiting payroll') {
      return _amber;
    }
    return _muted;
  }

  Map<String, double> get _summary {
    double paid = 0;
    double pending = 0;
    double review = 0;
    double awaiting = 0;
    double recordedPay = 0;
    double recordedMinutes = 0;

    for (final Map<String, dynamic> row in _filteredRows) {
      final bool isClosed =
          row['clock_out_at'] != null &&
          row['clock_out_at'].toString().isNotEmpty;
      final double grossPay = _number(row['gross_pay']);
      final Map<String, dynamic>? payroll = _map(row['payroll']);
      if (isClosed) {
        recordedPay += grossPay;
        recordedMinutes += _number(row['worked_minutes']);
      }
      if (payroll == null) {
        if (isClosed) awaiting += grossPay;
        continue;
      }

      final double payrollAmount = _number(payroll['amount'] ?? grossPay);
      switch ((payroll['status'] ?? '').toString().trim().toUpperCase()) {
        case 'PAID':
          paid += payrollAmount;
          break;
        case 'REVIEW_REQUIRED':
          review += payrollAmount;
          break;
        case 'PENDING':
          pending += payrollAmount;
          break;
        default:
          break;
      }
    }

    return <String, double>{
      'paid': paid,
      'pending': pending,
      'review': review,
      'awaiting': awaiting,
      'recorded_pay': recordedPay,
      'recorded_minutes': recordedMinutes,
    };
  }

  Future<void> _pickDate({required bool isFromDate}) async {
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: (isFromDate ? _fromDate : _toDate) ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isFromDate) {
        _fromDate = selected;
      } else {
        _toDate = selected;
      }
    });
  }

  void _applyDates() {
    if (_fromDate != null &&
        _toDate != null &&
        _dateOnly(_fromDate!).isAfter(_dateOnly(_toDate!))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('From date must be on or before To date.'),
        ),
      );
      return;
    }
    setState(() {
      _appliedFromDate = _fromDate;
      _appliedToDate = _toDate;
    });
  }

  void _clearDates() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _appliedFromDate = null;
      _appliedToDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, double> totals = _summary;
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        top: true,
        child: RefreshIndicator(
          color: _maroon,
          onRefresh: _loadRows,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              Text(
                'INTERHUB DRIVER WALLET',
                style: TextStyle(
                  color: _maroon,
                  fontSize: 10,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  const Text(
                    'Wallet & payroll',
                    style: TextStyle(
                      color: _text,
                      fontSize: 28,
                      height: 1.08,
                      letterSpacing: -0.6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onBackToDashboard,
                    style: TextButton.styleFrom(
                      foregroundColor: _muted,
                      backgroundColor: _surface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: _border),
                      ),
                    ),
                    child: const Text(
                      'Back to dashboard',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Track shift pay, payroll status, and payment proof from your Logistics center. Your Interhub pay is based on recorded hours.',
                style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 18),
              _dateFilterPanel(context),
              const SizedBox(height: 14),
              if (_error != null) ...[
                _messageCard(
                  icon: Icons.cloud_off_outlined,
                  title: 'Payroll data unavailable',
                  message: _error!,
                  action: TextButton.icon(
                    onPressed: _loading ? null : _loadRows,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final int columns = constraints.maxWidth >= 850 ? 3 : 2;
                  final double spacing = 10;
                  final double width =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                      columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      SizedBox(
                        width: width,
                        child: _metricCard(
                          label: 'Paid through payroll',
                          amount: totals['paid']!,
                          detail: 'Recorded payment with transfer proof',
                          color: _green,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _metricCard(
                          label: 'Pending payment',
                          amount: totals['pending']!,
                          detail: 'Included in a payroll period',
                          color: _amber,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _metricCard(
                          label: 'Hold for review',
                          amount: totals['review']!,
                          detail: 'Logistics review is required',
                          color: _danger,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _metricCard(
                          label: 'Awaiting payroll',
                          amount: totals['awaiting']!,
                          detail: 'Closed shifts not yet added to payroll',
                          color: _muted,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _metricCard(
                          label: 'Recorded shift pay',
                          amount: totals['recorded_pay']!,
                          detail:
                              '${(totals['recorded_minutes']! / 60).toStringAsFixed(2)} closed-shift hours in this date range',
                          color: _maroon,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              _historyPanel(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateFilterPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double fieldWidth = constraints.maxWidth >= 650
              ? 170
              : (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: fieldWidth,
                child: _dateField(
                  context,
                  label: 'From date',
                  value: _fromDate,
                  onTap: () => _pickDate(isFromDate: true),
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: _dateField(
                  context,
                  label: 'To date',
                  value: _toDate,
                  onTap: () => _pickDate(isFromDate: false),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _maroon,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _applyDates,
                child: const Text('Apply dates'),
              ),
              if (_appliedFromDate != null || _appliedToDate != null)
                TextButton(onPressed: _clearDates, child: const Text('Clear')),
            ],
          );
        },
      ),
    );
  }

  Widget _dateField(
    BuildContext context, {
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _text,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Material(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(value),
                      style: TextStyle(
                        color: value == null ? _muted : _text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.calendar_today_outlined, size: 15),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String label,
    required double amount,
    required String detail,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 7),
          Text(
            _money(amount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color == _muted ? _text : color,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 10, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _historyPanel(BuildContext context) {
    final List<Map<String, dynamic>> rows = _filteredRows;
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shift and payment history',
                  style: TextStyle(
                    color: _text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Each row is a recorded shift. Paid items include the reference and proof provided by Logistics.',
                  style: TextStyle(color: _muted, fontSize: 11, height: 1.45),
                ),
              ],
            ),
          ),
          if (_loading && rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 22, 18, 26),
              child: Center(
                child: Text(
                  'No shifts match these dates yet.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (constraints.maxWidth >= 760) {
                  return _desktopHistoryTable(rows);
                }
                return _mobileHistoryCards(rows);
              },
            ),
        ],
      ),
    );
  }

  Widget _desktopHistoryTable(List<Map<String, dynamic>> rows) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 44,
        dataRowMinHeight: 58,
        dataRowMaxHeight: 76,
        columns: const <DataColumn>[
          DataColumn(label: Text('Shift date')),
          DataColumn(label: Text('Transfer')),
          DataColumn(label: Text('Hours')),
          DataColumn(label: Text('Shift pay')),
          DataColumn(label: Text('Payroll status')),
          DataColumn(label: Text('Payment receipt')),
        ],
        rows: rows
            .map((Map<String, dynamic> row) {
              final String status = _statusLabel(row);
              return DataRow(
                cells: <DataCell>[
                  DataCell(Text(_formatShiftDate(row['clock_in_at']))),
                  DataCell(
                    SizedBox(
                      width: 150,
                      child: Text(
                        (row['manifest_number'] ?? 'No transfer assigned')
                            .toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(_hours(row['worked_minutes']))),
                  DataCell(Text(_money(_number(row['gross_pay'])))),
                  DataCell(_statusChip(status)),
                  DataCell(_receiptAction(row)),
                ],
              );
            })
            .toList(growable: false),
      ),
    );
  }

  Widget _mobileHistoryCards(List<Map<String, dynamic>> rows) {
    return Column(
      children: [
        for (int index = 0; index < rows.length; index++) ...[
          if (index > 0) const Divider(height: 1, color: _border),
          _mobileHistoryCard(rows[index]),
        ],
      ],
    );
  }

  Widget _mobileHistoryCard(Map<String, dynamic> row) {
    final String status = _statusLabel(row);
    final String transfer = (row['manifest_number'] ?? 'No transfer assigned')
        .toString();
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatShiftDate(row['clock_in_at']),
                      style: const TextStyle(
                        color: _text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      transfer,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _detail('Hours', _hours(row['worked_minutes']))),
              Expanded(
                child: _detail('Shift pay', _money(_number(row['gross_pay']))),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Payment receipt',
                  style: TextStyle(color: _muted, fontSize: 10),
                ),
              ),
              _receiptAction(row),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: _text,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String label) {
    final Color color = _statusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _receiptAction(Map<String, dynamic> row) {
    final Map<String, dynamic>? payroll = _map(row['payroll']);
    if (payroll == null) {
      return const Text('—', style: TextStyle(color: _muted, fontSize: 11));
    }
    final String reference = (payroll['payment_reference'] ?? '')
        .toString()
        .trim();
    final bool hasProof = payroll['proof_available'] == true;
    final String? itemId = payroll['id']?.toString();
    if (hasProof && itemId != null && itemId.isNotEmpty) {
      return TextButton.icon(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 7),
        ),
        onPressed: () => openWorkflowProof(
          context,
          'rider/attendance/payroll-items/$itemId/proof',
        ),
        icon: const Icon(Icons.receipt_long_outlined, size: 15),
        label: Text(reference.isEmpty ? 'View proof' : reference),
      );
    }
    if (reference.isNotEmpty) {
      return Text(
        reference,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _muted, fontSize: 10),
      );
    }
    return const Text('—', style: TextStyle(color: _muted, fontSize: 11));
  }

  Widget _messageCard({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0D0CC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                if (action != null) action,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
