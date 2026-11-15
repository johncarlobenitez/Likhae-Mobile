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

class LogisticsTransferItem {
  final int id;
  final String trackingNumber;
  final String status;
  final String transferLegStatus;
  final String parcelStatus;

  const LogisticsTransferItem({
    required this.id,
    required this.trackingNumber,
    required this.status,
    required this.transferLegStatus,
    required this.parcelStatus,
  });

  bool get canReceive => status.toUpperCase() == 'EXPECTED';
  bool get canRelease =>
      status.toUpperCase() == 'EXPECTED' &&
      transferLegStatus.toUpperCase() == 'READY';
  bool get isReleased => transferLegStatus.toUpperCase() == 'RELEASED';

  factory LogisticsTransferItem.fromApi(Map<String, dynamic> json) {
    return LogisticsTransferItem(
      id: int.tryParse('${json['id'] ?? ''}') ?? 0,
      trackingNumber: (json['tracking_number'] ?? '').toString(),
      status: (json['status'] ?? 'EXPECTED').toString().toUpperCase(),
      transferLegStatus: (json['transfer_leg_status'] ?? '').toString(),
      parcelStatus: (json['parcel_status'] ?? '').toString(),
    );
  }
}

class LogisticsTransfer {
  final int id;
  final String manifestNumber;
  final String status;
  final String originCenterName;
  final String destinationCenterName;
  final int totalCount;
  final int releasedCount;
  final int receivedCount;
  final int pendingCount;
  final List<LogisticsTransferItem> items;

  const LogisticsTransfer({
    required this.id,
    required this.manifestNumber,
    required this.status,
    required this.originCenterName,
    required this.destinationCenterName,
    required this.totalCount,
    required this.releasedCount,
    required this.receivedCount,
    required this.pendingCount,
    required this.items,
  });

  factory LogisticsTransfer.fromApi(Map<String, dynamic> json) {
    final dynamic rawItems = json['items'];
    final List<LogisticsTransferItem> items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (Map item) => LogisticsTransferItem.fromApi(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <LogisticsTransferItem>[];

    return LogisticsTransfer(
      id: int.tryParse('${json['id'] ?? ''}') ?? 0,
      manifestNumber: (json['manifest_number'] ?? '').toString(),
      status: (json['status'] ?? '').toString().toUpperCase(),
      originCenterName: (json['origin_center_name'] ?? 'Origin hub').toString(),
      destinationCenterName: (json['destination_center_name'] ?? '').toString(),
      totalCount: int.tryParse('${json['total_count'] ?? 0}') ?? items.length,
      releasedCount:
          int.tryParse('${json['released_count'] ?? 0}') ??
          items.where((LogisticsTransferItem item) => item.isReleased).length,
      receivedCount:
          int.tryParse('${json['received_count'] ?? 0}') ??
          items
              .where((LogisticsTransferItem item) => item.status == 'RECEIVED')
              .length,
      pendingCount:
          int.tryParse('${json['pending_count'] ?? 0}') ??
          items
              .where(
                (LogisticsTransferItem item) =>
                    item.canReceive || item.canRelease,
              )
              .length,
      items: items,
    );
  }
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
    if (!AppConfig.apiEnabled) {
      throw UnsupportedError(
        'Laravel sync is disabled. Rebuild the app with --dart-define=API_ENABLED=true.',
      );
    }

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

  static Future<List<LogisticsTransfer>> fetchIncomingTransfers() async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('logistics/incoming-transfers'),
      refresh: true,
    );
    final Map<String, dynamic> payload = _requirePayload(response);
    final dynamic rawData = payload['data'];
    if (rawData is! List) {
      throw const FormatException('Invalid incoming transfers response.');
    }

    return rawData
        .whereType<Map>()
        .map(
          (Map item) =>
              LogisticsTransfer.fromApi(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  static Future<List<LogisticsTransfer>> fetchOutgoingTransfers() async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('logistics/outgoing-transfers'),
      refresh: true,
    );
    final Map<String, dynamic> payload = _requirePayload(response);
    final dynamic rawData = payload['data'];
    if (rawData is! List) {
      throw const FormatException('Invalid outgoing transfers response.');
    }

    return rawData
        .whereType<Map>()
        .map(
          (Map item) =>
              LogisticsTransfer.fromApi(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  static Future<LogisticsTransfer> fetchIncomingTransfer(int manifestId) async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('logistics/incoming-transfers/$manifestId'),
      refresh: true,
    );
    final Map<String, dynamic> payload = _requirePayload(response);
    final dynamic rawData = payload['data'];
    if (rawData is! Map) {
      throw const FormatException('Invalid incoming transfer response.');
    }

    return LogisticsTransfer.fromApi(Map<String, dynamic>.from(rawData));
  }

  static Future<LogisticsTransfer> fetchOutgoingTransfer(int manifestId) async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('logistics/outgoing-transfers/$manifestId'),
      refresh: true,
    );
    final Map<String, dynamic> payload = _requirePayload(response);
    final dynamic rawData = payload['data'];
    if (rawData is! Map) {
      throw const FormatException('Invalid outgoing transfer response.');
    }

    return LogisticsTransfer.fromApi(Map<String, dynamic>.from(rawData));
  }

  static Future<LogisticsTransfer> releaseOutgoingTransferItem({
    required int manifestId,
    required int itemId,
    required String scannedCode,
    required String scanMethod,
  }) async {
    final String code = scannedCode.trim();
    if (code.isEmpty) {
      throw const FormatException('Scan or enter the parcel tracking number.');
    }

    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl(
        'logistics/outgoing-transfers/$manifestId/items/$itemId/release',
      ),
      <String, dynamic>{
        'scanned_code': code,
        'scan_method': scanMethod.toUpperCase(),
      },
    );
    final Map<String, dynamic> payload = _requirePayload(response);
    final dynamic rawData = payload['data'];
    if (rawData is! Map) {
      throw const FormatException('The server did not confirm parcel release.');
    }

    return LogisticsTransfer.fromApi(Map<String, dynamic>.from(rawData));
  }

  static Future<LogisticsTransfer> receiveTransferItem({
    required int manifestId,
    required int itemId,
    required String scannedCode,
    required String scanMethod,
  }) async {
    final String code = scannedCode.trim();
    if (code.isEmpty) {
      throw const FormatException('Scan or enter the parcel tracking number.');
    }

    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl(
        'logistics/incoming-transfers/$manifestId/items/$itemId/receive',
      ),
      <String, dynamic>{
        'scanned_code': code,
        'scan_method': scanMethod.toUpperCase(),
      },
    );
    final Map<String, dynamic> payload = _requirePayload(response);
    final dynamic rawData = payload['data'];
    if (rawData is! Map) {
      throw const FormatException(
        'The server did not confirm transfer receipt.',
      );
    }

    return LogisticsTransfer.fromApi(Map<String, dynamic>.from(rawData));
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
