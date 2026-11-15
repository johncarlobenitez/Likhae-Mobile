import 'package:likhae/core/theme/app_theme.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:likhae/core/api/api_client.dart';

import '../../../shared/widgets/shop_ui.dart';
import '../../../shared/widgets/sized_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:likhae/shared/map/maplibre_compat.dart' as maplibre;
import 'package:likhae/services/philippine_address_geocoding.dart';

import '../../auth/register_screen.dart'
    show AddressLoader, AddressOption, ChildAddressLoader, PostalCodeLoader;

enum BuyerAccountTab {
  profile,
  accountSecurity,
  addresses,
  vouchers,
  followingStores,
  wallet,
  password,
  recentlyViewed,
  settings,
  dangerZone,
}

extension BuyerAccountTabInfo on BuyerAccountTab {
  String get label {
    switch (this) {
      case BuyerAccountTab.profile:
        return 'Profile';

      case BuyerAccountTab.accountSecurity:
        return 'Account & Security';

      case BuyerAccountTab.addresses:
        return 'Addresses';

      case BuyerAccountTab.vouchers:
        return 'Vouchers';

      case BuyerAccountTab.followingStores:
        return 'Following Stores';

      case BuyerAccountTab.wallet:
        return 'Wallet';

      case BuyerAccountTab.password:
        return 'Change Password';

      case BuyerAccountTab.settings:
        return 'System Settings';
      case BuyerAccountTab.recentlyViewed:
        return 'Recently Viewed';

      case BuyerAccountTab.dangerZone:
        return 'Danger Zone';
    }
  }

  String get description {
    switch (this) {
      case BuyerAccountTab.profile:
        return 'Personal information';

      case BuyerAccountTab.accountSecurity:
        return 'Edit your information and password';

      case BuyerAccountTab.addresses:
        return 'Delivery locations';

      case BuyerAccountTab.vouchers:
        return 'Discounts and deals';

      case BuyerAccountTab.followingStores:
        return 'Stores you follow';

      case BuyerAccountTab.wallet:
        return 'Refund destination';

      case BuyerAccountTab.password:
        return 'Account security';

      case BuyerAccountTab.settings:
        return 'App preferences';
      case BuyerAccountTab.recentlyViewed:
        return 'Products you viewed';

      case BuyerAccountTab.dangerZone:
        return 'Close account';
    }
  }

  IconData get icon {
    switch (this) {
      case BuyerAccountTab.profile:
        return Icons.person_outline_rounded;

      case BuyerAccountTab.accountSecurity:
        return Icons.lock_outline_rounded;

      case BuyerAccountTab.addresses:
        return Icons.location_on_outlined;

      case BuyerAccountTab.vouchers:
        return Icons.confirmation_number_outlined;

      case BuyerAccountTab.followingStores:
        return Icons.storefront_outlined;

      case BuyerAccountTab.wallet:
        return Icons.account_balance_wallet_outlined;

      case BuyerAccountTab.password:
        return Icons.lock_outline_rounded;

      case BuyerAccountTab.settings:
        return Icons.settings_outlined;
      case BuyerAccountTab.recentlyViewed:
        return Icons.visibility_outlined;

      case BuyerAccountTab.dangerZone:
        return Icons.warning_amber_rounded;
    }
  }
}

enum BuyerGender { male, female, other }

extension BuyerGenderInfo on BuyerGender {
  String get backendValue {
    switch (this) {
      case BuyerGender.male:
        return 'male';

      case BuyerGender.female:
        return 'female';

      case BuyerGender.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case BuyerGender.male:
        return 'Male';

      case BuyerGender.female:
        return 'Female';

      case BuyerGender.other:
        return 'Other';
    }
  }

  static BuyerGender? fromValue(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'male':
        return BuyerGender.male;

      case 'female':
        return BuyerGender.female;

      case 'other':
        return BuyerGender.other;

      default:
        return null;
    }
  }
}

class BuyerProfileData {
  final String name;
  final String email;

  final String phone;

  final String? middleInitial;
  final DateTime? birthday;
  final BuyerGender? gender;

  final String? profilePhotoUrl;

  const BuyerProfileData({
    required this.name,
    required this.email,
    this.phone = '',
    this.middleInitial,
    this.birthday,
    this.gender,
    this.profilePhotoUrl,
  });

  String get initial {
    final String cleanName = name.trim();

    if (cleanName.isEmpty) {
      return 'B';
    }

    return cleanName[0].toUpperCase();
  }
}

class BuyerAccountSnapshot {
  final BuyerProfileData profile;
  final List<BuyerAddressData> addresses;

  const BuyerAccountSnapshot({required this.profile, required this.addresses});
}

class BuyerRefundDestination {
  final String id;
  final String method;
  final String? bankName;
  final String accountName;
  final String accountType;
  final String accountNumber;
  final bool isDefault;

  const BuyerRefundDestination({
    required this.id,
    required this.method,
    required this.accountName,
    required this.accountType,
    required this.accountNumber,
    this.bankName,
    this.isDefault = false,
  });

  String get maskedNumber {
    final String compact = accountNumber.replaceAll(RegExp(r'\s+'), '');
    if (compact.length <= 4) return compact;
    return '•••• ${compact.substring(compact.length - 4)}';
  }
}

class BuyerRefundDestinationMutation {
  final String action;
  final String? destinationId;
  final String? method;
  final String? bankName;
  final String? accountName;
  final String? accountType;
  final String? accountNumber;
  final bool makeDefault;

  const BuyerRefundDestinationMutation({
    required this.action,
    this.destinationId,
    this.method,
    this.bankName,
    this.accountName,
    this.accountType,
    this.accountNumber,
    this.makeDefault = false,
  });
}

class SelectedProfilePhoto {
  final String fileName;

  /// Bytes selected by image_picker/file_picker.
  ///
  /// The picker stays outside this screen so this file has
  /// no plugin dependency.
  final Uint8List bytes;

  const SelectedProfilePhoto({required this.fileName, required this.bytes});

  int get sizeInBytes {
    return bytes.lengthInBytes;
  }

  double get sizeInMegabytes {
    return sizeInBytes / (1024 * 1024);
  }
}

class UpdateBuyerProfileRequest {
  final String name;
  final String email;

  /// Empty string can later be mapped to null by the API
  /// service because Laravel accepts a nullable phone.
  final String phone;

  final DateTime? birthday;
  final BuyerGender? gender;

  final SelectedProfilePhoto? profilePhoto;

  final String? mobileChangeCode;

  const UpdateBuyerProfileRequest({
    required this.name,
    required this.email,
    required this.phone,
    required this.birthday,
    required this.gender,
    this.profilePhoto,
    this.mobileChangeCode,
  });
}

class BuyerProfileVerificationRequiredException implements Exception {
  final String target;
  final String message;

  const BuyerProfileVerificationRequiredException({
    required this.target,
    required this.message,
  });
}

class BuyerAddressData {
  final String id;

  final String label;
  final String recipientName;
  final String contactNumber;

  final String? houseNumber;
  final String? street;
  final String? barangay;
  final String? municipality;
  final String? province;
  final String? region;
  final String? regionCode;
  final String? provinceCode;
  final String? municipalityCode;
  final String? barangayCode;
  final String? postalCode;
  final String? landmark;
  final double? latitude;
  final double? longitude;

  final bool isDefault;

  /// Use this when Laravel returns the exact formatted()
  /// address string.
  final String? formattedAddress;

  const BuyerAddressData({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.contactNumber,
    this.houseNumber,
    this.street,
    this.barangay,
    this.municipality,
    this.province,
    this.region,
    this.regionCode,
    this.provinceCode,
    this.municipalityCode,
    this.barangayCode,
    this.postalCode,
    this.landmark,
    this.latitude,
    this.longitude,
    this.isDefault = false,
    this.formattedAddress,
  });

  String get displayAddress {
    final String? serverFormatted = formattedAddress?.trim();

    if (serverFormatted != null && serverFormatted.isNotEmpty) {
      return serverFormatted;
    }

    return <String?>[
          houseNumber,
          street,
          barangay,
          municipality,
          province,
          postalCode,
          region,
        ]
        .whereType<String>()
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .join(', ');
  }

  BuyerAddressData copyWith({bool? isDefault}) {
    return BuyerAddressData(
      id: id,
      label: label,
      recipientName: recipientName,
      contactNumber: contactNumber,
      houseNumber: houseNumber,
      street: street,
      barangay: barangay,
      municipality: municipality,
      province: province,
      region: region,
      regionCode: regionCode,
      provinceCode: provinceCode,
      municipalityCode: municipalityCode,
      barangayCode: barangayCode,
      postalCode: postalCode,
      landmark: landmark,
      latitude: latitude,
      longitude: longitude,
      isDefault: isDefault ?? this.isDefault,
      formattedAddress: formattedAddress,
    );
  }
}

class CreateBuyerAddressRequest {
  final String label;
  final String recipientName;
  final String contactNumber;

  final String houseNumber;
  final String street;
  final String barangay;
  final String municipality;
  final String province;
  final String region;
  final String? regionCode;
  final String? provinceCode;
  final String? municipalityCode;
  final String? barangayCode;
  final String postalCode;
  final String landmark;
  final double? latitude;
  final double? longitude;

  final bool isDefault;

  const CreateBuyerAddressRequest({
    required this.label,
    required this.recipientName,
    required this.contactNumber,
    required this.houseNumber,
    required this.street,
    required this.barangay,
    required this.municipality,
    required this.province,
    required this.region,
    this.regionCode,
    this.provinceCode,
    this.municipalityCode,
    this.barangayCode,
    required this.postalCode,
    required this.landmark,
    this.latitude,
    this.longitude,
    required this.isDefault,
  });
}

class ChangeBuyerPasswordRequest {
  final String currentPassword;
  final String newPassword;
  final String newPasswordConfirmation;

  const ChangeBuyerPasswordRequest({
    required this.currentPassword,
    required this.newPassword,
    required this.newPasswordConfirmation,
  });
}

typedef PickProfilePhotoCallback = Future<SelectedProfilePhoto?> Function();

typedef UpdateBuyerProfileCallback =
    Future<BuyerProfileData> Function(UpdateBuyerProfileRequest request);

typedef RequestBuyerEmailChangeCallback = Future<void> Function(String email);
typedef VerifyBuyerEmailChangeCallback =
    Future<BuyerProfileData> Function(String code);

typedef ResendBuyerMobileChangeCodeCallback = Future<void> Function();

typedef RemoveProfilePhotoCallback = Future<BuyerProfileData> Function();

typedef AddBuyerAddressCallback =
    Future<BuyerAddressData> Function(CreateBuyerAddressRequest request);

typedef UpdateBuyerAddressCallback =
    Future<BuyerAddressData> Function(
      String addressId,
      CreateBuyerAddressRequest request,
    );

typedef DeleteBuyerAddressCallback =
    Future<void> Function(BuyerAddressData address);

typedef SetDefaultBuyerAddressCallback =
    Future<void> Function(BuyerAddressData address);

typedef ChangeBuyerPasswordCallback =
    Future<void> Function(ChangeBuyerPasswordRequest request);

typedef DeleteBuyerAccountCallback =
    Future<void> Function(String password, String confirmation);

typedef LoadBuyerRefundDestinationsCallback =
    Future<List<BuyerRefundDestination>> Function();

typedef BuyerRefundDestinationMutationCallback =
    Future<List<BuyerRefundDestination>> Function(
      BuyerRefundDestinationMutation mutation,
    );

typedef RefreshBuyerAccountCallback = Future<BuyerAccountSnapshot> Function();

typedef LogoutBuyerCallback = Future<void> Function();

class AccountScreen extends StatefulWidget {
  final BuyerProfileData profile;

  final List<BuyerAddressData> addresses;

  final BuyerAccountTab initialTab;

  final String? buyerNotice;
  final String? errorMessage;

  /// null means the server did not provide an account-status
  /// value. Flutter must not invent "Active".
  final bool? accountActive;

  final VoidCallback? onBack;

  final PickProfilePhotoCallback? onPickProfilePhoto;

  final UpdateBuyerProfileCallback? onUpdateProfile;

  final RequestBuyerEmailChangeCallback? onRequestEmailChange;

  final VerifyBuyerEmailChangeCallback? onVerifyEmailChange;

  final ResendBuyerMobileChangeCodeCallback? onResendEmailChangeCode;

  final ResendBuyerMobileChangeCodeCallback? onResendMobileChangeCode;

  final RemoveProfilePhotoCallback? onRemoveProfilePhoto;

  final AddBuyerAddressCallback? onAddAddress;

  final UpdateBuyerAddressCallback? onUpdateAddress;

  final AddressLoader? loadRegions;
  final ChildAddressLoader? loadProvinces;
  final ChildAddressLoader? loadMunicipalities;
  final ChildAddressLoader? loadBarangays;
  final PostalCodeLoader? loadPostalCode;

  final DeleteBuyerAddressCallback? onDeleteAddress;

  final SetDefaultBuyerAddressCallback? onSetDefaultAddress;

  final ChangeBuyerPasswordCallback? onChangePassword;

  final DeleteBuyerAccountCallback? onDeleteAccount;

  final LoadBuyerRefundDestinationsCallback? onLoadRefundDestinations;

  final BuyerRefundDestinationMutationCallback? onMutateRefundDestination;

  final VoidCallback? onSystemSettings;
  final VoidCallback? onRecentlyViewed;

  final VoidCallback? onVouchers;
  final VoidCallback? onFollowingStores;

  /// Uses the compact Buyer Center header used by account pages.
  final bool showNavigationTabs;

  /// Shows a back button when this section was opened as a dedicated page.
  final bool showBackButton;

  /// Shows the Settings icon only on the main Profile tab.
  final bool showProfileSettingsButton;

  final RefreshBuyerAccountCallback? onRefresh;

  final LogoutBuyerCallback? onLogout;

  /// Optional parent synchronization callbacks.
  final ValueChanged<BuyerProfileData>? onProfileChanged;

  final ValueChanged<List<BuyerAddressData>>? onAddressesChanged;

  const AccountScreen({
    super.key,
    required this.profile,
    this.addresses = const <BuyerAddressData>[],
    this.initialTab = BuyerAccountTab.profile,
    this.buyerNotice,
    this.errorMessage,
    this.accountActive,
    this.onBack,
    this.onPickProfilePhoto,
    this.onUpdateProfile,
    this.onRequestEmailChange,
    this.onVerifyEmailChange,
    this.onResendEmailChangeCode,
    this.onResendMobileChangeCode,
    this.onRemoveProfilePhoto,
    this.onAddAddress,
    this.onUpdateAddress,
    this.loadRegions,
    this.loadProvinces,
    this.loadMunicipalities,
    this.loadBarangays,
    this.loadPostalCode,
    this.onDeleteAddress,
    this.onSetDefaultAddress,
    this.onChangePassword,
    this.onDeleteAccount,
    this.onLoadRefundDestinations,
    this.onMutateRefundDestination,
    this.onSystemSettings,
    this.onRecentlyViewed,
    this.onVouchers,
    this.onFollowingStores,
    this.showNavigationTabs = true,
    this.showBackButton = false,
    this.showProfileSettingsButton = false,
    this.onRefresh,
    this.onLogout,
    this.onProfileChanged,
    this.onAddressesChanged,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const Color _background = ShopColors.canvas;

  static const Color _surface = ShopColors.surface;

  static const Color _soft = ShopColors.soft;

  static const Color _border = ShopColors.border;

  static const Color _maroon = ShopColors.accent;

  static const Color _maroonDark = ShopColors.accentDark;

  static const Color _text = ShopColors.text;

  static const Color _brown = ShopColors.secondaryText;

  static const Color _muted = ShopColors.muted;

  static const Color _muted2 = ShopColors.faint;

  static const Color _tan = ShopColors.tan;

  static const Color _danger = Color(0xFFB42318);

  static const LatLng _defaultAddressMapCenter = LatLng(14.5995, 120.9842);

  late BuyerProfileData _profile;

  late List<BuyerAddressData> _addresses;

  late BuyerAccountTab _activeTab;

  bool _addingAddress = false;
  String? _editingAddressId;

  final Set<String> _deletingAddressIds = <String>{};
  final Set<String> _defaultingAddressIds = <String>{};

  bool _changingPassword = false;
  bool _refreshing = false;

  bool _loggingOut = false;

  List<BuyerRefundDestination> _refundDestinations = <BuyerRefundDestination>[];
  bool _loadingRefundDestinations = false;
  bool _savingRefundDestination = false;
  bool _refundDestinationsLoaded = false;
  String? _refundDestinationError;
  String? _editingRefundDestinationId;
  String _refundMethod = 'GCash';
  String _refundAccountType = 'MOBILE_NUMBER';
  bool _refundMakeDefault = true;
  final GlobalKey<FormState> _refundDestinationFormKey = GlobalKey<FormState>();
  final TextEditingController _refundBankController = TextEditingController();
  final TextEditingController _refundNameController = TextEditingController();
  final TextEditingController _refundNumberController = TextEditingController();
  final TextEditingController _deleteAccountPasswordController =
      TextEditingController();
  final TextEditingController _deleteAccountConfirmationController =
      TextEditingController();
  bool _deletingAccount = false;
  String? _deleteAccountError;

  final GlobalKey<FormState> _addressFormKey = GlobalKey<FormState>();

  final GlobalKey<FormState> _accountSecurityFormKey = GlobalKey<FormState>();

  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();

  late final TextEditingController _securityNameController;

  late final TextEditingController _securityEmailController;

  late final TextEditingController _securityPhoneController;

  SelectedProfilePhoto? _securitySelectedPhoto;

  DateTime? _securityBirthday;

  BuyerGender? _securityGender;

  bool _savingAccountSecurity = false;

  late final TextEditingController _addressLabelController;

  late final TextEditingController _recipientNameController;

  late final TextEditingController _addressPhoneController;

  final TextEditingController _houseNumberController = TextEditingController();

  final TextEditingController _streetController = TextEditingController();

  final TextEditingController _barangayController = TextEditingController();

  final TextEditingController _municipalityController = TextEditingController();

  final TextEditingController _provinceController = TextEditingController();

  final TextEditingController _regionController = TextEditingController();

  final TextEditingController _postalCodeController = TextEditingController();

  final TextEditingController _landmarkController = TextEditingController();

  final TextEditingController _addressSearchController =
      TextEditingController();

  AddressOption? _selectedRegion;
  AddressOption? _selectedProvince;
  AddressOption? _selectedMunicipality;
  AddressOption? _selectedBarangay;
  List<AddressOption> _addressRegions = <AddressOption>[];
  List<AddressOption> _addressProvinces = <AddressOption>[];
  List<AddressOption> _addressMunicipalities = <AddressOption>[];
  List<AddressOption> _addressBarangays = <AddressOption>[];
  bool _loadingAddressRegions = false;
  bool _loadingAddressProvinces = false;
  bool _loadingAddressMunicipalities = false;
  bool _loadingAddressBarangays = false;
  bool _loadingPostalCode = false;
  bool _postalCodeLookupFailed = false;
  int _addressOptionsRequest = 0;
  int _postalCodeLookupGeneration = 0;

  maplibre.MapLibreSession? _addressMap;
  maplibre.CircleAnnotationManager? _addressMarkerManager;

  LatLng? _selectedAddressLocation;
  LatLng _addressMapCenter = _defaultAddressMapCenter;
  double _addressMapZoom = 14;
  bool _findingAddress = false;
  bool _usingDeviceLocation = false;
  String? _addressLocationMessage;

  bool _newAddressIsDefault = false;

  final TextEditingController _currentPasswordController =
      TextEditingController();

  final TextEditingController _newPasswordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();

    _profile = widget.profile;

    _addresses = List<BuyerAddressData>.from(widget.addresses);

    _activeTab = widget.initialTab;

    _securityNameController = TextEditingController(text: _profile.name);

    _securityEmailController = TextEditingController(text: _profile.email);

    _securityPhoneController = TextEditingController(text: _profile.phone);

    _securityBirthday = _profile.birthday;

    _securityGender = _profile.gender;

    _newAddressIsDefault = _addresses.isEmpty;

    _addressLabelController = TextEditingController(text: 'Home');

    _recipientNameController = TextEditingController(text: _profile.name);

    _addressPhoneController = TextEditingController(text: _profile.phone);

    if (_activeTab == BuyerAccountTab.addresses) {
      unawaited(_loadAddressRegions());
    }
    if (_activeTab == BuyerAccountTab.wallet) {
      unawaited(_loadRefundDestinations());
    }
  }

  @override
  void didUpdateWidget(covariant AccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.profile != widget.profile) {
      final BuyerProfileData previousProfile = _profile;

      _profile = widget.profile;

      if (_securityNameController.text.trim() == previousProfile.name.trim()) {
        _securityNameController.text = _profile.name;
      }
      if (_securityEmailController.text.trim() ==
          previousProfile.email.trim()) {
        _securityEmailController.text = _profile.email;
      }
      if (_securityPhoneController.text.trim() ==
          previousProfile.phone.trim()) {
        _securityPhoneController.text = _profile.phone;
      }
      if (_securityBirthday == previousProfile.birthday) {
        _securityBirthday = _profile.birthday;
      }
      if (_securityGender == previousProfile.gender) {
        _securityGender = _profile.gender;
      }

      if (_recipientNameController.text.trim().isEmpty ||
          _recipientNameController.text.trim() == previousProfile.name.trim()) {
        _recipientNameController.text = _profile.name;
      }

      if (_addressPhoneController.text.trim().isEmpty ||
          _addressPhoneController.text.trim() == previousProfile.phone.trim()) {
        _addressPhoneController.text = _profile.phone;
      }
    }

    if (oldWidget.addresses != widget.addresses) {
      _addresses = List<BuyerAddressData>.from(widget.addresses);

      _cleanupDeletingAddressIds();
    }

    if (oldWidget.initialTab != widget.initialTab) {
      _activeTab = widget.initialTab;
      if (_activeTab == BuyerAccountTab.addresses) {
        unawaited(_loadAddressRegions());
      }
      if (_activeTab == BuyerAccountTab.wallet) {
        unawaited(_loadRefundDestinations());
      }
    }
  }

  @override
  void dispose() {
    _securityNameController.dispose();
    _securityEmailController.dispose();
    _securityPhoneController.dispose();
    _addressLabelController.dispose();
    _recipientNameController.dispose();
    _addressPhoneController.dispose();

    _houseNumberController.dispose();
    _streetController.dispose();
    _barangayController.dispose();
    _municipalityController.dispose();
    _provinceController.dispose();
    _regionController.dispose();
    _postalCodeController.dispose();
    _landmarkController.dispose();
    _addressSearchController.dispose();

    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _refundBankController.dispose();
    _refundNameController.dispose();
    _refundNumberController.dispose();
    _deleteAccountPasswordController.dispose();
    _deleteAccountConfirmationController.dispose();

    super.dispose();
  }

  void _setAddressLocation(LatLng location, {bool moveMap = true}) {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedAddressLocation = location;
      _addressMapCenter = location;
      _addressLocationMessage = null;
    });

    unawaited(_syncAddressMarker());

    if (moveMap && _addressMap != null) {
      _addressMapZoom = 16;
      unawaited(
        _addressMap!.setCamera(
          maplibre.CameraOptions(
            center: _toMapLibrePoint(location),
            zoom: _addressMapZoom,
          ),
        ),
      );
    }
  }

  bool get _canShowAddressMap {
    final bool supportedPlatform =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return supportedPlatform;
  }

  Future<void> _onAddressMapCreated(maplibre.MapLibreSession map) async {
    _addressMap = map;
    _addressMarkerManager = await map.annotations
        .createCircleAnnotationManager();
    await _syncAddressMarker();
  }

  Future<void> _syncAddressMarker() async {
    final maplibre.CircleAnnotationManager? manager = _addressMarkerManager;
    if (manager == null) {
      return;
    }

    await manager.deleteAll();

    final LatLng? location = _selectedAddressLocation;
    if (location == null) {
      return;
    }

    await manager.create(
      maplibre.CircleAnnotationOptions(
        geometry: _toMapLibrePoint(location),
        circleColor: AppTheme.resolve(context, _maroon).toARGB32(),
        circleRadius: 11,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 3,
      ),
    );
  }

  void _onAddressMapTap(maplibre.MapContentGestureContext context) {
    _setAddressLocation(_fromMapLibrePoint(context.point));
  }

  maplibre.Point _toMapLibrePoint(LatLng location) {
    return maplibre.Point(
      coordinates: maplibre.Position(location.longitude, location.latitude),
    );
  }

  LatLng _fromMapLibrePoint(maplibre.Point point) {
    return LatLng(
      point.coordinates.lat.toDouble(),
      point.coordinates.lng.toDouble(),
    );
  }

  Future<void> _useDeviceLocation() async {
    if (_usingDeviceLocation) {
      return;
    }

    setState(() {
      _usingDeviceLocation = true;
      _addressLocationMessage = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const FormatException('Turn on location services first.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const FormatException(
          'Location permission is required to use device location.',
        );
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _setAddressLocation(LatLng(position.latitude, position.longitude));
    } catch (error) {
      if (mounted) {
        setState(() {
          _addressLocationMessage = _addressLocationErrorText(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _usingDeviceLocation = false;
        });
      }
    }
  }

  Future<void> _loadAddressRegions() async {
    if (_addressRegions.isNotEmpty || _loadingAddressRegions) return;
    final AddressLoader? loader = widget.loadRegions;
    if (loader == null) return;

    setState(() => _loadingAddressRegions = true);
    try {
      final List<AddressOption> regions = await loader();
      if (!mounted) return;
      setState(() => _addressRegions = regions);
    } catch (_) {
      if (mounted) _showMessage('Unable to load regions.', error: true);
    } finally {
      if (mounted) setState(() => _loadingAddressRegions = false);
    }
  }

  void _refreshAddressPinAfterLocationChange() {
    unawaited(_syncAddressMarker());
    final maplibre.MapLibreSession? map = _addressMap;
    if (map != null) {
      unawaited(
        map.setCamera(
          maplibre.CameraOptions(
            center: _toMapLibrePoint(_defaultAddressMapCenter),
            zoom: 14,
          ),
        ),
      );
    }
  }

  void _clearPostalCodeForLocationChange() {
    _postalCodeLookupGeneration++;
    _postalCodeController.clear();
    _loadingPostalCode = false;
    _postalCodeLookupFailed = false;
  }

  Future<void> _onAddressRegionChanged(AddressOption? value) async {
    if (_selectedRegion?.code == value?.code) return;
    final int request = ++_addressOptionsRequest;
    final ChildAddressLoader? loadProvinces = widget.loadProvinces;
    final bool shouldLoad = value != null && loadProvinces != null;
    setState(() {
      _selectedRegion = value;
      _selectedProvince = null;
      _selectedMunicipality = null;
      _selectedBarangay = null;
      _addressProvinces = <AddressOption>[];
      _addressMunicipalities = <AddressOption>[];
      _addressBarangays = <AddressOption>[];
      _loadingAddressProvinces = shouldLoad;
      _loadingAddressMunicipalities = false;
      _loadingAddressBarangays = false;
      _regionController.text = value?.name ?? '';
      _provinceController.clear();
      _municipalityController.clear();
      _barangayController.clear();
      _clearPostalCodeForLocationChange();
      _selectedAddressLocation = null;
      _addressLocationMessage = null;
      _addressMapCenter = _defaultAddressMapCenter;
      _addressMapZoom = 14;
    });
    _refreshAddressPinAfterLocationChange();
    if (value == null || loadProvinces == null) return;

    try {
      final List<AddressOption> options = await loadProvinces(value.code);
      if (!mounted ||
          request != _addressOptionsRequest ||
          _selectedRegion?.code != value.code)
        return;
      setState(() => _addressProvinces = options);
    } catch (_) {
      if (mounted && request == _addressOptionsRequest) {
        _showMessage('Unable to load provinces.', error: true);
      }
    } finally {
      if (mounted && request == _addressOptionsRequest) {
        setState(() => _loadingAddressProvinces = false);
      }
    }
  }

  Future<void> _onAddressProvinceChanged(AddressOption? value) async {
    if (_selectedProvince?.code == value?.code) return;
    final int request = ++_addressOptionsRequest;
    final ChildAddressLoader? loadMunicipalities = widget.loadMunicipalities;
    final bool shouldLoad = value != null && loadMunicipalities != null;
    setState(() {
      _selectedProvince = value;
      _selectedMunicipality = null;
      _selectedBarangay = null;
      _addressMunicipalities = <AddressOption>[];
      _addressBarangays = <AddressOption>[];
      _loadingAddressMunicipalities = shouldLoad;
      _loadingAddressBarangays = false;
      _provinceController.text = value?.name ?? '';
      _municipalityController.clear();
      _barangayController.clear();
      _clearPostalCodeForLocationChange();
      _selectedAddressLocation = null;
      _addressLocationMessage = null;
      _addressMapCenter = _defaultAddressMapCenter;
      _addressMapZoom = 14;
    });
    _refreshAddressPinAfterLocationChange();
    if (value == null || loadMunicipalities == null) return;

    try {
      final List<AddressOption> options = await loadMunicipalities(value.code);
      if (!mounted ||
          request != _addressOptionsRequest ||
          _selectedProvince?.code != value.code)
        return;
      setState(() => _addressMunicipalities = options);
    } catch (_) {
      if (mounted && request == _addressOptionsRequest) {
        _showMessage('Unable to load cities.', error: true);
      }
    } finally {
      if (mounted && request == _addressOptionsRequest) {
        setState(() => _loadingAddressMunicipalities = false);
      }
    }
  }

  Future<void> _onAddressMunicipalityChanged(AddressOption? value) async {
    if (_selectedMunicipality?.code == value?.code) return;
    final int request = ++_addressOptionsRequest;
    final int postalLookupGeneration = ++_postalCodeLookupGeneration;
    final ChildAddressLoader? loadBarangays = widget.loadBarangays;
    final PostalCodeLoader? loadPostalCode = widget.loadPostalCode;
    final bool shouldLoad = value != null && loadBarangays != null;
    setState(() {
      _selectedMunicipality = value;
      _selectedBarangay = null;
      _addressBarangays = <AddressOption>[];
      _loadingAddressBarangays = shouldLoad;
      _municipalityController.text = value?.name ?? '';
      _barangayController.clear();
      _postalCodeController.clear();
      _loadingPostalCode = value != null && loadPostalCode != null;
      _postalCodeLookupFailed = false;
      _selectedAddressLocation = null;
      _addressLocationMessage = null;
      _addressMapCenter = _defaultAddressMapCenter;
      _addressMapZoom = 14;
    });
    _refreshAddressPinAfterLocationChange();
    if (value != null && loadPostalCode != null) {
      unawaited(_loadPostalCodeForMunicipality(value, postalLookupGeneration));
    }
    if (value == null || loadBarangays == null) return;

    try {
      final List<AddressOption> options = await loadBarangays(value.code);
      if (!mounted ||
          request != _addressOptionsRequest ||
          _selectedMunicipality?.code != value.code) {
        return;
      }
      setState(() => _addressBarangays = options);
    } catch (_) {
      if (mounted && request == _addressOptionsRequest) {
        _showMessage('Unable to load barangays.', error: true);
      }
    } finally {
      if (mounted && request == _addressOptionsRequest) {
        setState(() => _loadingAddressBarangays = false);
      }
    }
  }

  Future<void> _onAddressBarangayChanged(AddressOption? value) async {
    if (_selectedBarangay?.code == value?.code) return;
    setState(() {
      _selectedBarangay = value;
      _barangayController.text = value?.name ?? '';
      _selectedAddressLocation = null;
      _addressLocationMessage = null;
      _addressMapCenter = _defaultAddressMapCenter;
      _addressMapZoom = 14;
    });
    _refreshAddressPinAfterLocationChange();
  }

  Future<void> _loadPostalCodeForMunicipality(
    AddressOption municipality,
    int lookupGeneration,
  ) async {
    final PostalCodeLoader? loadPostalCode = widget.loadPostalCode;
    if (loadPostalCode == null) return;

    try {
      final String? postalCode = await loadPostalCode(
        municipalityCode: municipality.code,
        provinceCode: _selectedProvince?.code ?? '',
        provinceName: _selectedProvince?.name ?? '',
        municipalityName: municipality.name,
      );
      if (!mounted ||
          lookupGeneration != _postalCodeLookupGeneration ||
          _selectedMunicipality?.code != municipality.code) {
        return;
      }
      final String normalizedPostalCode = postalCode?.trim() ?? '';
      setState(() {
        if (_postalCodeController.text.trim().isEmpty) {
          _postalCodeController.text = normalizedPostalCode;
        }
        _loadingPostalCode = false;
        _postalCodeLookupFailed =
            normalizedPostalCode.isEmpty &&
            _postalCodeController.text.trim().isEmpty;
      });
    } catch (_) {
      if (mounted && lookupGeneration == _postalCodeLookupGeneration) {
        setState(() {
          _loadingPostalCode = false;
          _postalCodeLookupFailed = _postalCodeController.text.trim().isEmpty;
        });
      }
    }
  }

  Widget _buildAddressDropdown({
    required String label,
    required String hint,
    required List<AddressOption> options,
    required AddressOption? value,
    required bool enabled,
    required bool loading,
    required ValueChanged<AddressOption?> onChanged,
  }) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(
        color: AppTheme.resolve(context, ShopColors.border),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel(text: label, requiredField: true),
          const SizedBox(height: 7),
          DropdownButtonFormField<AddressOption>(
            value: value,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: loading ? 'Loading...' : hint,
              hintStyle: TextStyle(
                color: AppTheme.resolve(context, ShopColors.faint),
                fontSize: 14,
              ),
              isDense: true,
              filled: true,
              fillColor: AppTheme.resolve(
                context,
                ShopColors.canvas,
                fill: true,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 15,
              ),
              suffixIcon: loading
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: BorderSide(
                  color: AppTheme.resolve(context, ShopColors.accent),
                  width: 1.3,
                ),
              ),
              errorBorder: border.copyWith(
                borderSide: BorderSide(
                  color: AppTheme.resolve(context, Color(0xFFD64A59)),
                ),
              ),
              focusedErrorBorder: border.copyWith(
                borderSide: BorderSide(
                  color: AppTheme.resolve(context, Color(0xFFD64A59)),
                  width: 1.3,
                ),
              ),
            ),
            items: options
                .map(
                  (AddressOption option) => DropdownMenuItem<AddressOption>(
                    value: option,
                    child: Text(option.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            validator: (AddressOption? selected) =>
                selected == null ? 'Please select an option.' : null,
            onChanged: enabled && !loading ? onChanged : null,
          ),
        ],
      ),
    );
  }

  String get _postalCodeHelperText {
    if (_loadingPostalCode) return 'Finding postal code...';
    if (_postalCodeLookupFailed) {
      return 'Not found automatically. Enter it if you know it.';
    }
    final String postalCode = _postalCodeController.text.trim();
    if (postalCode.isNotEmpty) return 'Postal code: $postalCode';
    return 'Postal code will fill after you select a municipality.';
  }

  Widget _buildAddressLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAddressDropdown(
          label: 'Region',
          hint: 'Select region',
          options: _addressRegions,
          value: _selectedRegion,
          enabled: widget.loadProvinces != null && !_loadingAddressRegions,
          loading: _loadingAddressRegions,
          onChanged: (AddressOption? value) {
            unawaited(_onAddressRegionChanged(value));
          },
        ),
        _buildAddressDropdown(
          label: 'Province',
          hint: 'Select province',
          options: _addressProvinces,
          value: _selectedProvince,
          enabled: _selectedRegion != null,
          loading: _loadingAddressProvinces,
          onChanged: (AddressOption? value) {
            unawaited(_onAddressProvinceChanged(value));
          },
        ),
        _buildAddressDropdown(
          label: 'City / Municipality',
          hint: 'Select municipality / city',
          options: _addressMunicipalities,
          value: _selectedMunicipality,
          enabled: _selectedProvince != null,
          loading: _loadingAddressMunicipalities,
          onChanged: (AddressOption? value) {
            unawaited(_onAddressMunicipalityChanged(value));
          },
        ),
        _buildAddressDropdown(
          label: 'Barangay',
          hint: 'Select barangay',
          options: _addressBarangays,
          value: _selectedBarangay,
          enabled: _selectedMunicipality != null,
          loading: _loadingAddressBarangays,
          onChanged: (AddressOption? value) {
            unawaited(_onAddressBarangayChanged(value));
          },
        ),
        _AddressInput(
          label: 'Postal code',
          controller: _postalCodeController,
          hint: 'Auto-filled when available',
          helperText: _postalCodeHelperText,
          helperTextError: _postalCodeLookupFailed,
          prefixIcon: Icons.markunread_mailbox_outlined,
          keyboardType: TextInputType.number,
          maxLength: 20,
          readOnly: false,
          onChanged: (_) {
            if (_postalCodeLookupFailed) {
              setState(() => _postalCodeLookupFailed = false);
            }
          },
        ),
      ],
    );
  }

  Future<void> _findAddress() async {
    if (_findingAddress) {
      return;
    }
    final List<String> queries = PhilippineAddressGeocoding.buildQueries(
      searchText: _addressSearchController.text,
      houseNumber: _houseNumberController.text,
      street: _streetController.text,
      landmark: _landmarkController.text,
      barangay: _barangayController.text,
      municipality: _municipalityController.text,
      province: _provinceController.text,
      region: _regionController.text,
    );

    if (queries.isEmpty) {
      setState(() {
        _addressLocationMessage =
            'Enter a street, barangay, city, or province first, then search to place the pin.';
      });
      return;
    }

    setState(() {
      _findingAddress = true;
      _addressLocationMessage = null;
    });

    try {
      LatLng? location;
      for (final String query in queries) {
        final Response<dynamic> response = await ApiClient.getMapGeocode(query);
        if (!mounted) return;
        final int statusCode = response.statusCode ?? 500;
        final String? errorMessage =
            PhilippineAddressGeocoding.errorMessageForResponse(
              statusCode,
              response.data,
            );
        if (errorMessage != null) {
          throw FormatException(errorMessage);
        }
        location = PhilippineAddressGeocoding.locationFromResponse(
          response.data,
        );
        if (location != null) break;
      }

      if (location == null) {
        throw const FormatException(
          'We could not locate this address. Tap your delivery spot on the map or use device location. You can still save with your chosen pin.',
        );
      }

      _setAddressLocation(location);
      if (mounted) {
        setState(() {
          _addressLocationMessage =
              'Check the pin before saving. If needed, tap the map to mark your exact delivery spot.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _addressLocationMessage = _addressLocationErrorText(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _findingAddress = false;
        });
      }
    }
  }

  String _addressLocationErrorText(Object error) {
    if (error is FormatException) {
      return error.message.toString();
    }

    return 'Unable to set the delivery location. You can tap the map to pin it manually.';
  }

  void _cleanupDeletingAddressIds() {
    final Set<String> currentIds = _addresses
        .map((BuyerAddressData address) => address.id)
        .toSet();

    _deletingAddressIds.removeWhere((String id) => !currentIds.contains(id));
  }

  Future<void> _refresh() async {
    final RefreshBuyerAccountCallback? callback = widget.onRefresh;

    if (callback == null || _refreshing) {
      return;
    }

    setState(() {
      _refreshing = true;
    });

    try {
      final BuyerAccountSnapshot snapshot = await callback();
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = snapshot.profile;
        _addresses = List<BuyerAddressData>.from(snapshot.addresses);
      });
      widget.onProfileChanged?.call(snapshot.profile);
      widget.onAddressesChanged?.call(_addresses);
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _addAddress() async {
    FocusScope.of(context).unfocus();

    if (_addingAddress) {
      return;
    }

    if (!(_addressFormKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_selectedAddressLocation == null) {
      setState(() {
        _addressLocationMessage = 'Please pin the delivery location.';
      });
      return;
    }

    final String? editingId = _editingAddressId;
    final AddBuyerAddressCallback? addCallback = widget.onAddAddress;
    final UpdateBuyerAddressCallback? updateCallback = widget.onUpdateAddress;

    if ((editingId == null && addCallback == null) ||
        (editingId != null && updateCallback == null)) {
      _showMessage('Address saving will be connected to Laravel later.');

      return;
    }

    setState(() {
      _addingAddress = true;
    });

    try {
      final CreateBuyerAddressRequest request = CreateBuyerAddressRequest(
        label: _addressLabelController.text.trim(),
        recipientName: _recipientNameController.text.trim(),
        contactNumber: _addressPhoneController.text.trim(),
        houseNumber: _houseNumberController.text.trim(),
        street: _streetController.text.trim(),
        barangay: _selectedBarangay?.name ?? '',
        municipality: _selectedMunicipality?.name ?? '',
        province: _selectedProvince?.name ?? '',
        region: _selectedRegion?.name ?? '',
        regionCode: _selectedRegion?.code,
        provinceCode: _selectedProvince?.code,
        municipalityCode: _selectedMunicipality?.code,
        barangayCode: _selectedBarangay?.code,
        postalCode: _postalCodeController.text.trim(),
        landmark: _landmarkController.text.trim(),
        latitude: _selectedAddressLocation?.latitude,
        longitude: _selectedAddressLocation?.longitude,
        isDefault: _newAddressIsDefault,
      );
      final BuyerAddressData address = editingId == null
          ? await addCallback!(request)
          : await updateCallback!(editingId, request);

      if (!mounted) {
        return;
      }

      setState(() {
        if (address.isDefault) {
          _addresses = _addresses
              .map(
                (BuyerAddressData current) =>
                    current.copyWith(isDefault: false),
              )
              .toList();
        }

        if (editingId == null) {
          _addresses.add(address);
        } else {
          final int index = _addresses.indexWhere(
            (BuyerAddressData current) => current.id == editingId,
          );
          if (index >= 0) _addresses[index] = address;
        }

        _resetAddressForm();
      });

      _notifyAddressesChanged();

      _showMessage(
        editingId == null ? 'Delivery address saved.' : 'Address updated.',
      );
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _addingAddress = false;
        });
      }
    }
  }

  AddressOption? _matchAddressOption(
    Iterable<AddressOption> options,
    String? code,
    String? name,
  ) {
    for (final AddressOption option in options) {
      if (code != null && code.trim().isNotEmpty && option.code == code) {
        return option;
      }
    }
    final String target = (name ?? '').trim().toLowerCase();
    if (target.isEmpty) return null;
    for (final AddressOption option in options) {
      if (option.name.trim().toLowerCase() == target) return option;
    }
    return null;
  }

  Future<void> _editAddress(BuyerAddressData address) async {
    if (_addingAddress) return;
    _resetAddressForm();
    setState(() {
      _editingAddressId = address.id;
      _addressLabelController.text = address.label;
      _recipientNameController.text = address.recipientName;
      _addressPhoneController.text = address.contactNumber;
      _houseNumberController.text = address.houseNumber ?? '';
      _streetController.text = address.street ?? '';
      _landmarkController.text = address.landmark ?? '';
      _postalCodeController.text = address.postalCode ?? '';
      _newAddressIsDefault = address.isDefault;
      _selectedAddressLocation =
          address.latitude != null && address.longitude != null
          ? LatLng(address.latitude!, address.longitude!)
          : null;
      if (_selectedAddressLocation != null) {
        _addressMapCenter = _selectedAddressLocation!;
      }
      _addressSearchController.text = address.displayAddress;
    });
    await _loadAddressRegions();
    final AddressOption? region = _matchAddressOption(
      _addressRegions,
      address.regionCode,
      address.region,
    );
    if (region == null) {
      if (mounted)
        _showMessage(
          'Could not load the address region for editing.',
          error: true,
        );
      return;
    }
    await _onAddressRegionChanged(region);
    final AddressOption? province = _matchAddressOption(
      _addressProvinces,
      address.provinceCode,
      address.province,
    );
    if (province == null) {
      if (mounted)
        _showMessage(
          'Could not load the address province for editing.',
          error: true,
        );
      return;
    }
    await _onAddressProvinceChanged(province);
    final AddressOption? municipality = _matchAddressOption(
      _addressMunicipalities,
      address.municipalityCode,
      address.municipality,
    );
    if (municipality == null) {
      if (mounted)
        _showMessage(
          'Could not load the address municipality for editing.',
          error: true,
        );
      return;
    }
    await _onAddressMunicipalityChanged(municipality);
    final AddressOption? barangay = _matchAddressOption(
      _addressBarangays,
      address.barangayCode,
      address.barangay,
    );
    if (barangay == null) {
      if (mounted)
        _showMessage(
          'Could not load the address barangay for editing.',
          error: true,
        );
      return;
    }
    await _onAddressBarangayChanged(barangay);
    if (!mounted) return;
    setState(() {
      _postalCodeLookupGeneration++;
      _loadingPostalCode = false;
      _postalCodeLookupFailed = false;
      _postalCodeController.text = address.postalCode ?? '';
      _selectedAddressLocation =
          address.latitude != null && address.longitude != null
          ? LatLng(address.latitude!, address.longitude!)
          : null;
      if (_selectedAddressLocation != null) {
        _addressMapCenter = _selectedAddressLocation!;
      }
    });
    unawaited(_syncAddressMarker());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        _addressFormKey.currentContext ?? context,
        duration: const Duration(milliseconds: 250),
      );
    });
  }

  void _resetAddressForm() {
    _editingAddressId = null;
    _addressLabelController.text = 'Home';

    _recipientNameController.text = _profile.name;

    _addressPhoneController.text = _profile.phone;

    _houseNumberController.clear();
    _streetController.clear();
    _barangayController.clear();
    _municipalityController.clear();
    _provinceController.clear();
    _regionController.clear();
    _postalCodeController.clear();
    _landmarkController.clear();
    _addressSearchController.clear();

    _selectedRegion = null;
    _selectedProvince = null;
    _selectedMunicipality = null;
    _selectedBarangay = null;
    _addressProvinces = <AddressOption>[];
    _addressMunicipalities = <AddressOption>[];
    _addressBarangays = <AddressOption>[];
    _loadingAddressProvinces = false;
    _loadingAddressMunicipalities = false;
    _loadingAddressBarangays = false;
    _loadingPostalCode = false;
    _postalCodeLookupFailed = false;
    _addressOptionsRequest++;
    _postalCodeLookupGeneration++;

    _newAddressIsDefault = false;
    _selectedAddressLocation = null;
    _addressMapCenter = _defaultAddressMapCenter;
    _addressMapZoom = 14;
    _addressLocationMessage = null;

    unawaited(_syncAddressMarker());
    final maplibre.MapLibreSession? map = _addressMap;
    if (map != null) {
      unawaited(
        map.setCamera(
          maplibre.CameraOptions(
            center: _toMapLibrePoint(_defaultAddressMapCenter),
            zoom: _addressMapZoom,
          ),
        ),
      );
    }
  }

  Future<void> _deleteAddress(BuyerAddressData address) async {
    if (_deletingAddressIds.contains(address.id)) {
      return;
    }

    final DeleteBuyerAddressCallback? callback = widget.onDeleteAddress;

    if (callback == null) {
      _showMessage('Address deletion will be connected to Laravel later.');

      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.resolve(context, _surface, fill: true),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Delete address?',
            style: TextStyle(
              color: AppTheme.resolve(context, _text),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Remove "${address.label}" from your saved delivery addresses?',
            style: TextStyle(
              color: AppTheme.resolve(context, _muted),
              fontSize: 15,
              height: 1.55,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Keep Address'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.resolve(context, _danger, fill: true),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _deletingAddressIds.add(address.id);
    });

    try {
      await callback(address);

      if (!mounted) {
        return;
      }

      setState(() {
        _addresses.removeWhere(
          (BuyerAddressData current) => current.id == address.id,
        );
      });

      _notifyAddressesChanged();

      _showMessage('Address deleted.');
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _deletingAddressIds.remove(address.id);
        });
      }
    }
  }

  Future<void> _setDefaultAddress(BuyerAddressData address) async {
    if (address.isDefault || _defaultingAddressIds.contains(address.id)) {
      return;
    }
    final SetDefaultBuyerAddressCallback? callback = widget.onSetDefaultAddress;
    if (callback == null) {
      _showMessage('Setting the default address is not connected.');
      return;
    }
    setState(() => _defaultingAddressIds.add(address.id));
    try {
      await callback(address);
      if (!mounted) return;
      setState(() {
        _addresses = _addresses
            .map(
              (BuyerAddressData current) =>
                  current.copyWith(isDefault: current.id == address.id),
            )
            .toList(growable: false);
      });
      _notifyAddressesChanged();
      _showMessage('Default delivery address updated.');
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() => _defaultingAddressIds.remove(address.id));
      }
    }
  }

  void _notifyAddressesChanged() {
    widget.onAddressesChanged?.call(
      List<BuyerAddressData>.unmodifiable(_addresses),
    );
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();

    if (_changingPassword) {
      return;
    }

    if (!(_passwordFormKey.currentState?.validate() ?? false)) {
      return;
    }

    final ChangeBuyerPasswordCallback? callback = widget.onChangePassword;

    if (callback == null) {
      _showMessage('Password changing will be connected to Laravel later.');

      return;
    }

    setState(() {
      _changingPassword = true;
    });

    try {
      await callback(
        ChangeBuyerPasswordRequest(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
          newPasswordConfirmation: _confirmPasswordController.text,
        ),
      );

      if (!mounted) {
        return;
      }

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      setState(() {
        _showCurrentPassword = false;

        _showNewPassword = false;

        _showConfirmPassword = false;
      });

      _showMessage('Password updated.');
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _changingPassword = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error
              ? AppTheme.resolve(context, _danger, fill: true)
              : AppTheme.resolve(context, _maroonDark, fill: true),
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
  }

  String _errorText(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.resolve(context, _background, fill: true),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child: RefreshIndicator(
                color: AppTheme.resolve(context, _maroon),
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(14, 15, 14, 100),
                  children: [
                    if (widget.buyerNotice?.trim().isNotEmpty == true) ...[
                      _MessageBanner(
                        message: widget.buyerNotice!,
                        error: false,
                      ),

                      const SizedBox(height: 10),
                    ],

                    if (widget.errorMessage?.trim().isNotEmpty == true) ...[
                      _MessageBanner(
                        message: widget.errorMessage!,
                        error: true,
                      ),

                      const SizedBox(height: 10),
                    ],

                    _buildHeading(),

                    SizedBox(height: widget.showBackButton ? 4 : 16),

                    if (widget.initialTab != BuyerAccountTab.profile &&
                        _activeTab != BuyerAccountTab.accountSecurity &&
                        _activeTab != BuyerAccountTab.profile) ...[
                      _buildAccountSummary(),
                      const SizedBox(height: 14),
                    ] else
                      const SizedBox(height: 4),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: KeyedSubtree(
                        key: ValueKey<BuyerAccountTab>(_activeTab),
                        child: _buildActiveContent(),
                      ),
                    ),

                    const SizedBox(height: 18),

                    _buildLogoutButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return OutlinedButton.icon(
      onPressed: widget.onLogout == null || _loggingOut ? null : _confirmLogout,
      icon: _loggingOut
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.logout_rounded),
      label: Text(_loggingOut ? 'Signing Out...' : 'Sign Out'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.resolve(context, _danger),
        disabledForegroundColor: AppTheme.resolve(context, _muted2),
        side: BorderSide(color: AppTheme.resolve(context, _danger)),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'You will need to sign in again to access your buyer account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || widget.onLogout == null || !mounted) {
      return;
    }

    setState(() {
      _loggingOut = true;
    });

    try {
      await widget.onLogout!();
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut = false;
        });
      }
    }
  }

  Widget _buildTopBar() {
    final VoidCallback handleBack =
        widget.onBack ?? () => Navigator.of(context).maybePop();
    final List<Widget> actions = [
      if (_refreshing)
        const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      if (widget.accountActive != null)
        _AccountStatusBadge(active: widget.accountActive!),
    ];

    if (widget.showNavigationTabs) {
      if (widget.showBackButton) {
        final String title = switch (_activeTab) {
          BuyerAccountTab.accountSecurity => 'Account & Security',
          BuyerAccountTab.addresses => 'Address Management',
          _ => _activeTab.label,
        };
        final String subtitle = switch (_activeTab) {
          BuyerAccountTab.accountSecurity =>
            'Edit your personal information and update your password.',
          BuyerAccountTab.addresses =>
            'Manage your saved delivery addresses and locations.',
          BuyerAccountTab.profile =>
            'View your account details and personal information.',
          BuyerAccountTab.wallet => 'Manage your refund destination.',
          BuyerAccountTab.vouchers => 'View your available vouchers.',
          BuyerAccountTab.followingStores => 'Stores you follow.',
          BuyerAccountTab.recentlyViewed => 'Products you viewed recently.',
          BuyerAccountTab.password => 'Update your account password.',
          BuyerAccountTab.settings => 'Manage your app preferences.',
          BuyerAccountTab.dangerZone => 'Manage account deletion.',
        };
        return ShopPageHeader(
          title: title,
          subtitle: subtitle,
          onBack: handleBack,
        );
      }

      if (actions.isEmpty && !widget.showBackButton) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(
          children: [
            const Spacer(),
            ...actions,
          ],
        ),
      );
    }

    return ShopPageHeader(
      title: _activeTab == BuyerAccountTab.addresses
          ? 'Address Management'
          : _activeTab.label,
      subtitle: _activeTab.description,
      onBack: handleBack,
      actions: actions,
    );
  }

  Widget _buildHeading() {
    if (widget.showBackButton) {
      return const SizedBox.shrink();
    }

    final String title = switch (_activeTab) {
      BuyerAccountTab.accountSecurity => 'Account & Security',
      BuyerAccountTab.addresses => 'Address Management',
      _ => 'Account Management',
    };
    final String subtitle = switch (_activeTab) {
      BuyerAccountTab.accountSecurity =>
        'Edit your personal information and update your password.',
      BuyerAccountTab.addresses =>
        'Manage your saved delivery addresses and locations.',
      _ =>
        'View your account details, delivery addresses, and account security.',
    };
    final bool showSettingsIcon =
        widget.showProfileSettingsButton &&
        _activeTab == BuyerAccountTab.profile &&
        widget.onSystemSettings != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppTheme.resolve(context, _text),
                  fontSize: 30,
                  height: 1.05,
                  letterSpacing: -0.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (showSettingsIcon)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.resolve(context, _border)),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: IconButton(
                  onPressed: widget.onSystemSettings,
                  tooltip: 'Settings',
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.settings_outlined, size: 19),
                  color: AppTheme.resolve(context, _maroon),
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          style: TextStyle(
            color: AppTheme.resolve(context, _muted),
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _surface, fill: true),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.resolve(context, _border)),
      ),
      child: Row(
        children: [
          _ProfileAvatar(profile: _profile, selectedPhoto: null, size: 50),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.resolve(context, _text),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  _profile.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.resolve(context, _muted),
                    fontSize: 12.5,
                  ),
                ),

                if (_profile.phone.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),

                  Text(
                    _profile.phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.resolve(context, _muted2),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveContent() {
    switch (_activeTab) {
      case BuyerAccountTab.profile:
        return _buildProfileSection();

      case BuyerAccountTab.accountSecurity:
        return _buildAccountSecuritySection();

      case BuyerAccountTab.addresses:
        return _buildAddressesSection();

      case BuyerAccountTab.vouchers:
        return _AccountPanel(
          title: 'Vouchers',
          subtitle: 'View and use your available discounts and deals.',
          icon: Icons.confirmation_number_outlined,
          child: FilledButton.icon(
            onPressed: widget.onVouchers,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open Vouchers'),
          ),
        );

      case BuyerAccountTab.followingStores:
        return _AccountPanel(
          title: 'Following Stores',
          subtitle: 'Browse the stores you follow.',
          icon: Icons.storefront_outlined,
          child: FilledButton.icon(
            onPressed: widget.onFollowingStores,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open Following Stores'),
          ),
        );

      case BuyerAccountTab.wallet:
        return _buildWalletSection();

      case BuyerAccountTab.password:
        return _buildPasswordSection();

      case BuyerAccountTab.settings:
        return _AccountPanel(
          title: 'System Settings',
          subtitle: 'Manage app appearance, sounds, notifications, and AI.',
          icon: Icons.settings_outlined,
          child: FilledButton.icon(
            onPressed: widget.onSystemSettings,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open System Settings'),
          ),
        );

      case BuyerAccountTab.recentlyViewed:
        return _AccountPanel(
          title: 'Recently Viewed',
          subtitle: 'Products you viewed',
          icon: Icons.visibility_outlined,
          child: FilledButton(
            onPressed: widget.onRecentlyViewed,
            child: const Text('Open Recently Viewed'),
          ),
        );

      case BuyerAccountTab.dangerZone:
        return _buildDangerZoneSection();
    }
  }

  Future<void> _loadRefundDestinations() async {
    final LoadBuyerRefundDestinationsCallback? callback =
        widget.onLoadRefundDestinations;
    if (callback == null) {
      setState(() {
        _refundDestinationsLoaded = false;
        _refundDestinationError =
            'Refund destinations are unavailable while the buyer API is disconnected.';
      });
      return;
    }
    if (_loadingRefundDestinations) return;
    setState(() {
      _loadingRefundDestinations = true;
      _refundDestinationError = null;
    });
    try {
      final List<BuyerRefundDestination> destinations = await callback();
      if (!mounted) return;
      setState(() {
        _refundDestinations = destinations;
        _refundDestinationsLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _refundDestinationError = _errorText(error));
    } finally {
      if (mounted) setState(() => _loadingRefundDestinations = false);
    }
  }

  Future<void> _mutateRefundDestination(
    BuyerRefundDestinationMutation mutation,
  ) async {
    final BuyerRefundDestinationMutationCallback? callback =
        widget.onMutateRefundDestination;
    if (_savingRefundDestination) return;
    if (callback == null) {
      setState(() {
        _refundDestinationError =
            'Refund destinations are unavailable while the buyer API is disconnected.';
      });
      return;
    }
    setState(() {
      _savingRefundDestination = true;
      _refundDestinationError = null;
    });
    try {
      final List<BuyerRefundDestination> destinations = await callback(
        mutation,
      );
      if (!mounted) return;
      setState(() {
        _refundDestinations = destinations;
        _refundDestinationsLoaded = true;
      });
      if (mutation.action == 'add' || mutation.action == 'update') {
        setState(_resetRefundDestinationForm);
      }
      _showMessage(
        mutation.action == 'remove'
            ? 'Refund destination removed.'
            : mutation.action == 'set_default'
            ? 'Default refund destination updated.'
            : 'Refund destination saved securely.',
      );
    } catch (error) {
      if (mounted) setState(() => _refundDestinationError = _errorText(error));
    } finally {
      if (mounted) setState(() => _savingRefundDestination = false);
    }
  }

  void _editRefundDestination(BuyerRefundDestination destination) {
    setState(() {
      _editingRefundDestinationId = destination.id;
      _refundMethod = destination.method;
      _refundAccountType = destination.accountType;
      _refundBankController.text = destination.bankName ?? '';
      _refundNameController.text = destination.accountName;
      _refundNumberController.clear();
      _refundMakeDefault = destination.isDefault;
    });
  }

  void _resetRefundDestinationForm() {
    _editingRefundDestinationId = null;
    _refundMethod = 'GCash';
    _refundAccountType = 'MOBILE_NUMBER';
    _refundBankController.clear();
    _refundNameController.clear();
    _refundNumberController.clear();
    _refundMakeDefault = _refundDestinations.isEmpty;
  }

  Future<void> _saveRefundDestination() async {
    if (_savingRefundDestination ||
        !_refundDestinationFormKey.currentState!.validate()) {
      return;
    }
    await _mutateRefundDestination(
      BuyerRefundDestinationMutation(
        action: _editingRefundDestinationId == null ? 'add' : 'update',
        destinationId: _editingRefundDestinationId,
        method: _refundMethod,
        bankName: _refundMethod == 'Bank Transfer'
            ? _refundBankController.text.trim()
            : null,
        accountName: _refundNameController.text.trim(),
        accountType: _refundAccountType,
        accountNumber: _refundNumberController.text.trim(),
        makeDefault: _refundMakeDefault,
      ),
    );
  }

  Future<void> _removeRefundDestination(
    BuyerRefundDestination destination,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Remove refund destination?'),
        content: Text(
          'Remove ${destination.method} ending in ${destination.maskedNumber.split(' ').last}?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _mutateRefundDestination(
        BuyerRefundDestinationMutation(
          action: 'remove',
          destinationId: destination.id,
        ),
      );
    }
  }

  Widget _buildWalletSection() {
    return _AccountPanel(
      title: 'Wallet',
      subtitle:
          'Save a GCash, Maya, or bank account as your destination for future digital refunds.',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAEB),
              border: Border.all(color: const Color(0xFFFED766)),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Text(
              'Online checkout remains disabled; new purchases use Cash on Delivery. Current return and refund requests use the cash refund process after approval, return receipt, and inspection. Saved account details are reserved for future digital refunds.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingRefundDestinations && !_refundDestinationsLoaded)
            const Padding(
              padding: EdgeInsets.all(22),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_refundDestinationError != null)
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppTheme.resolve(context, _soft, fill: true),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _refundDestinationError!,
                    style: TextStyle(color: AppTheme.resolve(context, _danger)),
                  ),
                  TextButton.icon(
                    onPressed: _loadingRefundDestinations
                        ? null
                        : _loadRefundDestinations,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            )
          else if (_refundDestinations.isEmpty)
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppTheme.resolve(context, _soft, fill: true),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.resolve(context, _border)),
              ),
              child: const Text(
                'No refund destinations saved yet. Add one below; it will become the default automatically.',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            )
          else ...<Widget>[
            for (final BuyerRefundDestination destination
                in _refundDestinations) ...<Widget>[
              _buildRefundDestinationTile(destination),
              const SizedBox(height: 9),
            ],
          ],
          const SizedBox(height: 14),
          Form(
            key: _refundDestinationFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _editingRefundDestinationId == null
                      ? 'Add a refund destination'
                      : 'Update refund destination',
                  style: TextStyle(
                    color: AppTheme.resolve(context, _text),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_editingRefundDestinationId != null) ...<Widget>[
                  const SizedBox(height: 5),
                  Text(
                    'Re-enter the account number to save changes.',
                    style: TextStyle(
                      color: AppTheme.resolve(context, _muted),
                      fontSize: 11.5,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _refundMethod,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Refund destination method',
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                    DropdownMenuItem(value: 'Maya', child: Text('Maya')),
                    DropdownMenuItem(
                      value: 'Bank Transfer',
                      child: Text('Bank Transfer'),
                    ),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: _savingRefundDestination
                      ? null
                      : (String? value) {
                          if (value == null) return;
                          setState(() {
                            _refundMethod = value;
                            if (value == 'GCash' || value == 'Maya') {
                              _refundAccountType = 'MOBILE_NUMBER';
                            } else if (value == 'Bank Transfer') {
                              _refundAccountType = 'ACCOUNT_NUMBER';
                            }
                          });
                        },
                ),
                if (_refundMethod == 'Bank Transfer') ...<Widget>[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _refundBankController,
                    decoration: const InputDecoration(labelText: 'Bank name'),
                    validator: (String? value) =>
                        value == null || value.trim().isEmpty
                        ? 'Enter your bank name.'
                        : null,
                  ),
                ],
                const SizedBox(height: 10),
                TextFormField(
                  controller: _refundNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Account holder name',
                  ),
                  validator: (String? value) =>
                      value == null || value.trim().isEmpty
                      ? 'Enter the name on the account.'
                      : null,
                ),
                if (_refundMethod == 'Other') ...<Widget>[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _refundAccountType,
                    decoration: const InputDecoration(labelText: 'Number type'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'MOBILE_NUMBER',
                        child: Text('Mobile number'),
                      ),
                      DropdownMenuItem(
                        value: 'ACCOUNT_NUMBER',
                        child: Text('Account number'),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() => _refundAccountType = value);
                      }
                    },
                  ),
                ],
                const SizedBox(height: 10),
                TextFormField(
                  controller: _refundNumberController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _refundAccountType == 'MOBILE_NUMBER'
                        ? 'Mobile number'
                        : 'Account number',
                    hintText: _refundAccountType == 'MOBILE_NUMBER'
                        ? '09XX XXX XXXX or +63 9XX XXX XXXX'
                        : '6 to 20 digits',
                  ),
                  validator: (String? value) {
                    final String number = (value ?? '').replaceAll(
                      RegExp(r'[\s().-]+'),
                      '',
                    );
                    if (_refundAccountType == 'MOBILE_NUMBER') {
                      return RegExp(
                            r'^(?:09\d{9}|\+639\d{9}|639\d{9})$',
                          ).hasMatch(number)
                          ? null
                          : 'Enter a valid Philippine mobile number.';
                    }
                    return RegExp(r'^\d{6,20}$').hasMatch(number)
                        ? null
                        : 'Enter an account number with 6 to 20 digits.';
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _refundMakeDefault,
                  onChanged: (bool? value) =>
                      setState(() => _refundMakeDefault = value ?? false),
                  title: const Text(
                    'Set as default for future digital refunds',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.resolve(context, _soft, fill: true),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.resolve(context, _border),
                    ),
                  ),
                  child: const Text(
                    'Your saved account details are private and encrypted. Card numbers and security codes are never collected.',
                    style: TextStyle(fontSize: 11.5, height: 1.45),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    if (_editingRefundDestinationId != null)
                      TextButton(
                        onPressed: _savingRefundDestination
                            ? null
                            : () => setState(_resetRefundDestinationForm),
                        child: const Text('Cancel edit'),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _savingRefundDestination
                          ? null
                          : _saveRefundDestination,
                      icon: _savingRefundDestination
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _editingRefundDestinationId == null
                            ? 'Save refund destination'
                            : 'Update destination',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundDestinationTile(BuyerRefundDestination destination) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _surface, fill: true),
        border: Border.all(color: AppTheme.resolve(context, _border)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.account_balance_wallet_outlined,
                color: AppTheme.resolve(context, _maroon),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  destination.method,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (destination.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.resolve(
                      context,
                      ShopColors.accentSoft,
                      fill: true,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'DEFAULT',
                    style: TextStyle(
                      color: AppTheme.resolve(context, _maroon),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${destination.accountName} · ${destination.maskedNumber}',
            style: TextStyle(
              color: AppTheme.resolve(context, _muted),
              fontSize: 12,
            ),
          ),
          if (destination.bankName?.isNotEmpty == true) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              destination.bankName!,
              style: TextStyle(
                color: AppTheme.resolve(context, _muted2),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 5),
          Wrap(
            spacing: 4,
            runSpacing: 0,
            children: <Widget>[
              if (!destination.isDefault)
                TextButton(
                  onPressed: _savingRefundDestination
                      ? null
                      : () => _mutateRefundDestination(
                          BuyerRefundDestinationMutation(
                            action: 'set_default',
                            destinationId: destination.id,
                          ),
                        ),
                  child: const Text('Set as default'),
                ),
              TextButton(
                onPressed: _savingRefundDestination
                    ? null
                    : () => _editRefundDestination(destination),
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: _savingRefundDestination
                    ? null
                    : () => _removeRefundDestination(destination),
                style: TextButton.styleFrom(foregroundColor: _danger),
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZoneSection() {
    return _AccountPanel(
      title: 'Account Deletion',
      subtitle: 'Close your LIKHAE Buyer account.',
      icon: Icons.warning_amber_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F1),
              border: Border.all(color: const Color(0xFFFFCACA)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'This action cannot be undone',
                  style: TextStyle(
                    color: Color(0xFFB42318),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'This securely deactivates your account and signs you out. Historical orders are retained to protect fulfilment and payment records. Active orders must be completed or cancelled first.',
                  style: TextStyle(
                    color: Color(0xFFB42318),
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onDeleteAccount == null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Account closure is unavailable while the buyer API is disconnected.',
              style: TextStyle(color: AppTheme.resolve(context, _muted)),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 14),
            TextField(
              controller: _deleteAccountPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm your password',
              ),
            ),
            const SizedBox(height: 11),
            TextField(
              controller: _deleteAccountConfirmationController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Type DELETE to confirm',
              ),
            ),
            if (_deleteAccountError != null) ...<Widget>[
              const SizedBox(height: 9),
              Text(
                _deleteAccountError!,
                style: TextStyle(color: AppTheme.resolve(context, _danger)),
              ),
            ],
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _deletingAccount ? null : _deleteAccount,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.resolve(
                    context,
                    _danger,
                    fill: true,
                  ),
                ),
                icon: _deletingAccount
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person_off_outlined),
                label: const Text('Close My Account'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadOnlyProfileField(String label, String value) {
    final String displayValue = value.trim().isEmpty
        ? 'Not provided'
        : value.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _soft, fill: true),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.resolve(context, _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.resolve(context, _muted),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            style: TextStyle(
              color: AppTheme.resolve(context, _text),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccountPanel(
          title: 'Profile Information',
          subtitle: 'Your buyer details are view-only.',
          icon: Icons.person_outline_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: _ProfileAvatar(
                  profile: _profile,
                  selectedPhoto: null,
                  size: 82,
                ),
              ),
              const SizedBox(height: 16),
              _buildReadOnlyProfileField('Full name', _profile.name),
              _buildReadOnlyProfileField('Email address', _profile.email),
              _buildReadOnlyProfileField('Mobile number', _profile.phone),
              _buildReadOnlyProfileField(
                'Middle initial',
                _profile.middleInitial ?? '',
              ),
              _buildReadOnlyProfileField(
                'Date of birth',
                _profile.birthday == null
                    ? ''
                    : _formatDate(_profile.birthday!),
              ),
              _buildReadOnlyProfileField(
                'Gender',
                _profile.gender?.label ?? '',
              ),
              if (widget.accountActive != null)
                _buildReadOnlyProfileField(
                  'Account status',
                  widget.accountActive! ? 'Active' : 'Inactive',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccountPanel(
          title: 'Edit Information',
          subtitle: 'Keep your contact and profile details up to date.',
          icon: Icons.person_outline_rounded,
          child: Form(
            key: _accountSecurityFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      _ProfileAvatar(
                        profile: _profile,
                        selectedPhoto: _securitySelectedPhoto,
                        size: 82,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _savingAccountSecurity
                                ? null
                                : _pickAccountSecurityPhoto,
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Change Photo'),
                          ),
                          if (_securitySelectedPhoto != null ||
                              (_profile.profilePhotoUrl?.isNotEmpty ?? false))
                            TextButton.icon(
                              onPressed: _savingAccountSecurity
                                  ? null
                                  : _removeAccountSecurityPhoto,
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Remove'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JPG, PNG, or WebP up to 2 MB.',
                        style: TextStyle(
                          color: AppTheme.resolve(context, _muted),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _FieldLabel(text: 'Full name', requiredField: true),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _securityNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hintText: 'First and last name',
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                  validator: (String? value) {
                    final List<String> parts = (value ?? '')
                        .trim()
                        .split(RegExp(r'\s+'))
                        .where((String part) => part.isNotEmpty)
                        .toList(growable: false);
                    if (parts.length < 2 ||
                        parts.first.length < 2 ||
                        parts.last.length < 2) {
                      return 'Enter your first and last name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                const _FieldLabel(text: 'Email address', requiredField: true),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _securityEmailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hintText: 'Email address',
                    prefixIcon: Icons.email_outlined,
                  ),
                  validator: (String? value) {
                    final String email = (value ?? '').trim();
                    if (!RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch(email)) {
                      return 'Enter a valid email address.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                const _FieldLabel(text: 'Mobile number', requiredField: true),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _securityPhoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hintText: '09XXXXXXXXX',
                    prefixIcon: Icons.phone_outlined,
                  ),
                  validator: (String? value) => (value ?? '').trim().isEmpty
                      ? 'Enter your mobile number.'
                      : null,
                ),
                const SizedBox(height: 14),
                const _FieldLabel(text: 'Date of birth'),
                const SizedBox(height: 7),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickAccountSecurityBirthday,
                  child: InputDecorator(
                    decoration: _inputDecoration(
                      hintText: 'Choose date of birth',
                      prefixIcon: Icons.calendar_month_outlined,
                    ),
                    child: Text(
                      _securityBirthday == null
                          ? 'Choose date of birth'
                          : _formatDate(_securityBirthday!),
                      style: TextStyle(
                        color: AppTheme.resolve(
                          context,
                          _securityBirthday == null ? _muted2 : _text,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const _FieldLabel(text: 'Gender'),
                const SizedBox(height: 7),
                DropdownButtonFormField<BuyerGender>(
                  value: _securityGender,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    hintText: 'Choose gender',
                    prefixIcon: Icons.people_outline_rounded,
                  ),
                  items: BuyerGender.values
                      .map(
                        (BuyerGender gender) => DropdownMenuItem<BuyerGender>(
                          value: gender,
                          child: Text(gender.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (BuyerGender? value) {
                    setState(() => _securityGender = value);
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 49,
                  child: ElevatedButton(
                    onPressed: _savingAccountSecurity
                        ? null
                        : _saveAccountSecurity,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppTheme.resolve(
                        context,
                        _maroon,
                        fill: true,
                      ),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: _savingAccountSecurity
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Information',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildPasswordSection(),
      ],
    );
  }

  Future<void> _pickAccountSecurityPhoto() async {
    final PickProfilePhotoCallback? callback = widget.onPickProfilePhoto;
    if (callback == null) {
      _showMessage('Profile photo editing is unavailable right now.');
      return;
    }
    try {
      final SelectedProfilePhoto? photo = await callback();
      if (!mounted || photo == null) return;
      if (photo.bytes.isEmpty || photo.sizeInBytes > 2 * 1024 * 1024) {
        _showMessage('Choose an image up to 2 MB.', error: true);
        return;
      }
      setState(() => _securitySelectedPhoto = photo);
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    }
  }

  Future<void> _removeAccountSecurityPhoto() async {
    if (_securitySelectedPhoto != null) {
      setState(() => _securitySelectedPhoto = null);
      return;
    }
    final RemoveProfilePhotoCallback? callback = widget.onRemoveProfilePhoto;
    if (callback == null) {
      _showMessage('Profile photo removal is unavailable right now.');
      return;
    }
    setState(() => _savingAccountSecurity = true);
    try {
      final BuyerProfileData updated = await callback();
      if (!mounted) return;
      _setSecurityProfile(updated);
      _showMessage('Profile photo removed.');
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _savingAccountSecurity = false);
    }
  }

  Future<void> _pickAccountSecurityBirthday() async {
    final DateTime now = DateTime.now();
    final DateTime initial = _securityBirthday == null ||
            _securityBirthday!.isAfter(now)
        ? DateTime(now.year - 18, now.month, now.day)
        : _securityBirthday!;
    final DateTime? birthday = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (birthday != null && mounted) {
      setState(() => _securityBirthday = birthday);
    }
  }

  Future<void> _saveAccountSecurity() async {
    FocusScope.of(context).unfocus();
    if (_savingAccountSecurity ||
        !(_accountSecurityFormKey.currentState?.validate() ?? false)) {
      return;
    }
    final UpdateBuyerProfileCallback? callback = widget.onUpdateProfile;
    if (callback == null) {
      _showMessage(
        'Profile editing is unavailable while the buyer API is disconnected.',
      );
      return;
    }
    setState(() => _savingAccountSecurity = true);
    try {
      final String requestedEmail = _securityEmailController.text.trim();
      if (requestedEmail.toLowerCase() != _profile.email.trim().toLowerCase()) {
        final RequestBuyerEmailChangeCallback? requestEmail =
            widget.onRequestEmailChange;
        final VerifyBuyerEmailChangeCallback? verifyEmail =
            widget.onVerifyEmailChange;
        if (requestEmail == null || verifyEmail == null) {
          throw Exception('Email changes are unavailable right now.');
        }
        await requestEmail(requestedEmail);
        final String? code = await _requestSecurityVerificationCode(
          title: 'Verify email address',
          message:
              'Enter the six-digit code sent to $requestedEmail to confirm the new email address.',
          onResend: widget.onResendEmailChangeCode,
        );
        if (code == null) return;
        final BuyerProfileData updatedEmail = await verifyEmail(code);
        if (!mounted) return;
        setState(() {
          _profile = updatedEmail;
          _securityEmailController.text = updatedEmail.email;
        });
        widget.onProfileChanged?.call(updatedEmail);
      }

      final UpdateBuyerProfileRequest request = UpdateBuyerProfileRequest(
        name: _securityNameController.text.trim(),
        email: _profile.email,
        phone: _securityPhoneController.text.trim(),
        birthday: _securityBirthday,
        gender: _securityGender,
        profilePhoto: _securitySelectedPhoto,
      );
      late final BuyerProfileData updated;
      try {
        updated = await callback(request);
      } on BuyerProfileVerificationRequiredException catch (verification) {
        final String? code = await _requestSecurityVerificationCode(
          title: 'Verify mobile number',
          message: verification.message,
          onResend: widget.onResendMobileChangeCode,
        );
        if (code == null) return;
        updated = await callback(
          UpdateBuyerProfileRequest(
            name: request.name,
            email: request.email,
            phone: request.phone,
            birthday: request.birthday,
            gender: request.gender,
            profilePhoto: request.profilePhoto,
            mobileChangeCode: code,
          ),
        );
      }
      if (!mounted) return;
      _setSecurityProfile(updated);
      _showMessage('Account information updated.');
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _savingAccountSecurity = false);
    }
  }

  void _setSecurityProfile(BuyerProfileData profile) {
    setState(() {
      _profile = profile;
      _securityNameController.text = profile.name;
      _securityEmailController.text = profile.email;
      _securityPhoneController.text = profile.phone;
      _securityBirthday = profile.birthday;
      _securityGender = profile.gender;
      _securitySelectedPhoto = null;
    });
    widget.onProfileChanged?.call(profile);
  }

  Future<String?> _requestSecurityVerificationCode({
    required String title,
    required String message,
    ResendBuyerMobileChangeCodeCallback? onResend,
  }) async {
    final TextEditingController codeController = TextEditingController();
    bool resending = false;
    String? resendMessage;
    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => StatefulBuilder(
          builder:
              (BuildContext dialogContext, StateSetter setDialogState) =>
                  AlertDialog(
                    title: Text(title),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(message),
                        const SizedBox(height: 14),
                        TextField(
                          controller: codeController,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: '6-digit verification code',
                            counterText: '',
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        if (resendMessage != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            resendMessage!,
                            style: TextStyle(
                              color: AppTheme.resolve(context, _muted),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: resending
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                        child: const Text('Cancel'),
                      ),
                      if (onResend != null)
                        TextButton(
                          onPressed: resending
                              ? null
                              : () async {
                                  setDialogState(() {
                                    resending = true;
                                    resendMessage = null;
                                  });
                                  try {
                                    await onResend();
                                    setDialogState(() {
                                      resendMessage = 'A new code was sent.';
                                    });
                                  } catch (error) {
                                    setDialogState(() {
                                      resendMessage = _errorText(error);
                                    });
                                  } finally {
                                    setDialogState(() => resending = false);
                                  }
                                },
                          child: Text(resending ? 'Sending...' : 'Resend'),
                        ),
                      FilledButton(
                        onPressed: codeController.text.trim().length == 6
                            ? () => Navigator.of(
                                dialogContext,
                              ).pop(codeController.text.trim())
                            : null,
                        child: const Text('Verify'),
                      ),
                    ],
                  ),
        ),
      );
    } finally {
      codeController.dispose();
    }
  }

  Future<void> _deleteAccount() async {
    final DeleteBuyerAccountCallback? callback = widget.onDeleteAccount;
    if (callback == null) return;
    if (_deleteAccountConfirmationController.text.trim() != 'DELETE') {
      setState(() => _deleteAccountError = 'Type DELETE to confirm.');
      return;
    }
    if (_deleteAccountPasswordController.text.isEmpty) {
      setState(() => _deleteAccountError = 'Enter your current password.');
      return;
    }
    setState(() {
      _deletingAccount = true;
      _deleteAccountError = null;
    });
    try {
      await callback(
        _deleteAccountPasswordController.text,
        _deleteAccountConfirmationController.text.trim(),
      );
      if (mounted && widget.onLogout != null) {
        await widget.onLogout!();
      }
    } catch (error) {
      if (mounted) setState(() => _deleteAccountError = _errorText(error));
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  Widget _buildAddressesSection() {
    return _AccountPanel(
      title: 'Delivery Addresses',
      subtitle:
          'Saved addresses are used for future checkouts. Existing orders keep their original delivery details.',
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AccountTip(
            icon: Icons.location_on_outlined,
            title: 'Delivery tip',
            message:
                'Add a complete delivery address before placing an order for a smoother checkout.',
          ),

          const SizedBox(height: 12),

          if (_addresses.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.resolve(context, _soft, fill: true),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    color: AppTheme.resolve(context, _muted2),
                    size: 30,
                  ),

                  SizedBox(height: 9),

                  Text(
                    'No saved delivery address yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.resolve(context, _muted),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._addresses.map((BuyerAddressData address) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AddressCard(
                  address: address,
                  deleting: _deletingAddressIds.contains(address.id),
                  settingDefault: _defaultingAddressIds.contains(address.id),
                  onSetDefault: () => _setDefaultAddress(address),
                  onEdit: () => _editAddress(address),
                  onDelete: () {
                    _deleteAddress(address);
                  },
                ),
              );
            }),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              color: AppTheme.resolve(context, Colors.white, fill: true),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Form(
              key: _addressFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _editingAddressId == null
                        ? 'Add delivery address'
                        : 'Edit delivery address',
                    style: TextStyle(
                      color: AppTheme.resolve(context, ShopColors.text),
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Choose a precise location so the courier can find you.',
                    style: TextStyle(
                      color: AppTheme.resolve(context, ShopColors.muted),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 18),

                  _AddressInput(
                    label: 'Address label',
                    controller: _addressLabelController,
                    hint: 'Home, Work',
                    prefixIcon: Icons.bookmark_outline_rounded,
                    requiredField: true,
                    maxLength: 50,
                  ),

                  _AddressInput(
                    label: 'Recipient name',
                    controller: _recipientNameController,
                    hint: 'Recipient full name',
                    prefixIcon: Icons.person_outline_rounded,
                    requiredField: true,
                    maxLength: 200,
                  ),

                  _AddressInput(
                    label: 'Recipient contact number',
                    controller: _addressPhoneController,
                    hint: 'e.g. 0917 123 4567',
                    prefixIcon: Icons.phone_outlined,
                    requiredField: true,
                    keyboardType: TextInputType.phone,
                    maxLength: 30,
                  ),

                  _buildAddressLocationField(),

                  _AddressInput(
                    label: 'House / Unit Number',
                    controller: _houseNumberController,
                    hint: 'House or unit number',
                    prefixIcon: Icons.home_work_outlined,
                    maxLength: 100,
                  ),

                  _AddressInput(
                    label: 'Street / Purok',
                    controller: _streetController,
                    hint: 'Street or purok',
                    prefixIcon: Icons.home_outlined,
                    requiredField: true,
                    maxLength: 255,
                  ),

                  _AddressInput(
                    label:
                        'Building / Subdivision, Landmark / Additional Details',
                    controller: _landmarkController,
                    hint: 'Building, subdivision, or nearby landmark',
                    prefixIcon: Icons.flag_outlined,
                    maxLength: 255,
                  ),

                  const SizedBox(height: 20),

                  _buildAddressPinSection(),

                  const SizedBox(height: 12),

                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _addingAddress
                          ? null
                          : () {
                              setState(() {
                                _newAddressIsDefault = !_newAddressIsDefault;
                              });
                            },
                      borderRadius: BorderRadius.circular(11),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _newAddressIsDefault,
                              activeColor: AppTheme.resolve(context, _maroon),
                              onChanged: _addingAddress
                                  ? null
                                  : (bool? value) {
                                      setState(() {
                                        _newAddressIsDefault = value ?? false;
                                      });
                                    },
                            ),

                            Expanded(
                              child: Text(
                                'Set as default address',
                                style: TextStyle(
                                  color: AppTheme.resolve(context, _text),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 49,
                    child: ElevatedButton(
                      onPressed: _addingAddress ? null : _addAddress,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppTheme.resolve(
                          context,
                          _maroon,
                          fill: true,
                        ),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: _addingAddress
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _editingAddressId == null
                                  ? 'Save Address'
                                  : 'Update Address',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  if (_editingAddressId != null) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _addingAddress
                          ? null
                          : () => setState(_resetAddressForm),
                      child: const Text('Cancel editing'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressPinSection() {
    final LatLng? selectedLocation = _selectedAddressLocation;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _surface, fill: true),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.resolve(context, _border)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirm location',
                  style: TextStyle(
                    color: AppTheme.resolve(context, _brown),
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Search your barangay or address, then adjust the pin to the exact location for the rider.',
                  style: TextStyle(
                    color: AppTheme.resolve(context, _muted),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    OutlinedButton(
                      onPressed: _findingAddress || _usingDeviceLocation
                          ? null
                          : _findAddress,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.resolve(context, _maroon),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(
                          color: AppTheme.resolve(context, _border),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _findingAddress
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Search & pin',
                              style: TextStyle(fontSize: 11.5),
                            ),
                    ),
                    OutlinedButton(
                      onPressed: _findingAddress || _usingDeviceLocation
                          ? null
                          : _useDeviceLocation,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.resolve(context, _maroon),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(
                          color: AppTheme.resolve(context, _border),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _usingDeviceLocation
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Use device location',
                              style: TextStyle(fontSize: 11.5),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressSearchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _findAddress(),
                  decoration: _inputDecoration(
                    hintText: 'Search barangay, street, landmark, or address',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 230,
            child: _canShowAddressMap
                ? maplibre.MapLibreMapWidget(
                    viewport: maplibre.MapLibreViewport(
                      center: _toMapLibrePoint(_addressMapCenter),
                      zoom: _addressMapZoom,
                    ),
                    onMapCreated: _onAddressMapCreated,
                    onTapListener: _onAddressMapTap,
                  )
                : Container(
                    color: AppTheme.resolve(
                      context,
                      const Color(0xFFF7F2EE),
                      fill: true,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      kIsWeb
                          ? 'The interactive address map is available on Android, iOS, and web.'
                          : 'Interactive address maps are unavailable on this device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.resolve(context, _muted),
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Text(
              selectedLocation == null
                  ? 'Tap the map, search your barangay, or use device location to pin the delivery point.'
                  : 'Pinned for rider: ${selectedLocation.latitude.toStringAsFixed(6)}, ${selectedLocation.longitude.toStringAsFixed(6)}',
              style: TextStyle(
                color: AppTheme.resolve(context, _muted),
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
          if (_addressLocationMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                _addressLocationMessage!,
                style: TextStyle(
                  color: AppTheme.resolve(
                    context,
                    selectedLocation == null ? _danger : _muted,
                  ),
                  fontSize: 11.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return _AccountPanel(
      title: 'Change Password',
      subtitle: 'Enter your current password before setting a new one.',
      icon: Icons.lock_outline_rounded,
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FieldLabel(text: 'Current password'),

            const SizedBox(height: 7),

            TextFormField(
              controller: _currentPasswordController,
              obscureText: !_showCurrentPassword,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.password],
              decoration: _passwordDecoration(
                hintText: 'Current password',
                visible: _showCurrentPassword,
                onToggle: () {
                  setState(() {
                    _showCurrentPassword = !_showCurrentPassword;
                  });
                },
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Enter your current password.';
                }

                return null;
              },
            ),

            const SizedBox(height: 15),

            const _FieldLabel(text: 'New password'),

            const SizedBox(height: 7),

            TextFormField(
              controller: _newPasswordController,
              obscureText: !_showNewPassword,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              decoration: _passwordDecoration(
                hintText: 'New password',
                visible: _showNewPassword,
                onToggle: () {
                  setState(() {
                    _showNewPassword = !_showNewPassword;
                  });
                },
              ),
              validator: (String? value) {
                final String password = value ?? '';

                if (password.isEmpty) {
                  return 'Enter a new password.';
                }

                if (password.length < 8) {
                  return 'Use at least 8 characters.';
                }

                if (password.length > 72) {
                  return 'Password must not exceed 72 characters.';
                }

                if (password == _currentPasswordController.text) {
                  return 'Choose a password different from your current one.';
                }

                if (!RegExp(r'[a-z]').hasMatch(password) ||
                    !RegExp(r'[A-Z]').hasMatch(password) ||
                    !RegExp(r'\d').hasMatch(password) ||
                    !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
                  return 'Include uppercase and lowercase letters, a number, and a symbol.';
                }

                return null;
              },
            ),

            const SizedBox(height: 15),

            const _FieldLabel(text: 'Confirm new password'),

            const SizedBox(height: 7),

            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.newPassword],
              decoration: _passwordDecoration(
                hintText: 'Confirm new password',
                visible: _showConfirmPassword,
                onToggle: () {
                  setState(() {
                    _showConfirmPassword = !_showConfirmPassword;
                  });
                },
              ),
              onFieldSubmitted: (_) {
                if (!_changingPassword) {
                  _changePassword();
                }
              },
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Confirm your new password.';
                }

                if (value != _newPasswordController.text) {
                  return 'Passwords do not match.';
                }

                return null;
              },
            ),

            const SizedBox(height: 17),

            const _AccountTip(
              icon: Icons.shield_outlined,
              title: 'Security tip',
              message:
                  'Use 8–72 characters with uppercase and lowercase letters, a number, and a symbol. Choose a password different from your current one, confirm it below, and keep it private.',
            ),

            const SizedBox(height: 18),

            SizedBox(
              height: 49,
              child: ElevatedButton(
                onPressed: _changingPassword ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: AppTheme.resolve(
                    context,
                    _maroon,
                    fill: true,
                  ),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: _changingPassword
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Update Password',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: AppTheme.resolve(context, _muted2),
        fontSize: 13.5,
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(
              prefixIcon,
              color: AppTheme.resolve(context, _muted),
              size: 19,
            ),
      filled: true,
      fillColor: AppTheme.resolve(context, _surface, fill: true),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: AppTheme.resolve(context, _border)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: AppTheme.resolve(context, _border)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(
          color: AppTheme.resolve(context, _maroon),
          width: 1.3,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: AppTheme.resolve(context, _danger)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(
          color: AppTheme.resolve(context, _danger),
          width: 1.3,
        ),
      ),
    );
  }

  InputDecoration _passwordDecoration({
    required String hintText,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    return _inputDecoration(
      hintText: hintText,
      prefixIcon: Icons.lock_outline_rounded,
    ).copyWith(
      suffixIcon: IconButton(
        tooltip: visible ? 'Hide password' : 'Show password',
        onPressed: onToggle,
        icon: Icon(
          visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: AppTheme.resolve(context, _muted),
          size: 19,
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');

    final String day = value.day.toString().padLeft(2, '0');

    return '${value.year}-$month-$day';
  }
}

class _AccountTip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _AccountTip({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, ShopColors.soft, fill: true),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.resolve(context, ShopColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppTheme.resolve(context, ShopColors.accent),
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.resolve(context, ShopColors.text),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    color: AppTheme.resolve(context, ShopColors.secondaryText),
                    fontSize: 12.5,
                    height: 1.5,
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

class _AccountStatusBadge extends StatelessWidget {
  final bool active;

  const _AccountStatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? AppTheme.resolve(context, const Color(0xFFEEF8F1), fill: true)
            : AppTheme.resolve(context, ShopColors.soft, fill: true),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: active
              ? AppTheme.resolve(context, const Color(0xFFCDE5D4))
              : AppTheme.resolve(context, ShopColors.border),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.resolve(
                      context,
                      const Color(0xFF256F4A),
                      fill: true,
                    )
                  : AppTheme.resolve(context, ShopColors.faint, fill: true),
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 5),

          Text(
            active ? 'Active' : 'Inactive',
            style: TextStyle(
              color: active
                  ? AppTheme.resolve(context, const Color(0xFF256F4A))
                  : AppTheme.resolve(context, ShopColors.muted),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountPanel extends StatelessWidget {
  final String title;
  final String subtitle;

  final IconData icon;

  final Widget child;

  const _AccountPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, ShopColors.surface, fill: true),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.resolve(context, ShopColors.border)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.resolve(
              context,
              ShopColors.accent,
            ).withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.resolve(
                      context,
                      ShopColors.accentSoft,
                      fill: true,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: AppTheme.resolve(context, ShopColors.accent),
                    size: 19,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.resolve(context, ShopColors.text),
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.resolve(context, ShopColors.muted),
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: AppTheme.resolve(context, ShopColors.border),
          ),

          Padding(padding: const EdgeInsets.all(15), child: child),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final BuyerProfileData profile;

  final SelectedProfilePhoto? selectedPhoto;

  final double size;

  const _ProfileAvatar({
    required this.profile,
    required this.selectedPhoto,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final SelectedProfilePhoto? local = selectedPhoto;

    final String? remote = profile.profilePhotoUrl?.trim();

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, ShopColors.accentSoft, fill: true),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.resolve(context, ShopColors.border)),
      ),
      child: local != null
          ? Image.memory(
              local.bytes,
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return _AvatarInitial(value: profile.initial);
                  },
            )
          : remote != null && remote.isNotEmpty
          ? SizedNetworkImage(
              url: remote,
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return _AvatarInitial(value: profile.initial);
                  },
              placeholder: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.resolve(context, ShopColors.accent),
                  ),
                ),
              ),
            )
          : _AvatarInitial(value: profile.initial),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  final String value;

  const _AvatarInitial({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: AppTheme.resolve(context, ShopColors.accentSoft, fill: true),
      child: Text(
        value,
        style: TextStyle(
          color: AppTheme.resolve(context, ShopColors.accent),
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final BuyerAddressData address;

  final bool deleting;
  final bool settingDefault;
  final VoidCallback onSetDefault;
  final VoidCallback onEdit;

  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    required this.deleting,
    required this.settingDefault,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: address.isDefault
            ? AppTheme.resolve(context, const Color(0xFFFFF4F0), fill: true)
            : AppTheme.resolve(context, ShopColors.surface, fill: true),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: address.isDefault
              ? AppTheme.resolve(context, const Color(0xFFD9B09D))
              : AppTheme.resolve(context, ShopColors.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: AppTheme.resolve(
                context,
                ShopColors.accentSoft,
                fill: true,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.location_on_outlined,
              color: AppTheme.resolve(context, ShopColors.accent),
              size: 19,
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${address.label} · ${address.recipientName}',
                      style: TextStyle(
                        color: AppTheme.resolve(context, ShopColors.text),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    if (address.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.resolve(
                            context,
                            ShopColors.accentSoft,
                            fill: true,
                          ),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'DEFAULT',
                          style: TextStyle(
                            color: AppTheme.resolve(context, ShopColors.accent),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),

                if (address.contactNumber.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),

                  Text(
                    address.contactNumber,
                    style: TextStyle(
                      color: AppTheme.resolve(
                        context,
                        ShopColors.secondaryText,
                      ),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 7),

                Text(
                  address.displayAddress.isEmpty
                      ? 'No formatted address available.'
                      : address.displayAddress,
                  style: TextStyle(
                    color: AppTheme.resolve(context, ShopColors.muted),
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),

                if (address.landmark?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 5),

                  Text(
                    'Landmark: ${address.landmark}',
                    style: TextStyle(
                      color: AppTheme.resolve(context, ShopColors.faint),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 6),

          Column(
            children: [
              IconButton(
                tooltip: 'Edit address',
                onPressed: deleting || settingDefault ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 19),
              ),
              if (!address.isDefault)
                TextButton(
                  onPressed: settingDefault ? null : onSetDefault,
                  child: settingDefault
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Set default'),
                ),
              IconButton(
                tooltip: 'Delete address',
                onPressed: deleting ? null : onDelete,
                icon: deleting
                    ? SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.resolve(context, Color(0xFFB42318)),
                        ),
                      )
                    : Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.resolve(context, Color(0xFFB42318)),
                        size: 19,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddressInput extends StatelessWidget {
  final String label;

  final TextEditingController controller;

  final String hint;

  final TextInputType keyboardType;

  final IconData? prefixIcon;

  final bool requiredField;

  final bool readOnly;

  final String? helperText;

  final bool helperTextError;

  final int maxLength;

  final ValueChanged<String>? onChanged;

  const _AddressInput({
    required this.label,
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.requiredField = false,
    this.readOnly = false,
    this.helperText,
    this.helperTextError = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(
        color: AppTheme.resolve(context, ShopColors.border),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel(text: label, requiredField: requiredField),
          const SizedBox(height: 7),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            readOnly: readOnly,
            onChanged: onChanged,
            textCapitalization:
                keyboardType == TextInputType.phone ||
                    keyboardType == TextInputType.number
                ? TextCapitalization.none
                : TextCapitalization.words,
            style: TextStyle(
              color: AppTheme.resolve(context, ShopColors.text),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AppTheme.resolve(context, ShopColors.faint),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: prefixIcon == null
                  ? null
                  : Icon(
                      prefixIcon,
                      color: AppTheme.resolve(context, ShopColors.muted),
                      size: 19,
                    ),
              helperText: helperText,
              helperStyle: TextStyle(
                color: helperTextError
                    ? AppTheme.resolve(context, const Color(0xFFD64A59))
                    : AppTheme.resolve(context, ShopColors.muted),
                fontSize: 12,
              ),
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: AppTheme.resolve(
                context,
                ShopColors.canvas,
                fill: true,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 15,
              ),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: BorderSide(
                  color: AppTheme.resolve(context, ShopColors.accent),
                  width: 1.3,
                ),
              ),
              errorBorder: border.copyWith(
                borderSide: BorderSide(
                  color: AppTheme.resolve(context, Color(0xFFD64A59)),
                ),
              ),
              focusedErrorBorder: border.copyWith(
                borderSide: BorderSide(
                  color: AppTheme.resolve(context, Color(0xFFD64A59)),
                  width: 1.3,
                ),
              ),
              errorStyle: TextStyle(
                color: AppTheme.resolve(context, Color(0xFFD64A59)),
                fontSize: 12,
                height: 1.3,
              ),
            ),
            validator: (String? value) {
              final String text = value?.trim() ?? '';

              if (requiredField && text.isEmpty) {
                return 'Please provide $label';
              }

              if (text.length > maxLength) {
                return 'Maximum $maxLength characters.';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  final bool requiredField;

  const _FieldLabel({required this.text, this.requiredField = true});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: text),

          if (requiredField)
            TextSpan(
              text: ' *',
              style: TextStyle(
                color: AppTheme.resolve(context, Color(0xFFB42318)),
              ),
            ),
        ],
      ),
      style: TextStyle(
        color: AppTheme.resolve(context, ShopColors.text),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final String message;

  final bool error;

  const _MessageBanner({required this.message, required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error
            ? AppTheme.resolve(context, const Color(0xFFFCECE7), fill: true)
            : AppTheme.resolve(context, const Color(0xFFEEF8F1), fill: true),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: error
              ? AppTheme.resolve(context, const Color(0xFFEBC9C0))
              : AppTheme.resolve(context, const Color(0xFFCDE5D4)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: error
                ? AppTheme.resolve(context, const Color(0xFFB42318))
                : AppTheme.resolve(context, const Color(0xFF256F4A)),
            size: 18,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: error
                    ? AppTheme.resolve(context, const Color(0xFFB42318))
                    : AppTheme.resolve(context, const Color(0xFF256F4A)),
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
