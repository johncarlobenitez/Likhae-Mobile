import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProductSearchRecord {
  final String query;
  final int? productId;

  const ProductSearchRecord({required this.query, this.productId});

  factory ProductSearchRecord.fromJson(dynamic value) {
    if (value is String) {
      return ProductSearchRecord(query: value);
    }
    if (value is! Map) {
      return const ProductSearchRecord(query: '');
    }

    final String query = value['query']?.toString().trim() ?? '';
    final int? productId = int.tryParse(value['productId']?.toString() ?? '');
    return ProductSearchRecord(query: query, productId: productId);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'query': query,
    if (productId != null) 'productId': productId,
  };
}

class ProductSearchHistoryService {
  ProductSearchHistoryService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _storageKey = 'likhae_buyer_product_search_history';
  static const int _maximumRecords = 8;

  static List<ProductSearchRecord> _records = <ProductSearchRecord>[];
  static bool _loaded = false;
  static Future<void>? _pendingRead;
  static Future<void> _writes = Future<void>.value();

  static Future<List<ProductSearchRecord>> read() async {
    if (_loaded) return List<ProductSearchRecord>.unmodifiable(_records);

    if (_pendingRead == null) {
      _pendingRead = () async {
        try {
          final String? value = await _storage.read(key: _storageKey);
          if (value != null && value.isNotEmpty) {
            final dynamic decoded = jsonDecode(value);
            if (decoded is List) {
              _records = decoded
                  .map(ProductSearchRecord.fromJson)
                  .where((ProductSearchRecord record) => record.query.isNotEmpty)
                  .take(_maximumRecords)
                  .toList(growable: false);
            }
          }
        } catch (_) {
          // Search history remains available for the current session if local
          // secure storage is unavailable on this platform.
        }
        _loaded = true;
      }();
    }
    await _pendingRead;

    return List<ProductSearchRecord>.unmodifiable(_records);
  }

  static Future<List<ProductSearchRecord>> record(
    String query, {
    int? productId,
  }) async {
    final String trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return read();

    await read();
    final String normalizedQuery = trimmedQuery.toLowerCase();
    ProductSearchRecord? existing;
    for (final ProductSearchRecord record in _records) {
      if (record.query.toLowerCase() == normalizedQuery) {
        existing = record;
        break;
      }
    }
    _records = <ProductSearchRecord>[
      ProductSearchRecord(
        query: trimmedQuery,
        productId: productId ?? existing?.productId,
      ),
      ..._records.where((ProductSearchRecord record) =>
          record.query.toLowerCase() != normalizedQuery),
    ].take(_maximumRecords).toList(growable: false);

    final String encoded = jsonEncode(
      _records.map((ProductSearchRecord record) => record.toJson()).toList(),
    );
    final Future<void> write = _writes
        .catchError((Object _) {})
        .then((_) => _storage.write(key: _storageKey, value: encoded))
        .catchError((Object _) {});
    _writes = write;
    await write;
    return List<ProductSearchRecord>.unmodifiable(_records);
  }

  static Future<List<ProductSearchRecord>> remove(String query) async {
    await read();
    final String normalizedQuery = query.trim().toLowerCase();
    _records = _records
        .where((ProductSearchRecord record) =>
            record.query.toLowerCase() != normalizedQuery)
        .toList(growable: false);
    await _persist();
    return List<ProductSearchRecord>.unmodifiable(_records);
  }

  static Future<void> clear() async {
    await read();
    _records = <ProductSearchRecord>[];
    await _persist();
  }

  static Future<void> _persist() async {
    final String encoded = jsonEncode(
      _records.map((ProductSearchRecord record) => record.toJson()).toList(),
    );
    final Future<void> write = _writes
        .catchError((Object _) {})
        .then((_) => _storage.write(key: _storageKey, value: encoded))
        .catchError((Object _) {});
    _writes = write;
    await write;
  }
}
