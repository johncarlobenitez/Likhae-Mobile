import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/workspace_mobile_service.dart';
import '../../shared/widgets/workflow_ui.dart';
import '../../shared/widgets/shop_ui.dart';
import 'attendance/rider_attendance_qr_image.dart';
import 'scanner/rider_scanner_screen.dart';

class RiderReturnsScreen extends StatelessWidget {
  const RiderReturnsScreen({super.key});
  @override
  Widget build(BuildContext context) => WorkflowList(
    title: 'Return parcels',
    endpoint: 'rider/returns',
    emptyMessage: 'No return parcels are assigned to you.',
    item: (context, row, reload) {
      final actions = (row['actions'] as List? ?? const []).cast<String>();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${row['tracking_number'] ?? 'Return parcel'} · ${_title(row['status'])}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text('Seller: ${row['seller'] ?? 'Seller unavailable'}'),
              if (row['seller_address'] != null)
                Text('Address: ${row['seller_address']}'),
              if (row['center'] != null) Text('Center: ${row['center']}'),
              if (row['reason'] != null) Text('Reason: ${row['reason']}'),
              Wrap(
                spacing: 8,
                children: [
                  for (final action in actions)
                    OutlinedButton(
                      onPressed: () async {
                        final endpoint = 'rider/returns/${row['id']}/$action';
                        final scan = action != 'accept';
                        final done = await showWorkflowForm(
                          context,
                          title: _title(action),
                          description:
                              'Record the verified parcel custody step.',
                          endpoint: endpoint,
                          fields: scan
                              ? const [
                                  WorkflowField(
                                    'scanned_code',
                                    'Scan tracking code',
                                    scan: true,
                                  ),
                                  WorkflowField(
                                    'notes',
                                    'Notes',
                                    required: false,
                                    multiline: true,
                                  ),
                                ]
                              : const [],
                        );
                        if (done) reload();
                      },
                      child: Text(_title(action)),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class RiderTripsScreen extends StatelessWidget {
  const RiderTripsScreen({super.key});
  @override
  Widget build(BuildContext context) => WorkflowList(
    title: 'Delivery trips',
    endpoint: 'rider/trips',
    emptyMessage: 'No delivery trips are assigned.',
    item: (context, row, reload) {
      final items = WorkspaceMobileService.maps(row['items']);
      final actions = (row['actions'] as List? ?? const []).cast<String>();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trip #${row['id']} · ${_title(row['status'])}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${items.length} parcels · Capacity ${row['capacity'] ?? '—'}',
              ),
              for (final parcel in items)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${parcel['tracking_number'] ?? 'Parcel'} · ${_title(parcel['status'])}',
                  ),
                  subtitle: Text(
                    '${parcel['recipient'] ?? ''}\n${parcel['address'] ?? ''}',
                  ),
                ),
              Wrap(
                spacing: 8,
                children: [
                  for (final action in actions)
                    OutlinedButton(
                      onPressed: () async {
                        final done = await showWorkflowForm(
                          context,
                          title: _title(action),
                          description:
                              'Apply this action to every eligible parcel on the trip.',
                          endpoint: 'rider/trips/${row['id']}/$action',
                          fields: action == 'reject'
                              ? const [
                                  WorkflowField(
                                    'reason',
                                    'Reason',
                                    multiline: true,
                                  ),
                                ]
                              : const [],
                        );
                        if (done) reload();
                      },
                      child: Text(_title(action)),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class RiderPayoutsScreen extends StatefulWidget {
  const RiderPayoutsScreen({super.key});
  @override
  State<RiderPayoutsScreen> createState() => _RiderPayoutsScreenState();
}

class _RiderPayoutsScreenState extends State<RiderPayoutsScreen> {
  late Future<Map<String, dynamic>> _future = WorkspaceMobileService.get(
    'rider/payouts',
  ).then((p) => Map<String, dynamic>.from(p['data'] as Map));
  final _selected = <String>{};
  bool _busy = false;
  String? _error;
  void _reload() => setState(
    () => _future = WorkspaceMobileService.get(
      'rider/payouts',
    ).then((p) => Map<String, dynamic>.from(p['data'] as Map)),
  );

  Future<void> _destination(Map<String, dynamic> destination) async {
    final done = await showWorkflowForm(
      context,
      title: 'Payout destination',
      description: 'Save the account where Logistics can send rider payouts.',
      endpoint: 'rider/wallet/payout-destination',
      method: 'PUT',
      fields: [
        WorkflowField(
          'payout_method',
          'Payment method',
          initial: '${destination['payout_method'] ?? ''}',
          choices: const {
            'GCash': 'GCash',
            'Maya': 'Maya',
            'Bank Transfer': 'Bank Transfer',
            'Other': 'Other',
          },
        ),
        WorkflowField(
          'payout_bank_name',
          'Bank name',
          required: false,
          initial: '${destination['payout_bank_name'] ?? ''}',
        ),
        WorkflowField(
          'payout_account_name',
          'Account name',
          initial: '${destination['payout_account_name'] ?? ''}',
        ),
        WorkflowField(
          'payout_account_number',
          'Account number',
          initial: '${destination['payout_account_number'] ?? ''}',
        ),
      ],
    );
    if (done) _reload();
  }

  Future<void> _request() async {
    if (_selected.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final form = FormData();
      for (final id in _selected) {
        form.fields.add(MapEntry('participant_ids[]', id));
      }
      await WorkspaceMobileService.send('rider/earnings/payout-requests', form);
      _selected.clear();
      _reload();
    } catch (e) {
      setState(() => _error = workflowError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Rider payouts'),
      actions: [
        IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: snapshot.hasError
                ? Text(workflowError(snapshot.error!))
                : const CircularProgressIndicator(),
          );
        }
        final data = snapshot.data!;
        final eligible = WorkspaceMobileService.maps(data['eligible']);
        final receipts = WorkspaceMobileService.maps(data['receipts']);
        final destination = data['destination'] is Map
            ? Map<String, dynamic>.from(data['destination'] as Map)
            : <String, dynamic>{};
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _future;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Payout destination'),
                  subtitle: Text(
                    destination['payout_method'] == null
                        ? 'No destination saved'
                        : '${destination['payout_method']} · ${destination['payout_account_name'] ?? ''}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _destination(destination),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Available shares',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (eligible.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No reconciled earnings are ready for payout.'),
                ),
              for (final row in eligible)
                Card(
                  child: CheckboxListTile(
                    value: _selected.contains('${row['id']}'),
                    onChanged: (value) => setState(
                      () => value == true
                          ? _selected.add('${row['id']}')
                          : _selected.remove('${row['id']}'),
                    ),
                    title: Text(formatPesoValue(row['amount'], fallback: formatPesoAmount(0))),
                    subtitle: Text(
                      '${row['tracking_number'] ?? 'Delivery'} · share #${row['id']}',
                    ),
                  ),
                ),
              if (eligible.isNotEmpty)
                FilledButton(
                  onPressed: _busy || _selected.isEmpty ? null : _request,
                  child: Text(
                    _busy ? 'Submitting…' : 'Request selected payout',
                  ),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 20),
              Text(
                'Payout receipts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (receipts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No payout receipts yet.'),
                ),
              for (final row in receipts)
                Card(
                  child: ListTile(
                    title: Text(
                      '${formatPesoValue(row['amount'], fallback: formatPesoAmount(0))} · ${_title(row['status'])}',
                    ),
                    subtitle: Text(
                      '${row['reference'] ?? ''} · ${row['paid_at'] ?? ''}',
                    ),
                    trailing: Wrap(
                      children: [
                        if (row['proof_available'] == true)
                          IconButton(
                            icon: const Icon(Icons.receipt_long),
                            onPressed: () => openWorkflowProof(
                              context,
                              'rider/earnings/payouts/${row['id']}/proof',
                            ),
                          ),
                        if (row['status'] == 'PAYOUT_PENDING_ACK')
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            onPressed: () async {
                              final done = await showWorkflowForm(
                                context,
                                title: 'Confirm payout',
                                description:
                                    'Confirm only the amount that reached your account.',
                                endpoint:
                                    'rider/earnings/payouts/${row['id']}/acknowledge',
                                fields: [
                                  WorkflowField(
                                    'amount_received',
                                    'Amount received (₱)',
                                    numeric: true,
                                    initial: '${row['amount'] ?? ''}',
                                  ),
                                  const WorkflowField(
                                    'notes',
                                    'Notes',
                                    required: false,
                                    multiline: true,
                                  ),
                                ],
                              );
                              if (done) _reload();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class RiderAttendanceScreen extends StatefulWidget {
  const RiderAttendanceScreen({super.key});
  @override
  State<RiderAttendanceScreen> createState() => _RiderAttendanceScreenState();
}

class _RiderAttendanceScreenState extends State<RiderAttendanceScreen> {
  late Future<List<Map<String, dynamic>>> _future = WorkspaceMobileService.rows(
    'rider/attendance',
  );
  Map<String, dynamic>? _qr;
  Map<String, dynamic>? _todayAttendance;
  String? _message, _error;
  bool _busy = false;
  bool _loadingQr = false;
  Timer? _qrExpiryTimer;
  int _qrSecondsRemaining = 0;

  @override
  void dispose() {
    _qrExpiryTimer?.cancel();
    super.dispose();
  }

  void _reload() =>
      setState(() => _future = WorkspaceMobileService.rows('rider/attendance'));

  void _startQrExpiry(int seconds) {
    _qrExpiryTimer?.cancel();
    setState(() => _qrSecondsRemaining = seconds);
    _qrExpiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
      } else if (_qrSecondsRemaining <= 1) {
        timer.cancel();
        _timeInOut();
      } else {
        setState(() => _qrSecondsRemaining--);
      }
    });
  }

  Future<void> _timeInOut() async {
    if (_loadingQr) return;
    _qrExpiryTimer?.cancel();
    setState(() {
      _loadingQr = true;
      _error = null;
    });
    try {
      final body = await WorkspaceMobileService.get('rider/attendance/qr');
      if (!mounted) return;
      setState(() {
        _qr = body;
        _todayAttendance = body['today_attendance'] is Map
            ? Map<String, dynamic>.from(body['today_attendance'] as Map)
            : null;
      });
      _startQrExpiry(int.tryParse('${body['expires_in_seconds'] ?? 20}') ?? 20);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = workflowError(e);
          _qr = null;
          _qrSecondsRemaining = 0;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingQr = false);
    }
  }

  Future<void> _scan() async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => RiderScannerScreen(
          returnScanDetails: true,
          showSignOut: false,
          attendanceMode: true,
          onLoadRiderQr: () =>
              WorkspaceMobileService.get('rider/attendance/qr'),
        ),
      ),
    );
    if (!mounted) return;
    if (result == null) return;
    final token = result is Map
        ? result['scanned_code']?.toString()
        : result.toString();
    if (token == null || token.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final body = await WorkspaceMobileService.send('rider/attendance/scan', {
        'token': token,
      });
      _qrExpiryTimer?.cancel();
      if (!mounted) return;
      setState(() => _message = body['message']?.toString());
      _reload();
    } catch (e) {
      if (mounted) setState(() => _error = workflowError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Inter-hub attendance')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 136),
        children: [
          const Text(
            'Record attendance either way: scan the Logistics QR, or display your rider QR for Logistics to scan.',
          ),
          const SizedBox(height: 12),
          if (snapshot.hasError) Text(workflowError(snapshot.error!)),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: _loadingQr ? null : _timeInOut,
                child: Text(_loadingQr ? 'Refreshing QR…' : 'Show my rider QR'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _scan,
                child: const Text('Scan Logistics QR'),
              ),
            ],
          ),
          if (_qr != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      '${_qr!['action'] == 'TIME_OUT' ? 'Time Out' : 'Time In'} QR',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Show this code to Logistics to record your ${_qr!['action'] == 'TIME_OUT' ? 'Time Out' : 'Time In'}.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _qr!['qr_data_uri'] is String
                          ? RiderAttendanceQrImage(
                              dataUri: '${_qr!['qr_data_uri']}',
                              size: 230,
                            )
                          : const SizedBox(
                              width: 230,
                              height: 230,
                              child: Center(
                                child: Text('QR code unavailable.'),
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Refreshes in $_qrSecondsRemaining ${_qrSecondsRemaining == 1 ? 'second' : 'seconds'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_todayAttendance != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Today's attendance · ${_todayAttendance!['status'] ?? 'UNKNOWN'}",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "${_todayAttendance!['hours'] ?? '0.00'}h / 8h · estimated ${formatPesoValue(_todayAttendance!['pay_estimate'], fallback: formatPesoAmount(0))}",
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                    TextButton(
                      onPressed: _loadingQr ? null : _timeInOut,
                      child: Text(_loadingQr ? 'Refreshing…' : 'Refresh QR'),
                    ),
                  ],
                ),
              ),
            ),
          if (_message != null)
            Text(_message!, style: const TextStyle(color: Colors.green)),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 18),
          Text('Shift history', style: Theme.of(context).textTheme.titleLarge),
          if (snapshot.connectionState != ConnectionState.done)
            const Center(child: CircularProgressIndicator()),
          if (snapshot.hasData && snapshot.data!.isEmpty)
            const Text('No attendance shifts found.'),
          for (final row in snapshot.data ?? const <Map<String, dynamic>>[])
            Card(
              child: ListTile(
                title: Text(
                  '${row['clock_in_at'] ?? ''} → ${row['clock_out_at'] ?? 'In progress'}',
                ),
                subtitle: Text(
                  '${row['worked_minutes'] ?? 0} minutes · ${formatPesoValue(row['gross_pay'], fallback: formatPesoAmount(0))}',
                ),
                trailing:
                    row['payroll'] is Map &&
                        (row['payroll'] as Map)['proof_available'] == true
                    ? IconButton(
                        icon: const Icon(Icons.receipt_long),
                        onPressed: () => openWorkflowProof(
                          context,
                          'rider/attendance/payroll-items/${(row['payroll'] as Map)['id']}/proof',
                        ),
                      )
                    : null,
              ),
            ),
        ],
      ),
    ),
  );
}

class RiderProfileUpdatesScreen extends StatelessWidget {
  const RiderProfileUpdatesScreen({super.key});
  @override
  Widget build(BuildContext context) => WorkflowList(
    title: 'Vehicle & document review',
    endpoint: 'rider/profile/updates',
    header: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton.icon(
        onPressed: () async {
          final done = await showWorkflowForm(
            context,
            title: 'Submit profile update',
            description:
                'Vehicle or licence changes are reviewed by Logistics. Upload the matching document when the detail changes.',
            endpoint: 'rider/profile/updates',
            uploads: const {
              'vehicle_or_cr': 'Vehicle OR/CR',
              'drivers_license': 'Driver licence',
            },
            fields: [
              const WorkflowField(
                'vehicle_type',
                'Vehicle type',
                choices: {
                  'motorcycle': 'Motorcycle',
                  'tricycle': 'Tricycle',
                  'car': 'Car',
                  'van': 'Van',
                  'closed_van': 'Closed van',
                  'truck': 'Truck',
                },
              ),
              const WorkflowField('plate_number', 'Plate number'),
              const WorkflowField(
                'drivers_license_number',
                'Driver licence number',
              ),
            ],
          );
          if (done && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Update submitted for review.')),
            );
          }
        },
        icon: const Icon(Icons.upload_file),
        label: const Text('Submit vehicle or document update'),
      ),
    ),
    emptyMessage: 'No profile updates have been submitted.',
    item: (context, row, reload) => Card(
      child: ListTile(
        title: Text(
          '${row['vehicle_type'] ?? ''} · ${row['plate_number'] ?? ''} · ${_title(row['status'])}',
        ),
        subtitle: Text(
          '${row['review_notes'] ?? 'Submitted ${row['submitted_at'] ?? ''}'}',
        ),
      ),
    ),
  );
}

String _title(dynamic raw) => (raw ?? '')
    .toString()
    .replaceAll('_', ' ')
    .replaceAll('-', ' ')
    .split(' ')
    .where((s) => s.isNotEmpty)
    .map((s) => '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}')
    .join(' ');
