import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RememberedLoginCredentials {
  final String email;
  final String password;

  const RememberedLoginCredentials({
    required this.email,
    required this.password,
  });
}

class RememberedLoginStorage {
  RememberedLoginStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _emailKey = 'likhae_remembered_login_email';
  static const String _passwordKey = 'likhae_remembered_login_password';

  static Future<RememberedLoginCredentials?> read() async {
    final String? email = await _storage.read(key: _emailKey);
    final String? password = await _storage.read(key: _passwordKey);

    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }

    return RememberedLoginCredentials(email: email, password: password);
  }

  static Future<void> save({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _passwordKey, value: password);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }
}
