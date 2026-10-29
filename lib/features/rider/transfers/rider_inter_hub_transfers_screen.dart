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
      'status_label',
      'status',
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
typedef RiderTransferStart =
    Future<void> Function(int manifestId, Map<int, String> scannedCodes);

class RiderInterHubTransfersScreen extends StatefulWidget {
  final List<RiderInterHubTransferData> transfers;
  final String? statusMessage;
  final Future<void> Function()? onRefresh;
  final RiderTransferAccept? onAccept;
  final RiderTransferDecline? onDecline;
  final RiderTransferStart? onStart;

  const RiderInterHubTransfersScreen({
    super.key,
    this.transfers = const <RiderInterHubTransferData>[],
    this.statusMessage,
    this.onRefresh,
    this.onAccept,
    this.onDecline,
    this.onStart,
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
      backgroundColor: _background,
      body: SafeArea(
        child: RefreshIndicator(
          color: _maroon,
          onRefresh: () async {
            await widget.onRefresh?.call();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 112),
            children: <Widget>[
              _brandHeader(),
              const SizedBox(height: 28),
              const Text(
                'Inter-hub transfers',
                style: TextStyle(
                  color: _text,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Review your assigned manifest, accept it before the origin hub '
                'releases the parcels, then scan every parcel to start the trip. '
                'The destination hub records receipt on arrival.',
                style: TextStyle(color: _muted, fontSize: 13, height: 1.55),
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
            color: _maroon,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.local_shipping_rounded, color: Colors.white),
        ),
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'LIKHAE RIDER',
              style: TextStyle(
                color: _text,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Inter-logistics workspace',
              style: TextStyle(color: _muted, fontSize: 11),
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
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFB42318),
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _transferCard(RiderInterHubTransferData transfer) {
    final String parcelCount = transfer.items.length.toString();
    final Color statusColor = transfer.isReceived
        ? const Color(0xFF237A44)
        : <String>{'CANCELLED', 'CANCELED'}.contains(transfer.displayStatus)
        ? const Color(0xFF8A3E34)
        : _muted;
    final bool busy = _busyManifestIds.contains(transfer.id);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(15),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '$transfer.originHub  →  $transfer.destinationHub',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$parcelCount parcels',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  transfer.displayStatus,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (transfer.driverAccepted) ...<Widget>[
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
                  'Released by the origin hub. Scan every parcel to start transport.',
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
                    style: FilledButton.styleFrom(backgroundColor: _maroon),
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
                    style: FilledButton.styleFrom(backgroundColor: _maroon),
                  ),
              ],
            ),
            if (busy) ...<Widget>[
              const SizedBox(height: 10),
              const LinearProgressIndicator(color: _maroon),
            ],
          ],
        ],
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
    if (action == null || transfer.id <= 0) return;
    final Map<int, String>? scannedCodes = await _askForParcelScans(transfer);
    if (scannedCodes == null || !mounted) return;
    await _perform(
      transfer,
      () => action(transfer.id, scannedCodes),
      'Transport started. The destination hub can now receive the parcels.',
    );
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
    final TextEditingController controller = TextEditingController();
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
                  controller: controller,
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
                  if (controller.text.trim().isEmpty) {
                    setDialogState(() => formError = 'Enter a decline reason.');
                    return;
                  }
                  Navigator.pop(dialogContext, controller.text.trim());
                },
                child: const Text('Decline manifest'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(controller.dispose);
  }

  Future<Map<int, String>?> _askForParcelScans(
    RiderInterHubTransferData transfer,
  ) async {
    final List<RiderInterHubTransferItem> items = transfer.items;
    if (items.isEmpty ||
        items.any((RiderInterHubTransferItem item) => item.id <= 0)) {
      _showMessage(
        'This manifest is missing parcel scan details. Refresh or contact Logistics.',
        isError: true,
      );
      return null;
    }

    final Map<int, TextEditingController> controllers =
        <int, TextEditingController>{
          for (final RiderInterHubTransferItem item in items)
            item.id: TextEditingController(),
        };
    String? formError;
    try {
      return await showDialog<Map<int, String>>(
        context: context,
        builder: (BuildContext dialogContext) => StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Scan manifest parcels'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Enter or scan the barcode from each parcel. Every code must match the sealed manifest.',
                      ),
                      const SizedBox(height: 12),
                      for (
                        int index = 0;
                        index < items.length;
                        index++
                      ) ...<Widget>[
                        TextField(
                          controller: controllers[items[index].id],
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: _parcelLabel(index + 1),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (formError != null)
                        Text(
                          formError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final bool hasMissingCode = controllers.values.any(
                      (TextEditingController controller) =>
                          controller.text.trim().isEmpty,
                    );
                    if (hasMissingCode) {
                      setDialogState(
                        () => formError = 'Scan every parcel before starting.',
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, <int, String>{
                      for (final MapEntry<int, TextEditingController> entry
                          in controllers.entries)
                        entry.key: entry.value.text.trim(),
                    });
                  },
                  child: const Text('Start transport'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      for (final TextEditingController controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  String _parcelLabel(int number) => 'Parcel $number barcode';

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFF8A3E34) : _maroon,
        ),
      );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: <Widget>[
          Icon(Icons.swap_horiz_rounded, size: 34, color: _muted),
          SizedBox(height: 12),
          Text(
            'No inter-hub transfers assigned',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Assigned manifests will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
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
        Icon(icon, size: 17, color: const Color(0xFF237A44)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF60473E),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
