import 'package:likhae/core/theme/app_theme.dart';

import 'package:flutter/material.dart';

class RiderInterHubTransferItem {
  final int id;
  final String trackingCode;
  final String status;

  const RiderInterHubTransferItem({
    required this.id,
    required this.trackingCode,
    required this.status,
  });

  factory RiderInterHubTransferItem.fromApi(Map<String, dynamic> json) {
    return RiderInterHubTransferItem(
      id: _toInt(json['id']),
      trackingCode: (json['tracking_code'] ?? '').toString().trim(),
      status: (json['status'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic value) =>
      int.tryParse(value?.toString() ?? '') ?? 0;
}

class RiderInterHubTransferData {
  final int id;
  final String manifestNumber;
  final String originHub;
  final String destinationHub;
  final String status;
  final bool driverAccepted;
  final List<RiderInterHubTransferItem> items;
  final bool canAccept;
  final bool canDecline;
  final bool canStart;

  const RiderInterHubTransferData({
    this.id = 0,
    required this.manifestNumber,
    required this.originHub,
    required this.destinationHub,
    required this.status,
    this.driverAccepted = false,
    this.items = const <RiderInterHubTransferItem>[],
    this.canAccept = false,
    this.canDecline = false,
    this.canStart = false,
  });

  factory RiderInterHubTransferData.fromApi(Map<String, dynamic> json) {
    final String status = _firstValue(json, const <String>[
      'status',
      'status_label',
    ]);
    final bool accepted = (json['driver_accepted_at'] ?? '')
        .toString()
        .isNotEmpty;
    final List<RiderInterHubTransferItem> items = json['items'] is List
        ? (json['items'] as List)
              .whereType<Map>()
              .map(
                (Map item) => RiderInterHubTransferItem.fromApi(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <RiderInterHubTransferItem>[];

    return RiderInterHubTransferData(
      id: int.tryParse((json['id'] ?? '').toString()) ?? 0,
      manifestNumber: _firstValue(json, const <String>[
        'manifest_number',
        'manifest_code',
        'manifest_no',
        'manifest_reference',
        'reference',
        'code',
      ]),
      originHub: _hubName(
        json,
        const <String>[
          'origin_hub',
          'from_hub',
          'source_hub',
          'origin_center',
          'origin_logistics_center',
          'origin',
        ],
        const <String>[
          'origin_hub_name',
          'from_hub_name',
          'origin_center_name',
          'origin_logistics_center_name',
          'from_center_name',
          'origin_name',
        ],
      ),
      destinationHub: _hubName(
        json,
        const <String>[
          'destination_hub',
          'to_hub',
          'target_hub',
          'destination_center',
          'destination_logistics_center',
          'destination',
        ],
        const <String>[
          'destination_hub_name',
          'to_hub_name',
          'destination_center_name',
          'destination_logistics_center_name',
          'to_center_name',
          'destination_name',
        ],
      ),
      status: status,
      driverAccepted: accepted,
      items: items,
      canAccept: _boolOr(
        json['can_accept'],
        status.toUpperCase() == 'SEALED' && !accepted,
      ),
      canDecline: _boolOr(
        json['can_decline'],
        <String>{'DRAFT', 'SEALED'}.contains(status.toUpperCase()) && !accepted,
      ),
      canStart: _boolOr(
        json['can_start'],
        status.toUpperCase() == 'RELEASED' && accepted,
      ),
    );
  }

  static bool _boolOr(dynamic value, bool fallback) =>
      value is bool ? value : fallback;

  static String _hubName(
    Map<String, dynamic> json,
    List<String> nestedKeys,
    List<String> directKeys,
  ) {
    for (final String key in nestedKeys) {
      final dynamic value = json[key];
      if (value is Map) {
        final String name = _firstValue(
          Map<String, dynamic>.from(value),
          const <String>['name', 'label', 'code'],
        );
        if (name.isNotEmpty) return name;
      } else if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    final String direct = _firstValue(json, directKeys);
    return direct.isEmpty ? 'Hub not specified' : direct;
  }

  static String _firstValue(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = json[key];
      if (value == null || value is Map || value is List) continue;
      final String text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String get displayManifestNumber =>
      manifestNumber.isEmpty ? 'Transfer manifest' : manifestNumber;

  String get displayStatus {
    final String value = status.trim();
    if (value.isEmpty) return 'PENDING';
    return value.replaceAll('_', ' ').toUpperCase();
  }

  bool get isReceived {
    final String normalized = status.trim().toLowerCase();
    return normalized == 'received' || normalized == 'completed';
  }
}

typedef RiderTransferAccept = Future<void> Function(int manifestId);
typedef RiderTransferDecline =
    Future<void> Function(int manifestId, String reason);
typedef RiderTransferStart = Future<void> Function(int manifestId);

class RiderInterHubTransfersScreen extends StatefulWidget {
  final List<RiderInterHubTransferData> transfers;
  final String? statusMessage;
  final Future<void> Function()? onRefresh;
  final RiderTransferAccept? onAccept;
  final RiderTransferDecline? onDecline;
  final RiderTransferStart? onStart;
  final Future<RiderInterHubTransferData> Function(int manifestId)?
  onLoadTransfer;

  const RiderInterHubTransfersScreen({
    super.key,
    this.transfers = const <RiderInterHubTransferData>[],
    this.statusMessage,
    this.onRefresh,
    this.onAccept,
    this.onDecline,
    this.onStart,
    this.onLoadTransfer,
  });

  @override
  State<RiderInterHubTransfersScreen> createState() =>
      _RiderInterHubTransfersScreenState();
}

class _RiderInterHubTransfersScreenState
    extends State<RiderInterHubTransfersScreen> {
  static const Color _background = Color(0xFFFBF7F2);
  static const Color _surface = Color(0xFFFFFDF9);
  static const Color _border = Color(0xFFEADCCC);
  static const Color _maroon = Color(0xFF561C17);
  static const Color _text = Color(0xFF3B211B);
  static const Color _muted = Color(0xFF987865);

  final Set<int> _busyManifestIds = <int>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.resolve(context, _background, fill: true),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.resolve(context, _maroon),
          onRefresh: () async {
            await widget.onRefresh?.call();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 112),
            children: <Widget>[
              _brandHeader(),
              const SizedBox(height: 22),
              Text(
                'Inter-hub transfers',
                style: TextStyle(
                  color: AppTheme.resolve(context, _text),
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Review and accept your assigned manifest. The origin hub scans '
                'and releases the parcels; then start transport in the app. '
                'The destination hub scans them on arrival.',
                style: TextStyle(
                  color: AppTheme.resolve(context, _muted),
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
              if (widget.statusMessage?.trim().isNotEmpty == true) ...<Widget>[
                const SizedBox(height: 16),
                _message(widget.statusMessage!),
              ],
              const SizedBox(height: 20),
              if (widget.transfers.isEmpty)
                _emptyState()
              else
                for (final RiderInterHubTransferData transfer
                    in widget.transfers) ...<Widget>[
                  _transferCard(transfer),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _brandHeader() {
    return Row(
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.resolve(context, _maroon, fill: true),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.local_shipping_rounded, color: Colors.white),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'LIKHAE RIDER',
              style: TextStyle(
                color: AppTheme.resolve(context, _text),
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Inter-logistics workspace',
              style: TextStyle(
                color: AppTheme.resolve(context, _muted),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _message(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, const Color(0xFFFFF1F0), fill: true),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: AppTheme.resolve(context, Color(0xFFB42318)),
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _transferCard(RiderInterHubTransferData transfer) {
    final String parcelCount = transfer.items.length.toString();
    final Color statusColor = transfer.isReceived
        ? AppTheme.resolve(context, const Color(0xFF237A44))
        : <String>{'CANCELLED', 'CANCELED'}.contains(transfer.displayStatus)
        ? AppTheme.resolve(context, const Color(0xFF8A3E34))
        : AppTheme.resolve(context, _muted);
    final bool busy = _busyManifestIds.contains(transfer.id);
    final String origin = _hubLabel(transfer.originHub, 'Origin hub');
    final String destination = _hubLabel(
      transfer.destinationHub,
      'Destination hub',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _surface, fill: true),
        border: Border.all(color: AppTheme.resolve(context, _border)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      transfer.displayManifestNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.resolve(context, _text),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  transfer.displayStatus,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
            decoration: BoxDecoration(
              color: AppTheme.resolve(
                context,
                const Color(0xFFF7F1EA),
                fill: true,
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: AppTheme.resolve(
                  context,
                  _border,
                ).withValues(alpha: 0.7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.route_rounded,
                      size: 14,
                      color: AppTheme.resolve(context, _maroon),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'DELIVERY ROUTE',
                      style: TextStyle(
                        color: AppTheme.resolve(context, _muted),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(child: _routeEndpoint('ORIGIN', origin)),
                    Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.resolve(context, _maroon, fill: true),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(child: _routeEndpoint('DESTINATION', destination)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(
                Icons.inventory_2_outlined,
                size: 15,
                color: AppTheme.resolve(context, _muted),
              ),
              const SizedBox(width: 6),
              Text(
                '$parcelCount ${parcelCount == '1' ? 'parcel' : 'parcels'}',
                style: TextStyle(
                  color: AppTheme.resolve(context, _muted),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _transferProgress(transfer),
          if (transfer.driverAccepted &&
              transfer.status.toUpperCase() == 'SEALED') ...<Widget>[
            const SizedBox(height: 10),
            const _TransferNote(
              icon: Icons.check_circle_outline_rounded,
              text:
                  'You accepted this manifest. Wait for Logistics to release it.',
            ),
          ],
          if (transfer.canStart) ...<Widget>[
            const SizedBox(height: 10),
            const _TransferNote(
              icon: Icons.qr_code_scanner_rounded,
              text:
                  'Released by the origin hub. Start transport when you are ready; no rider parcel scan is needed.',
            ),
          ],
          if (transfer.status.toUpperCase() == 'IN_TRANSIT') ...<Widget>[
            const SizedBox(height: 10),
            const _TransferNote(
              icon: Icons.local_shipping_outlined,
              text:
                  'Transport is in progress. The destination hub will scan and confirm the parcels on arrival.',
            ),
          ],
          if (transfer.isReceived) ...<Widget>[
            const SizedBox(height: 10),
            const _TransferNote(
              icon: Icons.task_alt_rounded,
              text:
                  'The destination hub received the manifest. This transfer is complete.',
            ),
          ],
          if (transfer.canAccept ||
              transfer.canDecline ||
              transfer.canStart) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (transfer.canAccept && widget.onAccept != null)
                  FilledButton.icon(
                    onPressed: busy ? null : () => _accept(transfer),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Accept'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.resolve(
                        context,
                        _maroon,
                        fill: true,
                      ),
                    ),
                  ),
                if (transfer.canDecline && widget.onDecline != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _decline(transfer),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Decline'),
                  ),
                if (transfer.canStart && widget.onStart != null)
                  FilledButton.icon(
                    onPressed: busy || transfer.items.isEmpty
                        ? null
                        : () => _start(transfer),
                    icon: const Icon(Icons.route_rounded, size: 18),
                    label: const Text('Start transport'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.resolve(
                        context,
                        _maroon,
                        fill: true,
                      ),
                    ),
                  ),
              ],
            ),
            if (busy) ...<Widget>[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                color: AppTheme.resolve(context, _maroon),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _routeEndpoint(String label, String hub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: AppTheme.resolve(context, _muted),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          hub,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.resolve(context, _text),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  String _hubLabel(String value, String fallback) {
    final String clean = value.trim();
    if (clean.isEmpty || clean.startsWith('Instance of ')) return fallback;
    return clean;
  }

  Widget _transferProgress(RiderInterHubTransferData transfer) {
    final String status = transfer.status.toUpperCase();
    final bool prepared = status != 'DRAFT' && status != 'CANCELLED';
    final bool released = <String>{
      'RELEASED',
      'IN_TRANSIT',
      'RECEIVED',
    }.contains(status);
    final bool inTransit = <String>{'IN_TRANSIT', 'RECEIVED'}.contains(status);
    final List<(String, bool)> steps = <(String, bool)>[
      ('Prepared', prepared),
      ('Accepted', transfer.driverAccepted),
      ('Released', released),
      ('In transit', inTransit),
      ('Received', transfer.isReceived),
    ];

    return Semantics(
      label:
          'Transfer progress: ${steps.map((step) => '${step.$1} ${step.$2 ? 'complete' : 'pending'}').join(', ')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'TRANSFER PROGRESS',
            style: TextStyle(
              color: AppTheme.resolve(context, _muted),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: <Widget>[
              for (int i = 0; i < steps.length; i++) ...<Widget>[
                _progressNode(steps[i].$2),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: AppTheme.resolve(
                        context,
                        steps[i].$2 && steps[i + 1].$2
                            ? const Color(0xFF398357)
                            : const Color(0xFFD9D0C7),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final (String label, bool done) in steps)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        color: AppTheme.resolve(context, done ? _text : _muted),
                        fontSize: 9,
                        height: 1.15,
                        fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressNode(bool done) {
    final Color color = AppTheme.resolve(
      context,
      done ? const Color(0xFF398357) : const Color(0xFFB9ADA2),
    );
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done
            ? AppTheme.resolve(context, const Color(0xFF398357), fill: true)
            : AppTheme.resolve(context, _surface, fill: true),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(
        done ? Icons.check_rounded : Icons.circle,
        size: done ? 12 : 5,
        color: done ? Colors.white : color,
      ),
    );
  }

  Future<void> _accept(RiderInterHubTransferData transfer) async {
    final RiderTransferAccept? action = widget.onAccept;
    if (action == null || transfer.id <= 0) return;
    await _perform(
      transfer,
      () => action(transfer.id),
      'Transfer manifest accepted.',
    );
  }

  Future<void> _decline(RiderInterHubTransferData transfer) async {
    final RiderTransferDecline? action = widget.onDecline;
    if (action == null || transfer.id <= 0) return;
    final String? reason = await _askDeclineReason();
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    await _perform(
      transfer,
      () => action(transfer.id, reason.trim()),
      'Manifest declined and returned to Logistics.',
    );
  }

  Future<void> _start(RiderInterHubTransferData transfer) async {
    final RiderTransferStart? action = widget.onStart;
    if (action == null ||
        transfer.id <= 0 ||
        _busyManifestIds.contains(transfer.id)) {
      return;
    }
    setState(() => _busyManifestIds.add(transfer.id));
    try {
      final latest = await widget.onLoadTransfer?.call(transfer.id) ?? transfer;
      if (!mounted) return;
      if (!latest.canStart) {
        await widget.onRefresh?.call();
        if (mounted) {
          _showMessage(
            'This manifest is not ready to start. Refresh for its latest status.',
            isError: true,
          );
        }
        return;
      }
      await _perform(
        latest,
        () => action(latest.id),
        'Transport started. The destination hub can now receive the parcels.',
      );
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busyManifestIds.remove(transfer.id));
    }
  }

  Future<void> _perform(
    RiderInterHubTransferData transfer,
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _busyManifestIds.add(transfer.id));
    try {
      await action();
      await widget.onRefresh?.call();
      if (mounted) _showMessage(successMessage);
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busyManifestIds.remove(transfer.id));
    }
  }

  Future<String?> _askDeclineReason() {
    String enteredReason = '';
    String? formError;
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return AlertDialog(
            title: const Text('Decline transfer'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Give Logistics a reason for declining this manifest.',
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) => enteredReason = value,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (formError != null)
                  Text(formError!, style: const TextStyle(color: Colors.red)),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (enteredReason.trim().isEmpty) {
                    setDialogState(() => formError = 'Enter a decline reason.');
                    return;
                  }
                  Navigator.pop(dialogContext, enteredReason.trim());
                },
                child: const Text('Decline manifest'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? AppTheme.resolve(context, const Color(0xFF8A3E34), fill: true)
              : AppTheme.resolve(context, _maroon, fill: true),
        ),
      );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _surface, fill: true),
        border: Border.all(color: AppTheme.resolve(context, _border)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.swap_horiz_rounded,
            size: 34,
            color: AppTheme.resolve(context, _muted),
          ),
          SizedBox(height: 12),
          Text(
            'No inter-hub transfers assigned',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.resolve(context, _text),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Assigned manifests will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.resolve(context, _muted),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferNote extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TransferNote({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          icon,
          size: 17,
          color: AppTheme.resolve(context, const Color(0xFF237A44)),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppTheme.resolve(context, Color(0xFF60473E)),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
