import 'package:flutter/material.dart';

class RiderProfileData {
  final int id;

  final String name;

  final String email;

  final String contactNumber;

  final String birthday;

  final String sex;

  final String address;

  final String vehicleType;

  final String plateNumber;

  final String status;

  final String primaryRole;

  const RiderProfileData({
    required this.id,
    required this.name,
    required this.email,
    required this.contactNumber,
    required this.birthday,
    required this.sex,
    required this.address,
    required this.vehicleType,
    required this.plateNumber,
    required this.status,
    required this.primaryRole,
  });

  factory RiderProfileData.fromApi(
    Map<String, dynamic> json,
  ) {
    final Map<String, dynamic> user =
        json['user'] is Map
            ? Map<String, dynamic>.from(
                json['user'] as Map,
              )
            : json;

    final Map<String, dynamic> rider =
        json['rider'] is Map
            ? Map<String, dynamic>.from(
                json['rider'] as Map,
              )
            : json;

    return RiderProfileData(
      id: _toInt(
        user['id'] ??
            rider['user_id'] ??
            rider['id'],
      ),
      name: _valueOrFallback(
        user['name'] ??
            rider['name'],
        'Rider Account',
      ),
      email: _valueOrFallback(
        user['email'] ??
            rider['email'],
        'Not recorded',
      ),
      contactNumber: _valueOrFallback(
        user['phone'] ??
            user['contact_number'] ??
            rider['phone'] ??
            rider['contact_number'],
        'Not recorded',
      ),
      birthday: _formatBirthday(
        user['birthday'] ??
            rider['birthday'],
      ),
      sex: _valueOrFallback(
        user['sex'] ??
            rider['sex'],
        'Not recorded',
      ),
      address: _valueOrFallback(
        user['address'] ??
            rider['address'],
        'Not recorded',
      ),
      vehicleType: _valueOrFallback(
        rider['vehicle_type'] ??
            user['vehicle_type'],
        'Not recorded',
      ),
      plateNumber: _valueOrFallback(
        rider['plate_number'] ??
            user['plate_number'],
        'Not recorded',
      ),
      status: _headline(
        _valueOrFallback(
          rider['status'] ??
              user['status'],
          'active',
        ),
      ),
      primaryRole: _headline(
        _valueOrFallback(
          user['primary_role'] ??
              rider['primary_role'],
          'rider',
        ),
      ),
    );
  }

  String get riderId {
    return 'RID-${id.toString().padLeft(4, '0')}';
  }

  String get initials {
    final List<String> parts =
        name
            .trim()
            .split(
              RegExp(r'\s+'),
            )
            .where(
              (
                String part,
              ) =>
                  part.trim().isNotEmpty,
            )
            .take(2)
            .toList(
              growable: false,
            );

    if (parts.isEmpty) {
      return 'R';
    }

    final String value =
        parts
            .map(
              (
                String part,
              ) =>
                  part
                      .trim()
                      .substring(
                        0,
                        1,
                      )
                      .toUpperCase(),
            )
            .join();

    if (value.trim().isEmpty) {
      return 'R';
    }

    return value;
  }

  static int _toInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value
                  ?.toString()
                  .trim() ??
              '',
        ) ??
        0;
  }

  static String _valueOrFallback(
    dynamic value,
    String fallback,
  ) {
    if (value == null) {
      return fallback;
    }

    final String text =
        value.toString().trim();

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }

  static String _headline(
    String value,
  ) {
    final String clean =
        value
            .trim()
            .replaceAll(
              '_',
              ' ',
            )
            .replaceAll(
              '-',
              ' ',
            );

    if (clean.isEmpty) {
      return clean;
    }

    return clean
        .split(
          RegExp(r'\s+'),
        )
        .where(
          (
            String word,
          ) =>
              word.isNotEmpty,
        )
        .map(
          (
            String word,
          ) {
            if (word.length == 1) {
              return word.toUpperCase();
            }

            return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
          },
        )
        .join(' ');
  }

  static String _formatBirthday(
    dynamic value,
  ) {
    if (value == null) {
      return 'Not recorded';
    }

    final String raw =
        value.toString().trim();

    if (raw.isEmpty) {
      return 'Not recorded';
    }

    final DateTime? parsed =
        DateTime.tryParse(
      raw,
    );

    if (parsed == null) {
      return raw;
    }

    const List<String> months =
        <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final String month =
        months[parsed.month - 1];

    final String day =
        parsed.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$month $day, ${parsed.year}';
  }
}

typedef RiderProfileRefreshCallback =
    Future<void> Function();

typedef RiderLogoutCallback =
    Future<void> Function();

class RiderProfileScreen
    extends StatefulWidget {
  final RiderProfileData? profile;

  final RiderProfileRefreshCallback?
      onRefresh;

  final RiderLogoutCallback?
      onLogout;

  const RiderProfileScreen({
    super.key,
    this.profile,
    this.onRefresh,
    this.onLogout,
  });

  @override
  State<RiderProfileScreen>
      createState() =>
          _RiderProfileScreenState();
}

class _RiderProfileScreenState
    extends State<RiderProfileScreen> {
  static const Color _background =
      Color(0xFFFBF7F2);

  static const Color _surface =
      Color(0xFFFFFDF9);

  static const Color _border =
      Color(0xFFEADCCC);

  static const Color _maroon =
      Color(0xFF561C17);

  static const Color _maroonSoft =
      Color(0xFFF1E4D7);

  static const Color _text =
      Color(0xFF3B211B);

  static const Color _muted =
      Color(0xFF987865);

  static const Color _danger =
      Color(0xFFB42318);

  static const Color _dangerSoft =
      Color(0xFFFFF1F0);

  bool _loggingOut = false;

  Future<void> _refresh() async {
    final RiderProfileRefreshCallback?
        callback =
        widget.onRefresh;

    if (callback == null) {
      return;
    }

    await callback();
  }

  Future<void> _confirmLogout() async {
    if (_loggingOut) {
      return;
    }

    final RiderLogoutCallback?
        callback =
        widget.onLogout;

    if (callback == null) {
      _showMessage(
        'Sign out is not available right now.',
      );

      return;
    }

    final bool confirmed =
        await showDialog<bool>(
              context: context,
              builder:
                  (
                BuildContext context,
              ) {
                return AlertDialog(
                  backgroundColor:
                      _surface,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  title:
                      const Text(
                    'Sign out?',
                    style:
                        TextStyle(
                      color:
                          _text,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  content:
                      const Text(
                    'You will need to sign in again to access your rider account.',
                    style:
                        TextStyle(
                      color:
                          _muted,
                      height:
                          1.5,
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed:
                          () {
                        Navigator.of(
                          context,
                        ).pop(
                          false,
                        );
                      },
                      child:
                          const Text(
                        'Cancel',
                      ),
                    ),
                    FilledButton(
                      onPressed:
                          () {
                        Navigator.of(
                          context,
                        ).pop(
                          true,
                        );
                      },
                      style:
                          FilledButton
                              .styleFrom(
                        backgroundColor:
                            _danger,
                        foregroundColor:
                            Colors.white,
                      ),
                      child:
                          const Text(
                        'Sign Out',
                      ),
                    ),
                  ],
                );
              },
            ) ??
            false;

    if (!confirmed ||
        !mounted) {
      return;
    }

    setState(() {
      _loggingOut =
          true;
    });

    try {
      await callback();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to sign out: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut =
              false;
        });
      }
    }
  }

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(
          message,
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final RiderProfileData?
        profile =
        widget.profile;

    return Scaffold(
      backgroundColor:
          _background,
      appBar:
          AppBar(
        backgroundColor:
            _background,
        foregroundColor:
            _text,
        elevation:
            0,
        scrolledUnderElevation:
            0,
        title:
            const Text(
          'My Profile',
          style:
              TextStyle(
            color:
                _text,
            fontSize:
                19,
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
      body:
          SafeArea(
        top:
            false,
        child:
            RefreshIndicator(
          color:
              _maroon,
          onRefresh:
              _refresh,
          child:
              ListView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.fromLTRB(
              16,
              10,
              16,
              100,
            ),
            children: <Widget>[
              _buildHeading(),

              const SizedBox(
                height:
                    20,
              ),

              if (profile == null)
                _buildMissingProfile()
              else ...<Widget>[
                _buildProfileHeader(
                  profile,
                ),

                const SizedBox(
                  height:
                      14,
                ),

                _buildPersonalInformation(
                  profile,
                ),

                const SizedBox(
                  height:
                      14,
                ),

                _buildRiderInformation(
                  profile,
                ),

                const SizedBox(
                  height:
                      14,
                ),

                _buildAccountActions(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeading() {
    return const Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'ACCOUNT SETTINGS',
          style:
              TextStyle(
            color:
                _maroon,
            fontSize:
                10.5,
            letterSpacing:
                1.7,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        SizedBox(
          height:
              7,
        ),

        Text(
          'My Profile',
          style:
              TextStyle(
            color:
                _text,
            fontSize:
                30,
            height:
                1.08,
            letterSpacing:
                -0.6,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        SizedBox(
          height:
              8,
        ),

        Text(
          'Your profile is loaded from your authenticated rider account.',
          style:
              TextStyle(
            color:
                _muted,
            fontSize:
                12.5,
            height:
                1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMissingProfile() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            24,
        vertical:
            40,
      ),
      decoration:
          BoxDecoration(
        color:
            _surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color:
              _border,
        ),
      ),
      child:
          const Column(
        children: <Widget>[
          Icon(
            Icons
                .person_off_outlined,
            color:
                _muted,
            size:
                46,
          ),

          SizedBox(
            height:
                13,
          ),

          Text(
            'Rider profile not available',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  _text,
              fontSize:
                  16,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          SizedBox(
            height:
                6,
          ),

          Text(
            'Load the authenticated rider account from Laravel to display the profile.',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  _muted,
              fontSize:
                  12.5,
              height:
                  1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
    RiderProfileData profile,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color:
            _surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color:
              _border,
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width:
                    88,
                height:
                    88,
                alignment:
                    Alignment.center,
                decoration:
                    const BoxDecoration(
                  color:
                      _maroonSoft,
                  shape:
                      BoxShape.circle,
                ),
                child:
                    Text(
                  profile.initials,
                  style:
                      const TextStyle(
                    color:
                        _maroon,
                    fontSize:
                        25,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(
                width:
                    15,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      profile.name,
                      style:
                          const TextStyle(
                        color:
                            _text,
                        fontSize:
                            20,
                        height:
                            1.2,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(
                      height:
                          5,
                    ),

                    Text(
                      'Rider ID: ${profile.riderId}',
                      style:
                          const TextStyle(
                        color:
                            _muted,
                        fontSize:
                            11.5,
                      ),
                    ),

                    const SizedBox(
                      height:
                          11,
                    ),

                    Wrap(
                      spacing:
                          7,
                      runSpacing:
                          7,
                      children: <Widget>[
                        _ProfileBadge(
                          label:
                              profile.status,
                          type:
                              _ProfileBadgeType.success,
                        ),

                        _ProfileBadge(
                          label:
                              profile.primaryRole,
                          type:
                              _ProfileBadgeType.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInformation(
    RiderProfileData profile,
  ) {
    final List<_ProfileInformation>
        details =
        <_ProfileInformation>[
      _ProfileInformation(
        label:
            'Full Name',
        value:
            profile.name,
        icon:
            Icons
                .person_outline_rounded,
      ),
      _ProfileInformation(
        label:
            'Email',
        value:
            profile.email,
        icon:
            Icons
                .email_outlined,
      ),
      _ProfileInformation(
        label:
            'Contact Number',
        value:
            profile.contactNumber,
        icon:
            Icons
                .phone_outlined,
      ),
      _ProfileInformation(
        label:
            'Birthday',
        value:
            profile.birthday,
        icon:
            Icons
                .cake_outlined,
      ),
      _ProfileInformation(
        label:
            'Sex',
        value:
            profile.sex,
        icon:
            Icons
                .person_2_outlined,
      ),
      _ProfileInformation(
        label:
            'Address',
        value:
            profile.address,
        icon:
            Icons
                .location_on_outlined,
      ),
    ];

    return _ProfileSection(
      title:
          'Personal Information',
      items:
          details,
    );
  }

  Widget _buildRiderInformation(
    RiderProfileData profile,
  ) {
    final List<_ProfileInformation>
        details =
        <_ProfileInformation>[
      _ProfileInformation(
        label:
            'Vehicle Type',
        value:
            profile.vehicleType,
        icon:
            Icons
                .two_wheeler_outlined,
      ),
      _ProfileInformation(
        label:
            'Plate Number',
        value:
            profile.plateNumber,
        icon:
            Icons
                .pin_outlined,
      ),
      _ProfileInformation(
        label:
            'Account Status',
        value:
            profile.status,
        icon:
            Icons
                .verified_user_outlined,
      ),
      _ProfileInformation(
        label:
            'Role',
        value:
            profile.primaryRole,
        icon:
            Icons
                .badge_outlined,
      ),
    ];

    return _ProfileSection(
      title:
          'Rider Information',
      items:
          details,
    );
  }

  Widget _buildAccountActions() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        17,
      ),
      decoration:
          BoxDecoration(
        color:
            _dangerSoft,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFF3C4C0,
          ),
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Account Actions',
            style:
                TextStyle(
              color:
                  _danger,
              fontSize:
                  16,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height:
                5,
          ),

          const Text(
            'Sign out from your rider account.',
            style:
                TextStyle(
              color:
                  Color(
                0xFFB85B54,
              ),
              fontSize:
                  12,
              height:
                  1.45,
            ),
          ),

          const SizedBox(
            height:
                15,
          ),

          SizedBox(
            width:
                double.infinity,
            height:
                49,
            child:
                OutlinedButton.icon(
              onPressed:
                  _loggingOut
                      ? null
                      : _confirmLogout,
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    _danger,
                disabledForegroundColor:
                    _muted,
                backgroundColor:
                    _surface,
                side:
                    const BorderSide(
                  color:
                      _danger,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
              ),
              icon:
                  _loggingOut
                      ? const SizedBox(
                          width:
                              18,
                          height:
                              18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                            color:
                                _danger,
                          ),
                        )
                      : const Icon(
                          Icons
                              .logout_rounded,
                        ),
              label:
                  Text(
                _loggingOut
                    ? 'Signing Out...'
                    : 'Sign Out',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ProfileBadgeType {
  primary,
  success,
}

class _ProfileBadge
    extends StatelessWidget {
  final String label;

  final _ProfileBadgeType type;

  const _ProfileBadge({
    required this.label,
    required this.type,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool success =
        type ==
            _ProfileBadgeType.success;

    final Color background =
        success
            ? const Color(
                0xFFEAF6EE,
              )
            : const Color(
                0xFFF1E4D7,
              );

    final Color foreground =
        success
            ? const Color(
                0xFF237A44,
              )
            : const Color(
                0xFF561C17,
              );

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            10,
        vertical:
            6,
      ),
      decoration:
          BoxDecoration(
        color:
            background,
        borderRadius:
            BorderRadius.circular(
          100,
        ),
      ),
      child:
          Text(
        label,
        style:
            TextStyle(
          color:
              foreground,
          fontSize:
              10.5,
          fontWeight:
              FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProfileInformation {
  final String label;

  final String value;

  final IconData icon;

  const _ProfileInformation({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _ProfileSection
    extends StatelessWidget {
  final String title;

  final List<_ProfileInformation>
      items;

  const _ProfileSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        17,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFFFFDF9,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFEADCCC,
          ),
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style:
                const TextStyle(
              color:
                  Color(
                0xFF3B211B,
              ),
              fontSize:
                  16,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height:
                15,
          ),

          LayoutBuilder(
            builder:
                (
              BuildContext context,
              BoxConstraints
                  constraints,
            ) {
              final bool
                  useColumns =
                  constraints
                          .maxWidth >=
                      560;

              if (!useColumns) {
                return Column(
                  children:
                      List<Widget>.generate(
                    items.length,
                    (
                      int index,
                    ) {
                      return Padding(
                        padding:
                            EdgeInsets.only(
                          bottom:
                              index ==
                                      items.length -
                                          1
                                  ? 0
                                  : 10,
                        ),
                        child:
                            _ProfileInformationCard(
                          information:
                              items[index],
                        ),
                      );
                    },
                  ),
                );
              }

              const double gap =
                  10;

              final double cardWidth =
                  (constraints
                              .maxWidth -
                          gap) /
                      2;

              return Wrap(
                spacing:
                    gap,
                runSpacing:
                    gap,
                children:
                    items
                        .map(
                          (
                            _ProfileInformation
                                item,
                          ) =>
                              SizedBox(
                            width:
                                cardWidth,
                            child:
                                _ProfileInformationCard(
                              information:
                                  item,
                            ),
                          ),
                        )
                        .toList(
                          growable:
                              false,
                        ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileInformationCard
    extends StatelessWidget {
  final _ProfileInformation
      information;

  const _ProfileInformationCard({
    required this.information,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFF6EFE7,
        ),
        borderRadius:
            BorderRadius.circular(
          13,
        ),
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width:
                38,
            height:
                38,
            alignment:
                Alignment.center,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFFFFDF9,
              ),
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            child:
                Icon(
              information.icon,
              color:
                  const Color(
                0xFF561C17,
              ),
              size:
                  19,
            ),
          ),

          const SizedBox(
            width:
                10,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  information.label
                      .toUpperCase(),
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF987865,
                    ),
                    fontSize:
                        9.5,
                    letterSpacing:
                        0.5,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height:
                      5,
                ),

                Text(
                  information.value,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF3B211B,
                    ),
                    fontSize:
                        12.5,
                    height:
                        1.45,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
