import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../services/logistics_mobile_service.dart';

class LogisticsTransfersScreen extends StatefulWidget {
  final bool outgoing;

  const LogisticsTransfersScreen({super.key, this.outgoing = false});

  @override
  State<LogisticsTransfersScreen> createState() =>
      _LogisticsTransfersScreenState();
}

class _LogisticsTransfersScreenState extends State<LogisticsTransfersScreen> {
  static const Color _brand = Color(0xFF561C17);
  static const Color _ink = Color(0xFF3B211B);
  static const Color _muted = Color(0xFF987865);
  static const Color _border = Color(0xFFEADCCC);
  static const Color _surface = Color(0xFFFFFDF9);
  static const Color _soft = Color(0xFFF6EFE7);

  List<LogisticsTransfer> _transfers = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTransfers();
  }

  Future<void> _loadTransfers({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final transfers = widget.outgoing
          ? await LogisticsMobileService.fetchOutgoingTransfers()
          : await LogisticsMobileService.fetchIncomingTransfers();
      if (!mounted) return;
      setState(() {
        _transfers = transfers;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openTransfer(LogisticsTransfer transfer) async {
    final String actionPath = widget.outgoing ? 'releasing' : 'receiving';
    await context.push<void>('/logistics/transfers/$actionPath/${transfer.id}');
    if (mounted) await _loadTransfers(showLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.resolve(
        context,
        const Color(0xFFFBF7F2),
        fill: true,
      ),
      appBar: AppBar(
        title: Text(
          widget.outgoing
              ? 'Outgoing inter-hub parcels'
              : 'Incoming inter-hub parcels',
        ),
        foregroundColor: AppTheme.resolve(context, _ink),
        backgroundColor: AppTheme.resolve(
          context,
          const Color(0xFFFBF7F2),
          fill: true,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh transfers',
            onPressed: _loading ? null : () => _loadTransfers(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.resolve(context, _brand),
        onRefresh: () => _loadTransfers(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Text(
              widget.outgoing
                  ? 'Release transfer parcels'
                  : 'Receive transfer parcels',
              style: TextStyle(
                color: AppTheme.resolve(context, _ink),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.outgoing
                  ? 'Choose a sealed transfer accepted by its driver, then scan each parcel at handoff to mark it released.'
                  : 'Choose an incoming manifest, then scan each parcel to record destination-hub receipt.',
              style: TextStyle(
                color: AppTheme.resolve(context, _muted),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            if (_error != null) _messageCard(_error!, isError: true),
            if (_loading && _transfers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error == null && _transfers.isEmpty)
              _messageCard(
                widget.outgoing
                    ? 'No sealed transfers are waiting for release to an accepted driver.'
                    : 'No incoming inter-hub transfers are waiting for receipt.',
              ),
            ..._transfers.map(_transferCard),
          ],
        ),
      ),
    );
  }

  Widget _transferCard(LogisticsTransfer transfer) {
    final int completedCount = widget.outgoing
        ? transfer.releasedCount
        : transfer.receivedCount;
    final String progress = widget.outgoing
        ? '$completedCount of ${transfer.totalCount} parcels released'
        : '$completedCount of ${transfer.totalCount} parcels received';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.resolve(context, _surface, fill: true),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.resolve(context, _border)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openTransfer(transfer),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    color: AppTheme.resolve(context, _brand),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      transfer.manifestNumber,
                      style: TextStyle(
                        color: AppTheme.resolve(context, _ink),
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  _statusChip(transfer.status),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                widget.outgoing
                    ? 'To ${transfer.destinationCenterName}'
                    : 'From ${transfer.originCenterName}',
                style: TextStyle(
                  color: AppTheme.resolve(context, _muted),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                progress,
                style: TextStyle(
                  color: AppTheme.resolve(context, _ink),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openTransfer(transfer),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(
                    widget.outgoing
                        ? 'Open and release parcels'
                        : 'Open and receive parcels',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.resolve(
                      context,
                      _brand,
                      fill: true,
                    ),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _soft, fill: true),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: AppTheme.resolve(context, _brand),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _messageCard(String message, {bool isError = false}) {
    final Color color = isError
        ? AppTheme.lightDanger
        : AppTheme.resolve(context, _muted);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _surface, fill: true),
        border: Border.all(color: AppTheme.resolve(context, _border)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: color,
          height: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class LogisticsTransferDetailsScreen extends StatefulWidget {
  final int manifestId;
  final bool outgoing;

  const LogisticsTransferDetailsScreen({
    super.key,
    required this.manifestId,
    this.outgoing = false,
  });

  @override
  State<LogisticsTransferDetailsScreen> createState() =>
      _LogisticsTransferDetailsScreenState();
}

class _LogisticsTransferDetailsScreenState
    extends State<LogisticsTransferDetailsScreen> {
  static const Color _brand = Color(0xFF561C17);
  static const Color _ink = Color(0xFF3B211B);
  static const Color _muted = Color(0xFF987865);
  static const Color _border = Color(0xFFEADCCC);
  static const Color _surface = Color(0xFFFFFDF9);
  static const Color _soft = Color(0xFFF6EFE7);

  LogisticsTransfer? _transfer;
  String? _error;
  bool _loading = true;
  int? _workingItemId;

  @override
  void initState() {
    super.initState();
    _loadTransfer();
  }

  Future<void> _loadTransfer({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final transfer = widget.outgoing
          ? await LogisticsMobileService.fetchOutgoingTransfer(
              widget.manifestId,
            )
          : await LogisticsMobileService.fetchIncomingTransfer(
              widget.manifestId,
            );
      if (!mounted) return;
      setState(() {
        _transfer = transfer;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _scanAndUpdateParcel(LogisticsTransferItem item) async {
    final bool canAct = widget.outgoing ? item.canRelease : item.canReceive;
    if (_workingItemId != null || !canAct) return;
    final Map<String, String>? scan = await context.push<Map<String, String>>(
      '/logistics/scanner',
      extra: item.trackingNumber,
    );
    if (!mounted || scan == null) return;

    setState(() => _workingItemId = item.id);
    try {
      final String scannedCode = scan['scanned_code'] ?? '';
      final String scanMethod = scan['scan_method'] ?? 'MANUAL';
      final updated = widget.outgoing
          ? await LogisticsMobileService.releaseOutgoingTransferItem(
              manifestId: widget.manifestId,
              itemId: item.id,
              scannedCode: scannedCode,
              scanMethod: scanMethod,
            )
          : await LogisticsMobileService.receiveTransferItem(
              manifestId: widget.manifestId,
              itemId: item.id,
              scannedCode: scannedCode,
              scanMethod: scanMethod,
            );
      if (!mounted) return;
      setState(() {
        _transfer = updated;
        _error = null;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              widget.outgoing
                  ? '${item.trackingNumber} released to the transfer driver.'
                  : '${item.trackingNumber} received at the destination hub and moved to sorting.',
            ),
            backgroundColor: AppTheme.resolve(
              context,
              const Color(0xFF237A44),
              fill: true,
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Could not ${widget.outgoing ? 'release' : 'receive'} parcel: $error',
            ),
            backgroundColor: AppTheme.resolve(
              context,
              AppTheme.lightDanger,
              fill: true,
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _workingItemId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transfer = _transfer;
    return Scaffold(
      backgroundColor: AppTheme.resolve(
        context,
        const Color(0xFFFBF7F2),
        fill: true,
      ),
      appBar: AppBar(
        title: Text(
          transfer?.manifestNumber ??
              (widget.outgoing ? 'Release transfer' : 'Receive transfer'),
        ),
        foregroundColor: AppTheme.resolve(context, _ink),
        backgroundColor: AppTheme.resolve(
          context,
          const Color(0xFFFBF7F2),
          fill: true,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh transfer',
            onPressed: _loading ? null : () => _loadTransfer(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading && transfer == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && transfer == null
          ? _loadError()
          : transfer == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              color: AppTheme.resolve(context, _brand),
              onRefresh: () => _loadTransfer(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                children: [
                  _summary(transfer),
                  const SizedBox(height: 16),
                  Text(
                    'Parcels',
                    style: TextStyle(
                      color: AppTheme.resolve(context, _ink),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (transfer.items.isEmpty)
                    _notice('This transfer has no parcel items.')
                  else
                    ...transfer.items.map(_itemCard),
                ],
              ),
            ),
    );
  }

  Widget _summary(LogisticsTransfer transfer) {
    final int completedCount = widget.outgoing
        ? transfer.releasedCount
        : transfer.receivedCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _surface, fill: true),
        border: Border.all(color: AppTheme.resolve(context, _border)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            transfer.manifestNumber,
            style: TextStyle(
              color: AppTheme.resolve(context, _ink),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Origin: ${transfer.originCenterName}',
            style: TextStyle(color: AppTheme.resolve(context, _muted)),
          ),
          if (transfer.destinationCenterName.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'Destination: ${transfer.destinationCenterName}',
              style: TextStyle(color: AppTheme.resolve(context, _muted)),
            ),
          ],
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: transfer.totalCount == 0
                ? 0
                : completedCount / transfer.totalCount,
            color: AppTheme.resolve(context, _brand),
            backgroundColor: AppTheme.resolve(context, _soft, fill: true),
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 7),
          Text(
            '$completedCount of ${transfer.totalCount} ${widget.outgoing ? 'released' : 'received'} · ${transfer.pendingCount} pending',
            style: TextStyle(
              color: AppTheme.resolve(context, _ink),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.lightDanger, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemCard(LogisticsTransferItem item) {
    final bool pending = widget.outgoing ? item.canRelease : item.canReceive;
    final bool working = _workingItemId == item.id;
    final String statusText = pending
        ? (widget.outgoing
              ? 'Awaiting handoff scan'
              : 'Awaiting destination scan')
        : widget.outgoing && item.isReleased
        ? 'Released'
        : item.status.replaceAll('_', ' ');
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      color: AppTheme.resolve(context, _surface, fill: true),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.resolve(context, _border)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.trackingNumber.isEmpty
                  ? 'Parcel ${item.id}'
                  : item.trackingNumber,
              style: TextStyle(
                color: AppTheme.resolve(context, _ink),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              statusText,
              style: TextStyle(
                color: AppTheme.resolve(
                  context,
                  pending ? _muted : const Color(0xFF237A44),
                ),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (pending) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _workingItemId == null
                      ? () => _scanAndUpdateParcel(item)
                      : null,
                  icon: working
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(
                    working
                        ? (widget.outgoing
                              ? 'Recording release...'
                              : 'Recording receipt...')
                        : (widget.outgoing
                              ? 'Scan to release'
                              : 'Scan to receive'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.resolve(context, _brand),
                    side: BorderSide(color: AppTheme.resolve(context, _brand)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _loadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? 'Could not load transfer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.resolve(context, _muted)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _loadTransfer(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _surface, fill: true),
        border: Border.all(color: AppTheme.resolve(context, _border)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(color: AppTheme.resolve(context, _muted)),
      ),
    );
  }
}
