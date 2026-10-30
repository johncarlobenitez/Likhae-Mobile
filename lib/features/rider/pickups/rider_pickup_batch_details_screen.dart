import 'package:flutter/material.dart';
import 'dart:async';
import '../rider_product_image.dart';
import '../rider_stage_navigation_screen.dart';
import '../scanner/rider_parcel_scan_result.dart';

import 'rider_pickup_details_screen.dart' show RiderParcelScannerScreen;
import 'rider_pickups_screen.dart';

class RiderPickupBatchDetailsScreen extends StatefulWidget {
  final RiderPickupData batch;
  final Future<void> Function(int batchId)? onAccept;
  final Future<void> Function(int batchId)? onStart;
  final Future<void> Function(int batchId, String trackingCode, String method)?
  onScan;
  final Future<void> Function({
    required int batchId,
    required int assignmentId,
    required String reason,
  })?
  onNotCollected;
  final Future<void> Function(int batchId)? onFinish;
  final Future<RiderPickupData?> Function(int batchId)? onReload;

  const RiderPickupBatchDetailsScreen({
    super.key,
    required this.batch,
    this.onAccept,
    this.onStart,
    this.onScan,
    this.onNotCollected,
    this.onFinish,
    this.onReload,
  });

  @override
  State<RiderPickupBatchDetailsScreen> createState() =>
      _RiderPickupBatchDetailsScreenState();
}

class _RiderPickupBatchDetailsScreenState
    extends State<RiderPickupBatchDetailsScreen> {
  static const Color _background = Color(0xFFFBF7F2);
  static const Color _surface = Color(0xFFFFFDF9);
  static const Color _border = Color(0xFFEADCCC);
  static const Color _maroon = Color(0xFF561C17);
  static const Color _text = Color(0xFF3B211B);
  static const Color _muted = Color(0xFF987865);
  static const Color _green = Color(0xFF237A44);

  late RiderPickupData _batch;
  bool _busy = false;
  bool _changed = false;
  bool _needsRefresh = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _batch = widget.batch;
    if (widget.onReload != null) unawaited(_refresh());
  }

  Future<void> _loadLatest() async {
    final latest = await widget.onReload?.call(_batch.id);
    if (latest == null) {
      throw StateError(
        'Could not load the current pickup. Refresh to try again.',
      );
    }
    if (!mounted) return;
    _batch = latest;
    _needsRefresh = false;
  }

  Future<void> _refresh() async {
    if (_busy || widget.onReload == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _loadLatest();
    } catch (error) {
      if (mounted) {
        setState(() {
          _needsRefresh = true;
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openNavigation({required bool toLogisticsCenter}) async {
    final double? latitude = toLogisticsCenter
        ? _batch.logisticsCenterLatitude
        : _batch.sellerLatitude;
    final double? longitude = toLogisticsCenter
        ? _batch.logisticsCenterLongitude
        : _batch.sellerLongitude;
    final bool hasCoordinates =
        latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        (latitude != 0 || longitude != 0);
    if (!hasCoordinates) {
      _showMessage(
        toLogisticsCenter
            ? 'The logistics center map pin is unavailable.'
            : 'The seller pickup map pin is unavailable.',
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => RiderStageNavigationScreen(
          pickup: _batch,
          toLogisticsCenter: toLogisticsCenter,
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function()? action, String success) async {
    if (_busy || _needsRefresh) return;
    if (action == null) {
      _showMessage('Pickup batch API is not connected.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      _changed = true;
      String message = success;
      try {
        await _loadLatest();
      } catch (error) {
        message = '$success Refresh failed: $error';
        _needsRefresh = true;
        _error =
            'Your action was saved. Refresh the pickup before continuing. $error';
      }
      if (mounted) _showMessage(message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanWithCamera() async {
    final RiderParcelScanResult? scan = await Navigator.of(context)
        .push<RiderParcelScanResult>(
          MaterialPageRoute<RiderParcelScanResult>(
            fullscreenDialog: true,
            builder: (BuildContext context) =>
                const RiderParcelScannerScreen(returnScanDetails: true),
          ),
        );
    if (scan == null || scan.code.trim().isEmpty || !mounted) return;
    await _run(
      widget.onScan == null
          ? null
          : () => widget.onScan!(_batch.id, scan.code.trim(), scan.method),
      'Parcel scanned and pickup recorded.',
    );
  }

  Future<void> _scanManually() async {
    String enteredCode = '';
    final String? code = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        void closeDialog([String? value]) {
          FocusManager.instance.primaryFocus?.unfocus();
          Navigator.of(dialogContext).pop(value);
        }

        return AlertDialog(
          backgroundColor: _surface,
          title: const Text('Enter tracking code'),
          content: TextField(
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'Tracking number'),
            onChanged: (String value) => enteredCode = value,
            onSubmitted: (String value) => closeDialog(value.trim()),
          ),
          actions: <Widget>[
            TextButton(onPressed: closeDialog, child: const Text('Cancel')),
            FilledButton(
              onPressed: () => closeDialog(enteredCode.trim()),
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
    if (code == null || code.isEmpty || !mounted) return;
    await _run(
      widget.onScan == null
          ? null
          : () => widget.onScan!(_batch.id, code, 'MANUAL'),
      'Parcel verified and pickup recorded.',
    );
  }

  Future<void> _markNotCollected(RiderPickupBatchItemData parcel) async {
    String enteredReason = '';
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Mark parcel not collected'),
        content: TextField(
          onChanged: (value) => enteredReason = value,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Reason, e.g. seller is unavailable',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final String value = enteredReason.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Submit reason'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    await _run(
      widget.onNotCollected == null
          ? null
          : () => widget.onNotCollected!(
              batchId: _batch.id,
              assignmentId: parcel.assignmentId,
              reason: reason,
            ),
      'Parcel marked as not collected.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final String status = _batch.normalizedStatus;
    final bool inProgress = status == 'IN_PROGRESS';
    final bool allResolved =
        _batch.parcels.isNotEmpty && _batch.parcels.every((p) => p.isResolved);
    final int collected = _batch.parcels.where((p) => p.wasCollected).length;
    final String progressStatusLabel = inProgress && allResolved
        ? 'Ready for hub'
        : _batch.statusLabel;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _text,
        elevation: 0,
        title: Text(
          _batch.batchNumber.isEmpty ? 'Pickup Batch' : _batch.batchNumber,
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(_changed),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh pickup',
            onPressed: _busy || widget.onReload == null ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            if (const {'LOADING', 'READY', 'IN_PROGRESS'}.contains(status)) ...[
              if (!inProgress)
                _notice('Accept and start seller pickup to enable scanning.'),
              OutlinedButton.icon(
                onPressed: inProgress && !_busy && !_needsRefresh
                    ? _scanWithCamera
                    : null,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan parcel barcode / QR'),
              ),
              TextButton.icon(
                onPressed: inProgress && !_busy && !_needsRefresh
                    ? _scanManually
                    : null,
                icon: const Icon(Icons.keyboard_alt_outlined),
                label: const Text('Enter tracking code manually'),
              ),
              const SizedBox(height: 14),
            ],
            _buildSellerCard(),
            const SizedBox(height: 14),
            _buildProgressCard(collected, progressStatusLabel),
            const SizedBox(height: 14),
            if (status == 'READY' || (inProgress && !allResolved)) ...<Widget>[
              OutlinedButton.icon(
                onPressed: _busy || _needsRefresh
                    ? null
                    : () => _openNavigation(toLogisticsCenter: false),
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Navigate to seller'),
              ),
              const SizedBox(height: 12),
            ],
            if (status == 'EN_ROUTE_TO_HUB') ...<Widget>[
              OutlinedButton.icon(
                onPressed: _busy || _needsRefresh
                    ? null
                    : () => _openNavigation(toLogisticsCenter: true),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Navigate to logistics center'),
              ),
              const SizedBox(height: 12),
            ],
            if (_error != null) ...<Widget>[
              _buildError(_error!),
              const SizedBox(height: 12),
            ],
            _buildParcelList(inProgress && !_needsRefresh),
            const SizedBox(height: 16),
            if (status == 'LOADING')
              _actionButton(
                label: 'Accept pickup batch',
                icon: Icons.check_circle_outline_rounded,
                onPressed: () => _run(
                  widget.onAccept == null
                      ? null
                      : () => widget.onAccept!(_batch.id),
                  'Pickup batch accepted.',
                ),
              )
            else if (status == 'READY')
              _actionButton(
                label: 'Start seller pickup',
                icon: Icons.play_arrow_rounded,
                onPressed: () => _run(
                  widget.onStart == null
                      ? null
                      : () => widget.onStart!(_batch.id),
                  'Pickup started. Scan each waybill.',
                ),
              )
            else if (inProgress) ...<Widget>[
              _actionButton(
                label: allResolved
                    ? 'Finish pickup and go to hub'
                    : 'Finish after resolving every parcel',
                icon: Icons.local_shipping_outlined,
                onPressed: allResolved && !_busy && !_needsRefresh
                    ? () => _run(
                        widget.onFinish == null
                            ? null
                            : () => widget.onFinish!(_batch.id),
                        'Pickup batch finished. Head to the logistics center.',
                      )
                    : null,
              ),
            ] else if (status == 'EN_ROUTE_TO_HUB')
              _notice(
                'Pickup is complete. Deliver $collected collected parcel(s) to ${_batch.logisticsCenter.isEmpty ? 'the logistics center' : _batch.logisticsCenter}.',
              )
            else if (status == 'COMPLETED')
              _notice('This pickup batch is completed.')
            else
              _notice(
                'No pickup action is available for this status. Refresh for the latest update.',
              ),
            if (_busy) ...<Widget>[
              const SizedBox(height: 14),
              const Center(child: CircularProgressIndicator(color: _maroon)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSellerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _batch.sellerName.isEmpty ? 'Seller' : _batch.sellerName,
            style: const TextStyle(
              color: _text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _infoRow(Icons.storefront_outlined, 'Pickup address', _batch.address),
          if (_batch.logisticsCenter.isNotEmpty ||
              _batch.destinationAddress.isNotEmpty) ...<Widget>[
            const Divider(height: 22, color: _border),
            _infoRow(
              Icons.local_shipping_outlined,
              'Logistics center',
              _batch.logisticsCenter,
            ),
            if (_batch.destinationAddress.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 29, top: 4),
                child: Text(
                  _batch.destinationAddress,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
          ],
          if (_batch.approvedCapacity > 0) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Approved capacity: ${_batch.approvedCapacity} parcels',
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressCard(int collected, String statusLabel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3DC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.inventory_2_outlined, color: _maroon),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              '$collected of ${_batch.parcels.length} parcels collected',
              style: const TextStyle(color: _text, fontWeight: FontWeight.w800),
            ),
          ),
          _statusChip(statusLabel),
        ],
      ),
    );
  }

  Widget _buildParcelList(bool inProgress) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Parcels (${_batch.parcels.length})',
              style: const TextStyle(
                color: _text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (_batch.parcels.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Text(
                'No parcels are attached to this batch.',
                style: TextStyle(color: _muted),
              ),
            )
          else
            ..._batch.parcels.asMap().entries.map((entry) {
              final RiderPickupBatchItemData parcel = entry.value;
              return Column(
                children: <Widget>[
                  if (entry.key > 0) const Divider(height: 1, color: _border),
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            RiderProductImage(
                              imageUrl: parcel.imageUrl,
                              size: 58,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    parcel.trackingCode.isEmpty
                                        ? 'Tracking unavailable'
                                        : parcel.trackingCode,
                                    style: const TextStyle(
                                      color: _text,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (parcel
                                      .sellerOrderNumber
                                      .isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Order ${parcel.sellerOrderNumber}',
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  if (parcel.products.isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 5),
                                    Text(
                                      parcel.products.join(', '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _statusChip(_itemStatusLabel(parcel)),
                        if (parcel.notCollectedReason?.isNotEmpty ==
                            true) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            'Reason: ${parcel.notCollectedReason}',
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                        if (inProgress && !parcel.isResolved) ...<Widget>[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _markNotCollected(parcel),
                              icon: const Icon(
                                Icons.report_gmailerrorred_outlined,
                                size: 18,
                              ),
                              label: const Text('Not collected'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF9E3328),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: _muted, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
              const SizedBox(height: 3),
              Text(
                value.isEmpty ? 'Address unavailable' : value,
                style: const TextStyle(
                  color: _text,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return FilledButton.icon(
      onPressed: _busy || _needsRefresh ? null : onPressed,
      icon: Icon(icon),
      label: Text(label, textAlign: TextAlign.center),
      style: FilledButton.styleFrom(
        backgroundColor: _maroon,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _statusChip(String label) {
    final bool success =
        label.toLowerCase().contains('collected') ||
        label.toLowerCase() == 'completed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: success ? const Color(0xFFEAF6EE) : const Color(0xFFFFF3DC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: success ? _green : const Color(0xFF946514),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1B7B2)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF9E3328), height: 1.4),
      ),
    );
  }

  Widget _notice(String message) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6EE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: _green,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }

  String _itemStatusLabel(RiderPickupBatchItemData parcel) {
    if (parcel.wasCollected) {
      final String shipmentStatus = parcel.shipmentStatus.trim().toUpperCase();
      return switch (shipmentStatus) {
        'PICKED_UP' => 'Picked up from seller',
        'AT_SORTING_CENTER' => 'Received at sorting center',
        'SORTED' => 'Received and sorted',
        'DELIVERED' => 'Pickup complete · delivered',
        '' => 'Pickup complete · status unavailable',
        final status => 'Pickup complete · ${status.replaceAll('_', ' ')}',
      };
    }
    if (parcel.normalizedStatus == 'REJECTED') return 'Not collected';
    if (parcel.normalizedStatus == 'CANCELLED') return 'Cancelled';
    return parcel.assignmentStatus.replaceAll('_', ' ').toLowerCase();
  }
}
