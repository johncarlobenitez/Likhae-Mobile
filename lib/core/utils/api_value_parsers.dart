bool parseApiBool(dynamic value, {required bool defaultValue}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final String normalized = value?.toString().trim().toLowerCase() ?? '';
  if (<String>{'1', 'true', 'yes', 'on', 'active', 'available'}.contains(normalized)) {
    return true;
  }
  if (<String>{'0', 'false', 'no', 'off', 'inactive', 'unavailable'}.contains(normalized)) {
    return false;
  }
  return defaultValue;
}
