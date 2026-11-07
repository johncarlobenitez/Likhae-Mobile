import 'package:likhae/core/theme/app_theme.dart';

import 'package:flutter/material.dart';

import '../../core/theme/shop_colors.dart';
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
  static const Color _ink = ShopColors.text;
  static const Color _brand = ShopColors.accent;
  static const Color _canvas = ShopColors.canvas;
  static const Color _surface = ShopColors.surface;
  static const Color _soft = ShopColors.soft;
  static const Color _border = ShopColors.border;
  static const Color _muted = ShopColors.muted;
  static const Color _faint = ShopColors.faint;
  static const Color _success = AppTheme.lightSuccess;
  static const Color _danger = AppTheme.lightDanger;
  static const Color _dangerSoft = Color(0xFFFFF1F0);

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
                  ? '${parcel.trackingNumber} synced to Laravel as ${parcel.status}.'
                  : '${parcel.trackingNumber} was saved to Laravel as ${parcel.status}, but the dashboard could not refresh.',
            ),
            backgroundColor: AppTheme.resolve(context, _success, fill: true),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not receive parcel: $error'),
            backgroundColor: AppTheme.resolve(context, _danger, fill: true),
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
    return scans
        .where((LogisticsScanActivity scan) {
          final String key = '${scan.trackingNumber}:${scan.scannedAt}';
          return seen.add(key);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final String greetingName = widget.staffName.trim();
    final List<LogisticsScanActivity> scans = _visibleScans;
    return Scaffold(
      backgroundColor: AppTheme.resolve(context, _canvas, fill: true),
      appBar: AppBar(
        backgroundColor: AppTheme.resolve(context, _canvas, fill: true),
        foregroundColor: AppTheme.resolve(context, _ink),
        elevation: 0,
        title: const Text(
          'Logistics Dashboard',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: _loadingDashboard ? null : () => _loadDashboard(),
            icon: _loadingDashboard && _dashboard != null
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
          color: AppTheme.resolve(context, _brand),
          onRefresh: () async {
            await _loadDashboard();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: <Widget>[
              Text(
                greetingName.isEmpty
                    ? 'Parcel operations'
                    : 'Hello, $greetingName',
                style: TextStyle(
                  color: AppTheme.resolve(context, _ink),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _dashboard?.centerName.isNotEmpty == true
                    ? _dashboard!.centerName
                    : 'Receive parcels at your logistics center using the phone camera or manual entry.',
                style: TextStyle(
                  color: AppTheme.resolve(context, _muted),
                  height: 1.5,
                ),
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
                  Expanded(
                    child: Text(
                      'Recent parcel activity',
                      style: TextStyle(
                        color: AppTheme.resolve(context, _ink),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    _dashboard == null && _loadingDashboard
                        ? 'Loading'
                        : '${scans.length}',
                    style: TextStyle(
                      color: AppTheme.resolve(context, _brand),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_loadingDashboard && _dashboard == null)
                _loadingActivity()
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
        color: AppTheme.resolve(context, _dangerSoft, fill: true),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.cloud_off_rounded,
            color: AppTheme.resolve(context, _danger),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppTheme.resolve(context, _danger),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final LogisticsDashboardSnapshot? dashboard = _dashboard;
    final bool loading = dashboard == null && _loadingDashboard;
    final bool unavailable = dashboard == null && _dashboardError != null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _surface, fill: true),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.resolve(context, _border)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.resolve(context, _soft, fill: true),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: AppTheme.resolve(context, _brand),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  loading
                      ? 'Loading hub totals'
                      : unavailable
                      ? 'Hub totals unavailable'
                      : '${dashboard!.shipmentsInCenter} parcels in center',
                  style: TextStyle(
                    color: AppTheme.resolve(context, _ink),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loading
                      ? 'Syncing your logistics center'
                      : unavailable
                      ? 'Pull down or tap refresh to try again.'
                      : '${dashboard!.scansToday} parcel updates recorded today',
                  style: TextStyle(
                    color: AppTheme.resolve(context, _muted),
                    height: 1.35,
                  ),
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
        color: AppTheme.resolve(context, _brand, fill: true),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.qr_code_scanner_rounded,
            color: Colors.white,
            size: 30,
          ),
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
          Text(
            'Use the camera when a handheld barcode scanner is unavailable. You can also enter the tracking number manually.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _working ? null : _scanAndReceive,
              icon: _working
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.resolve(context, _brand),
                      ),
                    )
                  : const Icon(Icons.center_focus_strong_rounded),
              label: Text(_working ? 'Receiving parcel...' : 'Scan parcel'),
              style: FilledButton.styleFrom(
                foregroundColor: AppTheme.resolve(context, _brand),
                backgroundColor: AppTheme.resolve(
                  context,
                  _surface,
                  fill: true,
                ),
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
    final bool unavailable = _dashboardError != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _surface, fill: true),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.resolve(context, _border)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.resolve(
                context,
                unavailable ? _dangerSoft : _soft,
                fill: true,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              unavailable ? Icons.cloud_off_rounded : Icons.history_rounded,
              color: AppTheme.resolve(context, unavailable ? _danger : _brand),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  unavailable ? 'Activity unavailable' : 'No activity yet',
                  style: TextStyle(
                    color: AppTheme.resolve(context, _ink),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unavailable
                      ? 'Refresh the dashboard when your connection is available.'
                      : 'Parcel updates from your account will appear here.',
                  style: TextStyle(
                    color: AppTheme.resolve(context, _muted),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingActivity() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _surface, fill: true),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.resolve(context, _border)),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Loading recent parcel activity…',
              style: TextStyle(
                color: AppTheme.resolve(context, _muted),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityRow(LogisticsScanActivity activity) {
    final DateTime? scannedAt = DateTime.tryParse(
      activity.scannedAt,
    )?.toLocal();
    final String time = scannedAt == null
        ? ''
        : '${scannedAt.year}-${scannedAt.month.toString().padLeft(2, '0')}-${scannedAt.day.toString().padLeft(2, '0')}  ${scannedAt.hour.toString().padLeft(2, '0')}:${scannedAt.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _surface, fill: true),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.resolve(context, _border)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.check_circle_rounded,
            color: AppTheme.resolve(context, _success),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  activity.trackingNumber,
                  style: TextStyle(
                    color: AppTheme.resolve(context, _ink),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  activity.status.replaceAll('_', ' ').toLowerCase(),
                  style: TextStyle(color: AppTheme.resolve(context, _muted)),
                ),
                if (time.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    time,
                    style: TextStyle(
                      color: AppTheme.resolve(context, _faint),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.resolve(context, _faint),
          ),
        ],
      ),
    );
  }
}
