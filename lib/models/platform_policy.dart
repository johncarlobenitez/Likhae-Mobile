class PlatformPolicy {
  final int id;
  final String title;
  final String version;
  final String type;
  final String audience;
  final String? effectiveDate;
  final String body;

  const PlatformPolicy({
    required this.id,
    required this.title,
    required this.version,
    required this.type,
    required this.audience,
    required this.body,
    this.effectiveDate,
  });

  factory PlatformPolicy.fromJson(Map<String, dynamic> json) {
    return PlatformPolicy(
      id: int.tryParse((json['id'] ?? '').toString()) ?? 0,
      title: (json['title'] ?? 'Platform policy').toString(),
      version: (json['version'] ?? '').toString(),
      type: (json['policy_type'] ?? '').toString(),
      audience: (json['audience'] ?? '').toString(),
      effectiveDate: json['effective_date']?.toString(),
      body: (json['body'] ?? '').toString(),
    );
  }

  static List<PlatformPolicy> parseList(dynamic value) {
    if (value is! Iterable) return const <PlatformPolicy>[];

    return value
        .whereType<Map>()
        .map(
          (Map row) => PlatformPolicy.fromJson(Map<String, dynamic>.from(row)),
        )
        .where((PlatformPolicy policy) => policy.id > 0)
        .toList(growable: false);
  }
}
