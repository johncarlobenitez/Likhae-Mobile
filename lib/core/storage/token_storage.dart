import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'likhae_auth_token';

  static String? _token;
  static bool _loaded = false;
  static Future<String?>? _pendingRead;
  static Future<void> _writes = Future<void>.value();
  static int _revision = 0;

  static int get revision => _revision;

  static Future<String?> readToken() {
    if (_loaded) return Future<String?>.value(_token);
    if (_pendingRead != null) return _pendingRead!;
    final revision = _revision;
    late final Future<String?> pending;
    pending = _storage
        .read(key: _tokenKey)
        .then((value) {
          if (revision == _revision) {
            _token = value;
            _loaded = true;
          }
          return _token;
        })
        .whenComplete(() {
          if (identical(_pendingRead, pending)) _pendingRead = null;
        });
    return _pendingRead = pending;
  }

  static Future<void> writeToken(String token) {
    _revision++;
    _loaded = true;
    _token = token;
    return _enqueue(() => _storage.write(key: _tokenKey, value: token));
  }

  static Future<void> clearToken() {
    _revision++;
    _loaded = true;
    _token = null;
    return _enqueue(() => _storage.delete(key: _tokenKey));
  }

  static Future<void> _enqueue(Future<void> Function() write) {
    final next = _writes.catchError((Object _) {}).then((_) => write());
    _writes = next;
    return next;
  }
}
