class AuthUserModel {
  AuthUserModel({
    required this.id,
    required this.name,
    this.email,
    this.contactNumber,
    this.status,
    this.emailVerified,
    this.roles = const <String>[],
    this.mobileRoles = const <String>[],
  });

  final int id;
  final String name;
  final String? email;
  final String? contactNumber;
  final String? status;
  final bool? emailVerified;
  final List<String> roles;
  final List<String> mobileRoles;

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawRoles = json['roles'] ?? json['mobile_roles'] ?? <dynamic>[];
    final dynamic rawMobileRoles = json['mobile_roles'] ?? <dynamic>[];

    return AuthUserModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? json['first_name'] ?? 'User').toString(),
      email: json['email']?.toString(),
      contactNumber: json['contact_number']?.toString(),
      status: json['status']?.toString(),
      emailVerified: json['email_verified'] == true,
      roles: (rawRoles is Iterable)
          ? rawRoles.map((dynamic item) => item.toString()).toList(growable: false)
          : const <String>[],
      mobileRoles: (rawMobileRoles is Iterable)
          ? rawMobileRoles.map((dynamic item) => item.toString()).toList(growable: false)
          : const <String>[],
    );
  }
}
