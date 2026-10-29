import 'package:flutter/material.dart';

import '../../services/logistics_mobile_service.dart';

typedef OpenLogisticsScanner = Future<Map<String, String>?> Function();
typedef LogisticsSignOut = Future<void> Function();

class LogisticsDashboardScreen extends StatefulWidget {
  final String staffName;
  final OpenLogisticsScanner onOpenScanner;
  final LogisticsSignOut onSignOut;

  const LogisticsDashboardScreen({
    super.key,
    this.staffName = '',
    required this.onOpenScanner,
    required this.onSignOut,
  });

  @override
  State<LogisticsDashboardScreen> createState() =>
      _LogisticsDashboardScreenState();
}

class _LogisticsDashboardScreenState extends State<LogisticsDashboardScreen> {
  static const Color _ink = Color(0xFF253A36);
  static const Color _green = Color(0xFF176B58);
  static const Color _canvas = Color(0xFFF5F8F6);

  final List<LogisticsScanActivity> _recentScansAfterRefreshFailure =
      <LogisticsScanActivity>[];
  LogisticsDashboardSnapshot? _dashboard;
  String? _dashboardError;
  bool _loadingDashboard = true;
  bool _working = false;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<bool> _loadDashboard({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loadingDashboard = true;
        _dashboardError = null;
      });
    }

    try {
      final LogisticsDashboardSnapshot dashboard =
          await LogisticsMobileService.fetchDashboard();
      if (!mounted) return false;
      setState(() {
        _dashboard = dashboard;
        _dashboardError = null;
        _recentScansAfterRefreshFailure.clear();
        _loadingDashboard = false;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _dashboardError = error.toString().replaceFirst('Exception: ', '');
        _loadingDashboard = false;
      });
      return false;
    }
  }

  Future<void> _scanAndReceive() async {
    if (_working) return;
    final Map<String, String>? scanResult = await widget.onOpenScanner();
    final String trackingNumber = scanResult?['scanned_code']?.trim() ?? '';
    if (!mounted || trackingNumber.isEmpty) {
      return;
    }

    setState(() => _working = true);
    try {
      final LogisticsReceivedParcel parcel =
          await LogisticsMobileService.receiveScannedParcel(
            trackingNumber,
            scanMethod: scanResult?['scan_method'] ?? 'MANUAL',
          );
      final bool refreshed = await _loadDashboard(showLoading: false);
      if (!mounted) return;

      if (!refreshed) {
        setState(() {
          _recentScansAfterRefreshFailure.insert(
            0,
            LogisticsScanActivity(
              trackingNumber: parcel.trackingNumber,
              status: parcel.status,
              scannedAt: DateTime.now().toIso8601String(),
            ),
          );
        });
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              refreshed
                  ? '${parcel.trackingNumber} marked as received.'
                  : '${parcel.trackingNumber} was saved. Dashboard refresh failed.',
            ),
            backgroundColor: _green,
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not receive parcel: $error'),
            backgroundColor: const Color(0xFFB42318),
          ),
        );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  List<LogisticsScanActivity> get _visibleScans {
    final List<LogisticsScanActivity> scans = <LogisticsScanActivity>[
      ..._recentScansAfterRefreshFailure,
      ...?_dashboard?.recentScans,
    ];
    final Set<String> seen = <String>{};
    return scans.where((LogisticsScanActivity scan) {
      final String key = '${scan.trackingNumber}:${scan.scannedAt}';
      return seen.add(key);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final String greetingName = widget.staffName.trim();
    final List<LogisticsScanActivity> scans = _visibleScans;
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: _canvas,
        foregroundColor: _ink,
        elevation: 0,
        title: const Text(
          'Logistics Dashboard',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: _loadingDashboard ? null : () => _loadDashboard(),
            icon: _loadingDashboard
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signingOut ? null : _signOut,
            icon: _signingOut
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: _green,
          onRefresh: () async {
            await _loadDashboard();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: <Widget>[
              Text(
                greetingName.isEmpty ? 'Parcel operations' : 'Hello, $greetingName',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _dashboard?.centerName.isNotEmpty == true
                    ? _dashboard!.centerName
                    : 'Receive parcels at your logistics center using the phone camera or manual entry.',
                style: const TextStyle(color: Color(0xFF64736F), height: 1.5),
              ),
              if (_dashboardError != null) ...<Widget>[
                const SizedBox(height: 14),
                _errorCard(_dashboardError!),
              ],
              const SizedBox(height: 22),
              _summaryCard(),
              const SizedBox(height: 18),
              _scanCard(),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Recent parcel activity',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${scans.length}',
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_loadingDashboard && _dashboard == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (scans.isEmpty)
                _emptyActivity()
              else
                ...scans.map(_activityRow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFB42318)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF9C261D), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final LogisticsDashboardSnapshot? dashboard = _dashboard;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE6E1)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F3EF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: _green),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${dashboard?.shipmentsInCenter ?? 0} parcels in center',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${dashboard?.scansToday ?? 0} parcel updates recorded today',
                  style: const TextStyle(color: Color(0xFF64736F), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 30),
          const SizedBox(height: 15),
          const Text(
            'Phone parcel scanner',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use the camera when a handheld barcode scanner is unavailable. You can also enter the tracking number manually.',
            style: TextStyle(color: Color(0xFFE2F1EC), height: 1.45),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _working ? null : _scanAndReceive,
              icon: _working
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _green,
                      ),
                    )
                  : const Icon(Icons.center_focus_strong_rounded),
              label: Text(_working ? 'Receiving parcel...' : 'Scan parcel'),
              style: FilledButton.styleFrom(
                foregroundColor: _green,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyActivity() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6E1)),
      ),
      child: Text(
        _dashboardError == null
            ? 'Parcel updates recorded by your account will appear here.'
            : 'Connect to the logistics API to load center activity.',
        style: const TextStyle(color: Color(0xFF64736F), height: 1.4),
      ),
    );
  }

  Widget _activityRow(LogisticsScanActivity activity) {
    final DateTime? scannedAt = DateTime.tryParse(activity.scannedAt)?.toLocal();
    final String time = scannedAt == null
        ? ''
        : '${scannedAt.year}-${scannedAt.month.toString().padLeft(2, '0')}-${scannedAt.day.toString().padLeft(2, '0')}  ${scannedAt.hour.toString().padLeft(2, '0')}:${scannedAt.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE6E1)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_rounded, color: _green),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  activity.trackingNumber,
                  style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  activity.status.replaceAll('_', ' ').toLowerCase(),
                  style: const TextStyle(color: Color(0xFF64736F)),
                ),
                if (time.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    time,
                    style: const TextStyle(color: Color(0xFF87958F), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF87958F)),
        ],
      ),
    );
  }
}
