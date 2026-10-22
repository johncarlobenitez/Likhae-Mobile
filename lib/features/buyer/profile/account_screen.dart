import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/shop_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import '../../auth/register_screen.dart'
    show AddressLoader, AddressOption, ChildAddressLoader, PostalCodeLoader;

enum BuyerAccountTab { profile, addresses, vouchers, password, settings }

extension BuyerAccountTabInfo on BuyerAccountTab {
  String get label {
    switch (this) {
      case BuyerAccountTab.profile:
        return 'Profile';

      case BuyerAccountTab.addresses:
        return 'Addresses';

      case BuyerAccountTab.vouchers:
        return 'Vouchers';

      case BuyerAccountTab.password:
        return 'Change Password';

      case BuyerAccountTab.settings:
        return 'System Settings';
    }
  }

  String get description {
    switch (this) {
      case BuyerAccountTab.profile:
        return 'Personal information';

      case BuyerAccountTab.addresses:
        return 'Delivery locations';

      case BuyerAccountTab.vouchers:
        return 'Discounts and deals';

      case BuyerAccountTab.password:
        return 'Account security';

      case BuyerAccountTab.settings:
        return 'App preferences';
    }
  }

  IconData get icon {
    switch (this) {
      case BuyerAccountTab.profile:
        return Icons.person_outline_rounded;

      case BuyerAccountTab.addresses:
        return Icons.location_on_outlined;

      case BuyerAccountTab.vouchers:
        return Icons.confirmation_number_outlined;

      case BuyerAccountTab.password:
        return Icons.lock_outline_rounded;

      case BuyerAccountTab.settings:
        return Icons.settings_outlined;
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

  const BuyerAccountSnapshot({
    required this.profile,
    required this.addresses,
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

typedef ResendBuyerMobileChangeCodeCallback = Future<void> Function();

typedef RemoveProfilePhotoCallback = Future<BuyerProfileData> Function();

typedef AddBuyerAddressCallback =
    Future<BuyerAddressData> Function(CreateBuyerAddressRequest request);

typedef DeleteBuyerAddressCallback =
    Future<void> Function(BuyerAddressData address);

typedef SetDefaultBuyerAddressCallback =
    Future<void> Function(BuyerAddressData address);

typedef ChangeBuyerPasswordCallback =
    Future<void> Function(ChangeBuyerPasswordRequest request);

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

  final ResendBuyerMobileChangeCodeCallback? onResendMobileChangeCode;

  final RemoveProfilePhotoCallback? onRemoveProfilePhoto;

  final AddBuyerAddressCallback? onAddAddress;

  final AddressLoader? loadRegions;
  final ChildAddressLoader? loadProvinces;
  final ChildAddressLoader? loadMunicipalities;
  final ChildAddressLoader? loadBarangays;
  final PostalCodeLoader? loadPostalCode;

  final DeleteBuyerAddressCallback? onDeleteAddress;

  final SetDefaultBuyerAddressCallback? onSetDefaultAddress;

  final ChangeBuyerPasswordCallback? onChangePassword;

  final VoidCallback? onSystemSettings;

  final VoidCallback? onVouchers;

  /// When false, this account tab is rendered as a dedicated page without
  /// showing the Me-section navigation tiles again.
  final bool showNavigationTabs;

  final RefreshBuyerAccountCallback? onRefresh;

  final LogoutBuyerCallback? onLogout;

  /// Optional parent synchronization callbacks.
  final ValueChanged<BuyerProfileData>? onProfileChanged;

  final ValueChanged<List<BuyerAddressData>>? onAddressesChanged;

  final ValueChanged<BuyerAccountTab>? onTabChanged;

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
    this.onResendMobileChangeCode,
    this.onRemoveProfilePhoto,
    this.onAddAddress,
    this.loadRegions,
    this.loadProvinces,
    this.loadMunicipalities,
    this.loadBarangays,
    this.loadPostalCode,
    this.onDeleteAddress,
    this.onSetDefaultAddress,
    this.onChangePassword,
    this.onSystemSettings,
    this.onVouchers,
    this.showNavigationTabs = true,
    this.onRefresh,
    this.onLogout,
    this.onProfileChanged,
    this.onAddressesChanged,
    this.onTabChanged,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const String _mapboxAccessToken =
      String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

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

  static const int _maxProfilePhotoBytes = 2 * 1024 * 1024;

  late BuyerProfileData _profile;

  late List<BuyerAddressData> _addresses;

  late BuyerAccountTab _activeTab;

  SelectedProfilePhoto? _selectedPhoto;

  bool _savingProfile = false;
  bool _removingPhoto = false;

  bool _addingAddress = false;

  final Set<String> _deletingAddressIds = <String>{};
  final Set<String> _defaultingAddressIds = <String>{};

  bool _changingPassword = false;
  bool _refreshing = false;

  bool _loggingOut = false;

  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();

  final GlobalKey<FormState> _addressFormKey = GlobalKey<FormState>();

  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;

  late final TextEditingController _emailController;

  late final TextEditingController _phoneController;

  DateTime? _birthday;

  BuyerGender? _gender;

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
  final Dio _addressGeocoder = Dio();

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

  mapbox.MapboxMap? _addressMap;
  mapbox.CircleAnnotationManager? _addressMarkerManager;

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

    _newAddressIsDefault = _addresses.isEmpty;

    _nameController = TextEditingController(text: _profile.name);

    _emailController = TextEditingController(text: _profile.email);

    _phoneController = TextEditingController(text: _profile.phone);

    _birthday = _profile.birthday;

    _gender = _profile.gender;

    _addressLabelController = TextEditingController(text: 'Home');

    _recipientNameController = TextEditingController(text: _profile.name);

    _addressPhoneController = TextEditingController(text: _profile.phone);

    if (_activeTab == BuyerAccountTab.addresses) {
      unawaited(_loadAddressRegions());
    }
  }

  @override
  void didUpdateWidget(covariant AccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.profile != widget.profile) {
      final BuyerProfileData previousProfile = _profile;

      _profile = widget.profile;

      if (_nameController.text == previousProfile.name) {
        _nameController.text = _profile.name;
      }

      if (_emailController.text == previousProfile.email) {
        _emailController.text = _profile.email;
      }

      if (_phoneController.text == previousProfile.phone) {
        _phoneController.text = _profile.phone;
      }

      if (_birthday == previousProfile.birthday) _birthday = _profile.birthday;

      if (_gender == previousProfile.gender) _gender = _profile.gender;

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
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();

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
          mapbox.CameraOptions(
            center: _toMapboxPoint(location),
            zoom: _addressMapZoom,
          ),
        ),
      );
    }
  }

  bool get _canShowAddressMap {
    if (kIsWeb) {
      return false;
    }

    final bool supportedPlatform =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return supportedPlatform && _mapboxAccessToken.isNotEmpty;
  }

  Future<void> _onAddressMapCreated(mapbox.MapboxMap map) async {
    _addressMap = map;
    _addressMarkerManager =
        await map.annotations.createCircleAnnotationManager();
    await _syncAddressMarker();
  }

  Future<void> _syncAddressMarker() async {
    final mapbox.CircleAnnotationManager? manager = _addressMarkerManager;
    if (manager == null) {
      return;
    }

    await manager.deleteAll();

    final LatLng? location = _selectedAddressLocation;
    if (location == null) {
      return;
    }

    await manager.create(
      mapbox.CircleAnnotationOptions(
        geometry: _toMapboxPoint(location),
        circleColor: _maroon.toARGB32(),
        circleRadius: 11,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 3,
      ),
    );
  }

  void _onAddressMapTap(mapbox.MapContentGestureContext context) {
    _setAddressLocation(_fromMapboxPoint(context.point));
  }

  mapbox.Point _toMapboxPoint(LatLng location) {
    return mapbox.Point(
      coordinates: mapbox.Position(location.longitude, location.latitude),
    );
  }

  LatLng _fromMapboxPoint(mapbox.Point point) {
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
    final mapbox.MapboxMap? map = _addressMap;
    if (map != null) {
      unawaited(
        map.setCamera(
          mapbox.CameraOptions(
            center: _toMapboxPoint(_defaultAddressMapCenter),
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
          _selectedRegion?.code != value.code) return;
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
          _selectedProvince?.code != value.code) return;
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
    final ChildAddressLoader? loadBarangays = widget.loadBarangays;
    final bool shouldLoad = value != null && loadBarangays != null;
    setState(() {
      _selectedMunicipality = value;
      _selectedBarangay = null;
      _addressBarangays = <AddressOption>[];
      _loadingAddressBarangays = shouldLoad;
      _municipalityController.text = value?.name ?? '';
      _barangayController.clear();
      _clearPostalCodeForLocationChange();
      _selectedAddressLocation = null;
      _addressLocationMessage = null;
      _addressMapCenter = _defaultAddressMapCenter;
      _addressMapZoom = 14;
    });
    _refreshAddressPinAfterLocationChange();
    if (value == null || loadBarangays == null) return;

    try {
      final List<AddressOption> options = await loadBarangays(value.code);
      if (!mounted ||
          request != _addressOptionsRequest ||
          _selectedMunicipality?.code != value.code) return;
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
    final int lookupGeneration = ++_postalCodeLookupGeneration;
    setState(() {
      _selectedBarangay = value;
      _barangayController.text = value?.name ?? '';
      _postalCodeController.clear();
      _loadingPostalCode = value != null;
      _postalCodeLookupFailed = false;
      _selectedAddressLocation = null;
      _addressLocationMessage = null;
      _addressMapCenter = _defaultAddressMapCenter;
      _addressMapZoom = 14;
    });
    _refreshAddressPinAfterLocationChange();

    final AddressOption? municipality = _selectedMunicipality;
    final PostalCodeLoader? loadPostalCode = widget.loadPostalCode;
    if (value == null || municipality == null || loadPostalCode == null) {
      if (mounted && value != null) {
        setState(() {
          _loadingPostalCode = false;
          _postalCodeLookupFailed = true;
        });
      }
      return;
    }

    try {
      final String? postalCode = await loadPostalCode(
        municipalityCode: municipality.code,
        barangayCode: value.code,
        provinceCode: _selectedProvince?.code ?? '',
        provinceName: _selectedProvince?.name ?? '',
        municipalityName: municipality.name,
      );
      if (!mounted ||
          lookupGeneration != _postalCodeLookupGeneration ||
          _selectedBarangay?.code != value.code) return;
      final String normalizedPostalCode = postalCode?.trim() ?? '';
      setState(() {
        _postalCodeController.text = normalizedPostalCode;
        _loadingPostalCode = false;
        _postalCodeLookupFailed = normalizedPostalCode.isEmpty;
      });
    } catch (_) {
      if (mounted && lookupGeneration == _postalCodeLookupGeneration) {
        setState(() {
          _loadingPostalCode = false;
          _postalCodeLookupFailed = true;
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
      borderSide: const BorderSide(color: ShopColors.border),
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
              hintStyle: const TextStyle(
                color: ShopColors.faint,
                fontSize: 14,
              ),
              isDense: true,
              filled: true,
              fillColor: ShopColors.canvas,
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
                borderSide: const BorderSide(
                  color: ShopColors.accent,
                  width: 1.3,
                ),
              ),
              errorBorder: border.copyWith(
                borderSide: const BorderSide(color: Color(0xFFD64A59)),
              ),
              focusedErrorBorder: border.copyWith(
                borderSide: const BorderSide(
                  color: Color(0xFFD64A59),
                  width: 1.3,
                ),
              ),
            ),
            items: options
                .map(
                  (AddressOption option) => DropdownMenuItem<AddressOption>(
                    value: option,
                    child: Text(
                      option.name,
                      overflow: TextOverflow.ellipsis,
                    ),
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
      return 'Postal code is unavailable for this barangay.';
    }
    final String postalCode = _postalCodeController.text.trim();
    if (postalCode.isNotEmpty) return 'Postal code: $postalCode';
    return 'Postal code will fill after you select a barangay.';
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
          readOnly: true,
        ),
      ],
    );
  }
  Future<void> _findAddress() async {
    final String searchText = _addressSearchController.text.trim();
    final String query = <String>[
      if (searchText.isNotEmpty) searchText,
      if (_barangayController.text.trim().isNotEmpty)
        _barangayController.text.trim(),
      if (_municipalityController.text.trim().isNotEmpty)
        _municipalityController.text.trim(),
      if (_provinceController.text.trim().isNotEmpty)
        _provinceController.text.trim(),
      'Philippines',
    ].join(', ');

    if (query == 'Philippines' || _findingAddress) {
      setState(() {
        _addressLocationMessage =
            'Enter your barangay or address first, then search to place the pin.';
      });
      return;
    }

    const String mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
    if (mapboxToken.isEmpty) {
      setState(() {
        _addressLocationMessage =
            'Enter an address or tap the map. Address search needs MAPBOX_ACCESS_TOKEN.';
      });
      return;
    }

    setState(() {
      _findingAddress = true;
      _addressLocationMessage = null;
    });

    try {
      final Response<dynamic> response = await _addressGeocoder.get(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json',
        queryParameters: <String, dynamic>{
          'access_token': mapboxToken,
          'country': 'ph',
          'limit': 1,
        },
      );
      final dynamic features = response.data is Map
          ? (response.data as Map)['features']
          : null;
      final dynamic coordinates = features is List && features.isNotEmpty
          ? (features.first is Map
              ? (features.first as Map)['center']
              : null)
          : null;

      if (coordinates is! List || coordinates.length < 2) {
        throw const FormatException('No matching address was found.');
      }

      final double? longitude = double.tryParse(coordinates[0].toString());
      final double? latitude = double.tryParse(coordinates[1].toString());
      if (latitude == null || longitude == null) {
        throw const FormatException('The selected address has no coordinates.');
      }

      _setAddressLocation(LatLng(latitude, longitude));
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
        _nameController.text = snapshot.profile.name;
        _emailController.text = snapshot.profile.email;
        _phoneController.text = snapshot.profile.phone;
        _birthday = snapshot.profile.birthday;
        _gender = snapshot.profile.gender;
        _selectedPhoto = null;
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

  void _changeTab(BuyerAccountTab tab) {
    if (_activeTab == tab) {
      widget.onTabChanged?.call(tab);
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _activeTab = tab;
    });

    if (tab == BuyerAccountTab.addresses) {
      unawaited(_loadAddressRegions());
    }

    widget.onTabChanged?.call(tab);
  }

  Future<void> _pickPhoto() async {
    if (_savingProfile || _removingPhoto) {
      return;
    }

    final PickProfilePhotoCallback? callback = widget.onPickProfilePhoto;

    if (callback == null) {
      _showMessage('Profile photo selection will be connected later.');

      return;
    }

    try {
      final SelectedProfilePhoto? photo = await callback();

      if (!mounted || photo == null) {
        return;
      }

      if (photo.bytes.isEmpty) {
        _showMessage('The selected image is empty.', error: true);

        return;
      }

      if (photo.sizeInBytes > _maxProfilePhotoBytes) {
        _showMessage('Profile photo must not exceed 2 MB.', error: true);

        return;
      }

      setState(() {
        _selectedPhoto = photo;
      });
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    }
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();

    if (_savingProfile || _removingPhoto) {
      return;
    }

    if (!(_profileFormKey.currentState?.validate() ?? false)) {
      return;
    }

    final SelectedProfilePhoto? photo = _selectedPhoto;

    if (photo != null && photo.sizeInBytes > _maxProfilePhotoBytes) {
      _showMessage('Profile photo must not exceed 2 MB.', error: true);

      return;
    }

    final UpdateBuyerProfileCallback? callback = widget.onUpdateProfile;

    if (callback == null) {
      _showMessage('Profile saving will be connected to Laravel later.');

      return;
    }

    setState(() {
      _savingProfile = true;
    });

    try {
      final BuyerProfileData previousProfile = _profile;
      final UpdateBuyerProfileRequest request = UpdateBuyerProfileRequest(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        birthday: _birthday,
        gender: _gender,
        profilePhoto: _selectedPhoto,
      );
      late final BuyerProfileData updated;

      try {
        updated = await callback(request);
      } on BuyerProfileVerificationRequiredException catch (verification) {
        final BuyerProfileData? verified = await _verifyMobileChange(
          callback,
          request,
          verification,
        );
        if (verified == null) {
          return;
        }
        updated = verified;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = updated;

        _selectedPhoto = null;

        _nameController.text = updated.name;

        _emailController.text = updated.email;

        _phoneController.text = updated.phone;

        _birthday = updated.birthday;

        _gender = updated.gender;

        if (_recipientNameController.text.trim().isEmpty ||
            _recipientNameController.text.trim() ==
                previousProfile.name.trim()) {
          _recipientNameController.text = updated.name;
        }

        if (_addressPhoneController.text.trim().isEmpty ||
            _addressPhoneController.text.trim() ==
                previousProfile.phone.trim()) {
          _addressPhoneController.text = updated.phone;
        }
      });

      widget.onProfileChanged?.call(updated);

      _showMessage('Profile updated.');
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _savingProfile = false;
        });
      }
    }
  }

  Future<BuyerProfileData?> _verifyMobileChange(
    UpdateBuyerProfileCallback callback,
    UpdateBuyerProfileRequest request,
    BuyerProfileVerificationRequiredException verification,
  ) async {
    final TextEditingController codeController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool submitting = false;
    bool resending = false;
    String? dialogError;
    String? dialogNotice;

    try {
      return await showDialog<BuyerProfileData>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              Future<void> submitCode() async {
                if (submitting || !(formKey.currentState?.validate() ?? false)) {
                  return;
                }
                setDialogState(() {
                  submitting = true;
                  dialogError = null;
                });
                try {
                  final BuyerProfileData updated = await callback(
                    UpdateBuyerProfileRequest(
                      name: request.name,
                      email: request.email,
                      phone: request.phone,
                      birthday: request.birthday,
                      gender: request.gender,
                      profilePhoto: request.profilePhoto,
                      mobileChangeCode: codeController.text.trim(),
                    ),
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(updated);
                  }
                } catch (error) {
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      submitting = false;
                      dialogError = _errorText(error);
                    });
                  }
                }
              }

              Future<void> resendCode() async {
                final ResendBuyerMobileChangeCodeCallback? resend =
                    widget.onResendMobileChangeCode;
                if (resending || resend == null) {
                  return;
                }
                setDialogState(() {
                  resending = true;
                  dialogError = null;
                  dialogNotice = null;
                });
                try {
                  await resend();
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      resending = false;
                      dialogNotice = 'A new verification code was sent.';
                    });
                  }
                } catch (error) {
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      resending = false;
                      dialogError = _errorText(error);
                    });
                  }
                }
              }

              return AlertDialog(
                backgroundColor: _surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: const Text(
                  'Verify mobile number',
                  style: TextStyle(color: _text, fontWeight: FontWeight.w800),
                ),
                content: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        verification.message.isEmpty
                            ? 'Enter the six-digit code sent to ${verification.target}.'
                            : verification.message,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: codeController,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 22,
                          letterSpacing: 8,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: '------',
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: const BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: const BorderSide(color: _border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: const BorderSide(color: _maroon),
                          ),
                        ),
                        validator: (String? value) {
                          final String code = value?.trim() ?? '';
                          return RegExp(r'^\d{6}$').hasMatch(code)
                              ? null
                              : 'Enter the six-digit code.';
                        },
                        onFieldSubmitted: (_) => submitCode(),
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          dialogError!,
                          style: const TextStyle(
                            color: _danger,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (dialogNotice != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          dialogNotice!,
                          style: const TextStyle(
                            color: _maroon,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed:
                              resending || widget.onResendMobileChangeCode == null
                              ? null
                              : resendCode,
                          child: Text(
                            resending ? 'Sending…' : 'Resend code',
                            style: const TextStyle(color: _maroon),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: submitting ? null : submitCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _maroon,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Verify and save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      codeController.dispose();
    }
  }

  Future<void> _removeProfilePhoto() async {
    if (_removingPhoto || _savingProfile) {
      return;
    }

    /*
     * A newly selected local photo has not been sent to
     * Laravel yet. Removing it only clears the local preview.
     */
    if (_selectedPhoto != null) {
      setState(() {
        _selectedPhoto = null;
      });

      return;
    }

    final String? remotePhoto = _profile.profilePhotoUrl?.trim();

    if (remotePhoto == null || remotePhoto.isEmpty) {
      return;
    }

    final RemoveProfilePhotoCallback? callback = widget.onRemoveProfilePhoto;

    if (callback == null) {
      _showMessage('Profile photo removal will be connected to Laravel later.');

      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Remove profile photo?',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'Your account will use your initial when no profile photo is saved.',
            style: TextStyle(color: _muted, fontSize: 15, height: 1.55),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _danger,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _removingPhoto = true;
    });

    try {
      final BuyerProfileData updated = await callback();

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = updated;

        _selectedPhoto = null;
      });

      widget.onProfileChanged?.call(updated);

      _showMessage('Profile photo removed.');
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _removingPhoto = false;
        });
      }
    }
  }

  Future<void> _selectBirthday() async {
    final DateTime now = DateTime.now();

    final DateTime fallback = DateTime(now.year - 18, now.month, now.day);

    DateTime initialDate = _birthday ?? fallback;

    if (initialDate.isAfter(now)) {
      initialDate = fallback;
    }

    if (initialDate.isBefore(DateTime(1900))) {
      initialDate = DateTime(1900);
    }

    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select date of birth',
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _birthday = selected;
    });
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

    final AddBuyerAddressCallback? callback = widget.onAddAddress;

    if (callback == null) {
      _showMessage('Address saving will be connected to Laravel later.');

      return;
    }

    setState(() {
      _addingAddress = true;
    });

    try {
      final BuyerAddressData address = await callback(
        CreateBuyerAddressRequest(
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
        ),
      );

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

        _addresses.add(address);

        _resetAddressForm();
      });

      _notifyAddressesChanged();

      _showMessage('Delivery address saved.');
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

  void _resetAddressForm() {
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
    final mapbox.MapboxMap? map = _addressMap;
    if (map != null) {
      unawaited(
        map.setCamera(
          mapbox.CameraOptions(
            center: _toMapboxPoint(_defaultAddressMapCenter),
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
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Delete address?',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Remove "${address.label}" from your saved delivery addresses?',
            style: const TextStyle(color: _muted, fontSize: 15, height: 1.55),
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
                backgroundColor: _danger,
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
    final SetDefaultBuyerAddressCallback? callback =
        widget.onSetDefaultAddress;
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
          backgroundColor: error ? _danger : _maroonDark,
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
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child: RefreshIndicator(
                color: _maroon,
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

                    const SizedBox(height: 16),

                    _buildAccountSummary(),

                    const SizedBox(height: 14),

                    if (widget.showNavigationTabs) ...[
                      _buildSampleMessages(),

                      const SizedBox(height: 14),

                      _buildTabs(),

                      const SizedBox(height: 13),
                    ],

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
        foregroundColor: _danger,
        disabledForegroundColor: _muted2,
        side: const BorderSide(color: _danger),
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
      if (actions.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: actions,
        ),
      );
    }

    return ShopPageHeader(
      title: _activeTab.label,
      subtitle: _activeTab.description,
      onBack: handleBack,
      actions: actions,
    );
  }

  Widget _buildHeading() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BUYER CENTER',
          style: TextStyle(
            color: _maroon,
            fontSize: 12,
            letterSpacing: 1.7,
            fontWeight: FontWeight.w800,
          ),
        ),

        SizedBox(height: 5),

        Text(
          'Account Management',
          style: TextStyle(
            color: _text,
            fontSize: 30,
            height: 1.05,
            letterSpacing: -0.7,
            fontWeight: FontWeight.w800,
          ),
        ),

        SizedBox(height: 7),

        Text(
          'Manage your profile, delivery addresses, and account security.',
          style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
        ),
      ],
    );
  }

  Widget _buildAccountSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          _ProfileAvatar(
            profile: _profile,
            selectedPhoto: _selectedPhoto,
            size: 50,
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  _profile.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12.5),
                ),

                if (_profile.phone.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),

                  Text(
                    _profile.phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted2, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleMessages() {
    const List<_AccountSampleMessage> messages = <_AccountSampleMessage>[
      _AccountSampleMessage(
        icon: Icons.person_outline_rounded,
        title: 'Profile tip',
        message:
            'Keep your name, email, and contact number updated so checkout details stay accurate.',
      ),
      _AccountSampleMessage(
        icon: Icons.location_on_outlined,
        title: 'Delivery tip',
        message:
            'Add a complete delivery address before placing an order for a smoother checkout.',
      ),
      _AccountSampleMessage(
        icon: Icons.lock_outline_rounded,
        title: 'Security tip',
        message:
            'Use at least 8 characters for your password and keep it private.',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HELPFUL MESSAGES',
            style: TextStyle(
              color: _maroon,
              fontSize: 11.5,
              letterSpacing: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Quick account reminders',
            style: TextStyle(
              color: _text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...List<Widget>.generate(messages.length, (int index) {
            final _AccountSampleMessage item = messages[index];

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == messages.length - 1 ? 0 : 10,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ShopColors.accentSoft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(item.icon, color: _maroon, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: _text,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.message,
                            style: const TextStyle(
                              color: _muted,
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
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: BuyerAccountTab.values.length,
        separatorBuilder: (BuildContext context, int index) {
          return const SizedBox(width: 7);
        },
        itemBuilder: (BuildContext context, int index) {
          final BuyerAccountTab tab = BuyerAccountTab.values[index];

          final bool selected = tab == _activeTab;

          return Material(
            color: selected ? ShopColors.accentSoft : _surface,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              onTap: () {
                if (tab == BuyerAccountTab.vouchers &&
                    widget.onVouchers != null) {
                  widget.onVouchers!();
                  return;
                }
                if (tab == BuyerAccountTab.settings &&
                    widget.onSystemSettings != null) {
                  widget.onSystemSettings!();
                  return;
                }
                if (widget.onTabChanged != null) {
                  widget.onTabChanged!(tab);
                  return;
                }
                _changeTab(tab);
              },
              borderRadius: BorderRadius.circular(13),
              child: Container(
                constraints: const BoxConstraints(minWidth: 130),
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: selected ? _tan : _border),
                ),
                child: Row(
                  children: [
                    Icon(
                      tab.icon,
                      color: selected ? _maroon : _muted,
                      size: 18,
                    ),

                    const SizedBox(width: 8),

                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tab.label,
                          style: TextStyle(
                            color: selected ? _maroon : _text,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 2),

                        Text(
                          tab.description,
                          style: const TextStyle(
                            color: _muted2,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveContent() {
    switch (_activeTab) {
      case BuyerAccountTab.profile:
        return _buildProfileSection();

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
    }
  }

  Widget _buildProfileSection() {
    return _AccountPanel(
      title: 'Profile Information',
      subtitle: 'Update your personal details and profile photo.',
      icon: Icons.person_outline_rounded,
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Column(
                children: [
                  _ProfileAvatar(
                    profile: _profile,
                    selectedPhoto: _selectedPhoto,
                    size: 82,
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Profile photo',
                    style: TextStyle(
                      color: _text,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'Choose an image up to 2 MB. Laravel will perform the final image validation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),

                  if (_selectedPhoto != null) ...[
                    const SizedBox(height: 6),

                    Text(
                      '${_selectedPhoto!.fileName} · ${_formatFileSize(_selectedPhoto!.sizeInBytes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _brown,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _savingProfile || _removingPhoto
                              ? null
                              : _pickPhoto,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: _maroon,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            size: 17,
                          ),
                          label: const Text(
                            'Choose Photo',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _removingPhoto ||
                                  _savingProfile ||
                                  (_selectedPhoto == null &&
                                      (_profile.profilePhotoUrl == null ||
                                          _profile.profilePhotoUrl!
                                              .trim()
                                              .isEmpty))
                              ? null
                              : _removeProfilePhoto,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _brown,
                            side: const BorderSide(color: _border),
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          icon: _removingPhoto
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _maroon,
                                  ),
                                )
                              : const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                ),
                          label: const Text(
                            'Remove',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            const _FieldLabel(text: 'Full name'),

            const SizedBox(height: 7),

            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 160,
              decoration: _inputDecoration(
                hintText: 'Full name',
                prefixIcon: Icons.person_outline,
              ).copyWith(counterText: ''),
              validator: (String? value) {
                final String name = value?.trim() ?? '';

                if (name.isEmpty) {
                  return 'Enter your full name.';
                }

                if (name.length > 160) {
                  return 'Full name must not exceed 160 characters.';
                }

                return null;
              },
            ),

            const SizedBox(height: 15),

            const _FieldLabel(text: 'Email address'),

            const SizedBox(height: 7),

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              maxLength: 255,
              autofillHints: const <String>[AutofillHints.email],
              decoration: _inputDecoration(
                hintText: 'Email address',
                prefixIcon: Icons.email_outlined,
              ).copyWith(counterText: ''),
              validator: (String? value) {
                final String email = value?.trim() ?? '';

                if (email.isEmpty) {
                  return 'Enter your email address.';
                }

                if (email.length > 255) {
                  return 'Email must not exceed 255 characters.';
                }

                final RegExp emailPattern = RegExp(
                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                );

                if (!emailPattern.hasMatch(email)) {
                  return 'Enter a valid email address.';
                }

                return null;
              },
            ),

            const SizedBox(height: 15),

            const _FieldLabel(text: 'Mobile number', requiredField: false),

            const SizedBox(height: 7),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              maxLength: 40,
              autofillHints: const <String>[AutofillHints.telephoneNumber],
              decoration: _inputDecoration(
                hintText: 'Contact number',
                prefixIcon: Icons.phone_outlined,
              ).copyWith(counterText: ''),
              validator: (String? value) {
                if ((value ?? '').trim().length > 40) {
                  return 'Contact number must not exceed 40 characters.';
                }

                return null;
              },
            ),

            const SizedBox(height: 15),

            const _FieldLabel(text: 'Date of birth', requiredField: false),

            const SizedBox(height: 7),

            InkWell(
              onTap: _savingProfile ? null : _selectBirthday,
              borderRadius: BorderRadius.circular(13),
              child: InputDecorator(
                decoration: _inputDecoration(
                  hintText: 'Select birthday',
                  prefixIcon: Icons.calendar_today_outlined,
                ),
                child: Text(
                  _birthday == null
                      ? 'Select birthday'
                      : _formatDate(_birthday!),
                  style: TextStyle(
                    color: _birthday == null ? _muted2 : _text,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            const _FieldLabel(text: 'Gender', requiredField: false),

            const SizedBox(height: 7),

            DropdownButtonFormField<BuyerGender?>(
              initialValue: _gender,
              isExpanded: true,
              decoration: _inputDecoration(
                hintText: 'Prefer not to say',
                prefixIcon: Icons.wc_outlined,
              ),
              items: <DropdownMenuItem<BuyerGender?>>[
                const DropdownMenuItem<BuyerGender?>(
                  value: null,
                  child: Text('Prefer not to say'),
                ),
                ...BuyerGender.values.map((BuyerGender gender) {
                  return DropdownMenuItem<BuyerGender?>(
                    value: gender,
                    child: Text(gender.label),
                  );
                }),
              ],
              onChanged: _savingProfile
                  ? null
                  : (BuyerGender? value) {
                      setState(() {
                        _gender = value;
                      });
                    },
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 49,
              child: ElevatedButton(
                onPressed: _savingProfile || _removingPhoto
                    ? null
                    : _saveProfile,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _maroon,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: _savingProfile
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Changes',
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

  Widget _buildAddressesSection() {
    return _AccountPanel(
      title: 'Delivery Addresses',
      subtitle:
          'Saved addresses are used for future checkouts. Existing orders keep their original delivery details.',
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_addresses.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                children: [
                  Icon(Icons.location_off_outlined, color: _muted2, size: 30),

                  SizedBox(height: 9),

                  Text(
                    'No saved delivery address yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 13),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Form(
              key: _addressFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add delivery address',
                    style: TextStyle(
                      color: ShopColors.text,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Choose a precise location so the courier can find you.',
                    style: TextStyle(
                      color: ShopColors.muted,
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
                    label: 'Building / Subdivision, Landmark / Additional Details',
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
                              activeColor: _maroon,
                              onChanged: _addingAddress
                                  ? null
                                  : (bool? value) {
                                      setState(() {
                                        _newAddressIsDefault = value ?? false;
                                      });
                                    },
                            ),

                            const Expanded(
                              child: Text(
                                'Set as default address',
                                style: TextStyle(
                                  color: _text,
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
                        backgroundColor: _maroon,
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
                          : const Text(
                              'Save Address',
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
        ],
      ),
    );
  }

  Widget _buildAddressPinSection() {
    final LatLng? selectedLocation = _selectedAddressLocation;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
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
                const Text(
                  'Confirm location',
                  style: TextStyle(
                    color: _brown,
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Search your barangay or address, then adjust the pin to the exact location for the rider.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.45),
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
                        foregroundColor: _maroon,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: _border),
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
                        foregroundColor: _maroon,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: _border),
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
                ? mapbox.MapWidget(
                    viewport: mapbox.CameraViewportState(
                      center: _toMapboxPoint(_addressMapCenter),
                      zoom: _addressMapZoom,
                    ),
                    onMapCreated: _onAddressMapCreated,
                    onTapListener: _onAddressMapTap,
                  )
                : Container(
                    color: const Color(0xFFF7F2EE),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      kIsWeb
                          ? 'Mapbox Maps SDK is available on Android and iOS.'
                          : 'Add MAPBOX_ACCESS_TOKEN to your Flutter run configuration to load the map.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _muted,
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
              style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
            ),
          ),
          if (_addressLocationMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                _addressLocationMessage!,
                style: const TextStyle(color: _danger, fontSize: 11.5),
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

            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: _maroon, size: 18),

                  SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      'Use 8–72 characters with uppercase and lowercase letters, a number, and a symbol. It must differ from your current password and match the confirmation.',
                      style: TextStyle(
                        color: _brown,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              height: 49,
              child: ElevatedButton(
                onPressed: _changingPassword ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _maroon,
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
      hintStyle: const TextStyle(color: _muted2, fontSize: 13.5),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, color: _muted, size: 19),
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _maroon, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _danger, width: 1.3),
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
          color: _muted,
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

  static String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }

    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '$bytes B';
  }
}

class _AccountSampleMessage {
  final IconData icon;
  final String title;
  final String message;

  const _AccountSampleMessage({
    required this.icon,
    required this.title,
    required this.message,
  });
}

class _AccountStatusBadge extends StatelessWidget {
  final bool active;

  const _AccountStatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEEF8F1) : ShopColors.soft,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: active ? const Color(0xFFCDE5D4) : ShopColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF256F4A) : ShopColors.faint,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 5),

          Text(
            active ? 'Active' : 'Inactive',
            style: TextStyle(
              color: active ? const Color(0xFF256F4A) : ShopColors.muted,
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
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ShopColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ShopColors.accent.withValues(alpha: 0.035),
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
                    color: ShopColors.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: ShopColors.accent, size: 19),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: ShopColors.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: ShopColors.muted,
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

          const Divider(height: 1, color: ShopColors.border),

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
        color: ShopColors.accentSoft,
        shape: BoxShape.circle,
        border: Border.all(color: ShopColors.border),
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
          ? Image.network(
              remote,
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return _AvatarInitial(value: profile.initial);
                  },
              loadingBuilder:
                  (
                    BuildContext context,
                    Widget child,
                    ImageChunkEvent? progress,
                  ) {
                    if (progress == null) {
                      return child;
                    }

                    return const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ShopColors.accent,
                        ),
                      ),
                    );
                  },
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
      color: ShopColors.accentSoft,
      child: Text(
        value,
        style: const TextStyle(
          color: ShopColors.accent,
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

  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    required this.deleting,
    required this.settingDefault,
    required this.onSetDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: address.isDefault
            ? const Color(0xFFFFF4F0)
            : ShopColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: address.isDefault
              ? const Color(0xFFD9B09D)
              : ShopColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: ShopColors.accentSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.location_on_outlined,
              color: ShopColors.accent,
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
                      style: const TextStyle(
                        color: ShopColors.text,
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
                          color: ShopColors.accentSoft,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text(
                          'DEFAULT',
                          style: TextStyle(
                            color: ShopColors.accent,
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
                    style: const TextStyle(
                      color: ShopColors.secondaryText,
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
                  style: const TextStyle(
                    color: ShopColors.muted,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),

                if (address.landmark?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 5),

                  Text(
                    'Landmark: ${address.landmark}',
                    style: const TextStyle(
                      color: ShopColors.faint,
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
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFB42318),
                        ),
                      )
                    : const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFB42318),
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
  });

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: ShopColors.border),
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
            textCapitalization:
                keyboardType == TextInputType.phone ||
                    keyboardType == TextInputType.number
                ? TextCapitalization.none
                : TextCapitalization.words,
            style: const TextStyle(
              color: ShopColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: ShopColors.faint,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: prefixIcon == null
                  ? null
                  : Icon(prefixIcon, color: ShopColors.muted, size: 19),
              helperText: helperText,
              helperStyle: TextStyle(
                color: helperTextError
                    ? const Color(0xFFD64A59)
                    : ShopColors.muted,
                fontSize: 12,
              ),
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: ShopColors.canvas,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 15,
              ),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: const BorderSide(
                  color: ShopColors.accent,
                  width: 1.3,
                ),
              ),
              errorBorder: border.copyWith(
                borderSide: const BorderSide(color: Color(0xFFD64A59)),
              ),
              focusedErrorBorder: border.copyWith(
                borderSide: const BorderSide(
                  color: Color(0xFFD64A59),
                  width: 1.3,
                ),
              ),
              errorStyle: const TextStyle(
                color: Color(0xFFD64A59),
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
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFB42318)),
            ),
        ],
      ),
      style: const TextStyle(
        color: ShopColors.text,
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
        color: error ? const Color(0xFFFCECE7) : const Color(0xFFEEF8F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: error ? const Color(0xFFEBC9C0) : const Color(0xFFCDE5D4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: error ? const Color(0xFFB42318) : const Color(0xFF256F4A),
            size: 18,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: error
                    ? const Color(0xFFB42318)
                    : const Color(0xFF256F4A),
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

InputDecoration _accountInputDecoration({required String hintText}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: ShopColors.faint, fontSize: 13.5),
    filled: true,
    fillColor: ShopColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ShopColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ShopColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ShopColors.accent, width: 1.3),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFB42318)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFB42318), width: 1.3),
    ),
  );
}
