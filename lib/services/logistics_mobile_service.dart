import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';

class LogisticsReceivedParcel {
  final String trackingNumber;
  final String status;

  const LogisticsReceivedParcel({
    required this.trackingNumber,
    required this.status,
  });
}

class LogisticsScanActivity {
  final String trackingNumber;
  final String status;
  final String scannedAt;

  const LogisticsScanActivity({
    required this.trackingNumber,
    required this.status,
    required this.scannedAt,
  });

  factory LogisticsScanActivity.fromApi(Map<String, dynamic> json) {
    return LogisticsScanActivity(
      trackingNumber: (json['tracking_number'] ?? '').toString(),
      status: (json['status'] ?? 'RECEIVED').toString(),
      scannedAt: (json['scanned_at'] ?? json['updated_at'] ?? '').toString(),
    );
  }
}

class LogisticsDashboardSnapshot {
  final String centerName;
  final int shipmentsInCenter;
  final int scansToday;
  final List<LogisticsScanActivity> recentScans;

  const LogisticsDashboardSnapshot({
    required this.centerName,
    required this.shipmentsInCenter,
    required this.scansToday,
    required this.recentScans,
  });
}

class LogisticsMobileService {
  LogisticsMobileService._();

  static Future<LogisticsDashboardSnapshot> fetchDashboard() async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('logistics/dashboard'),
      refresh: true,
    );
    final Map<String, dynamic> payload = _requirePayload(response);
    final dynamic rawData = payload['data'];
    if (rawData is! Map) {
      throw const FormatException('Invalid logistics dashboard response.');
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);
    final dynamic rawCenter = data['center'];
    final dynamic rawSummary = data['summary'];
    final dynamic rawScans = data['recent_scans'];
    final dynamic rawShipments = data['recent_shipments'];
    final Map<String, dynamic> center = rawCenter is Map
        ? Map<String, dynamic>.from(rawCenter)
        : const <String, dynamic>{};
    final Map<String, dynamic> summary = rawSummary is Map
        ? Map<String, dynamic>.from(rawSummary)
        : const <String, dynamic>{};
    final List<dynamic> activityRows = rawShipments is List
        ? rawShipments
        : rawScans is List
        ? rawScans
        : const <dynamic>[];
    final List<LogisticsScanActivity> scans = activityRows
        .whereType<Map>()
        .map(
          (Map row) =>
              LogisticsScanActivity.fromApi(Map<String, dynamic>.from(row)),
        )
        .where((LogisticsScanActivity row) => row.trackingNumber.isNotEmpty)
        .toList(growable: false);

    return LogisticsDashboardSnapshot(
      centerName: (center['name'] ?? '').toString(),
      shipmentsInCenter:
          int.tryParse((summary['shipments_in_center'] ?? 0).toString()) ?? 0,
      scansToday: int.tryParse((summary['scans_today'] ?? 0).toString()) ?? 0,
      recentScans: scans,
    );
  }

  static Future<LogisticsReceivedParcel> receiveScannedParcel(
    String rawTrackingNumber, {
    String scanMethod = 'MANUAL',
  }) async {
    final String trackingNumber = rawTrackingNumber.trim();
    if (trackingNumber.isEmpty) {
      throw const FormatException('Scan or enter a parcel tracking number.');
    }

    final Response<dynamic> receive = await ApiClient.post(
      AppConfig.resolveApiUrl('logistics/scan-receive'),
      <String, dynamic>{
        'scanned_code': trackingNumber,
        'scan_method': scanMethod.toUpperCase(),
      },
    );
    final Map<String, dynamic> receivePayload = _requirePayload(receive);
    final String savedTracking = (receivePayload['tracking_number'] ?? '')
        .toString()
        .trim();
    final String savedStatus = (receivePayload['current_status'] ?? '')
        .toString()
        .trim();
    if (savedTracking.isEmpty || savedStatus.isEmpty) {
      throw const FormatException(
        'The server did not confirm receipt of the parcel. Refresh logistics before scanning again.',
      );
    }

    return LogisticsReceivedParcel(
      trackingNumber: savedTracking,
      status: savedStatus,
    );
  }

  static Map<String, dynamic> _requirePayload(Response<dynamic> response) {
    final int statusCode = response.statusCode ?? 500;
    final dynamic body = response.data;
    if (statusCode < 200 || statusCode >= 300) {
      final String message = body is Map && body['message'] != null
          ? body['message'].toString()
          : 'Logistics request failed (HTTP $statusCode).';
      throw Exception(message);
    }
    if (body is! Map) {
      throw const FormatException('Invalid response from the logistics API.');
    }
    if (body['success'] == false) {
      throw Exception(
        body['message'] ?? 'The logistics request was not completed.',
      );
    }
    return Map<String, dynamic>.from(body);
  }
}
