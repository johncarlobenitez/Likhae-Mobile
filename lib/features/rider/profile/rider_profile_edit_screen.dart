import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:likhae/shared/map/maplibre_compat.dart' as maplibre;

import '../../../services/philippine_address_service.dart';
import '../../../services/rider_mobile_service.dart';
import '../../auth/register_screen.dart' show AddressOption;
import 'rider_profile_screen.dart';

class RiderProfileEditScreen extends StatefulWidget {
  final RiderProfileData profile;

  const RiderProfileEditScreen({super.key, required this.profile});

  @override
  State<RiderProfileEditScreen> createState() => _RiderProfileEditScreenState();
}

class _RiderProfileEditScreenState extends State<RiderProfileEditScreen> {
  static const Color _background = Color(0xFFFBF7F2);
  static const Color _surface = Color(0xFFFFFDF9);
  static const Color _border = Color(0xFFEADCCC);
  static const Color _maroon = Color(0xFF561C17);
  static const Color _maroonSoft = Color(0xFFF1E4D7);
  static const Color _text = Color(0xFF3B211B);
  static const Color _muted = Color(0xFF987865);
  static const LatLng _defaultMapCenter = LatLng(13.4, 122.0);

  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _addressFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _vehicleFormKey = GlobalKey<FormState>();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _contact = TextEditingController();
  final TextEditingController _plateNumber = TextEditingController();
  final TextEditingController _postalCode = TextEditingController();
  final TextEditingController _houseNumber = TextEditingController();
  final TextEditingController _street = TextEditingController();
  final TextEditingController _landmark = TextEditingController();
  final TextEditingController _currentPassword = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  late RiderProfileData _profile;
  List<AddressOption> _regions = <AddressOption>[];
  List<AddressOption> _provinces = <AddressOption>[];
  List<AddressOption> _municipalities = <AddressOption>[];
  List<AddressOption> _barangays = <AddressOption>[];
  AddressOption? _region;
  AddressOption? _province;
  AddressOption? _municipality;
  AddressOption? _barangay;
  maplibre.MapLibreSession? _map;
  maplibre.CircleAnnotationManager? _markerManager;
  LatLng? _selectedLocation;
  Uint8List? _newProfilePhoto;
  String? _profilePhotoFileName;
  bool _loadingAddressOptions = false;
  bool _loadingPostalCode = false;
  bool _usingDeviceLocation = false;
  bool _pinConfirmed = false;
  bool _savingProfile = false;
  bool _savingVehicle = false;
  bool _savingAddress = false;
  bool _savingPassword = false;
  bool _addressChanged = false;
  bool _hasSaved = false;
  String? _addressError;

  bool get _canShowMap =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _firstName.text = _profile.firstName;
    _lastName.text = _profile.lastName;
    _email.text = _profile.email;
    _contact.text = _profile.contactNumber;
    _plateNumber.text = _profile.plateNumber == 'Not recorded'
        ? ''
        : _profile.plateNumber;
    final RiderResidentialAddressData? address = _profile.residentialAddress;
    if (address != null) {
      _postalCode.text = address.postalCode;
      _houseNumber.text = address.houseNumber;
      _street.text = address.streetAddress;
      _landmark.text = address.landmark;
      if (address.latitude != null && address.longitude != null) {
        _selectedLocation = LatLng(address.latitude!, address.longitude!);
        _pinConfirmed = true;
      }
      unawaited(_loadSavedAddressOptions(address));
    } else {
      unawaited(_loadAddressRegions());
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _contact.dispose();
    _plateNumber.dispose();
    _postalCode.dispose();
    _houseNumber.dispose();
    _street.dispose();
    _landmark.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _loadAddressRegions() async {
    if (mounted) setState(() => _loadingAddressOptions = true);
    try {
      final List<AddressOption> regions =
          await PhilippineAddressService.fetchRegions();
      if (!mounted) return;
      setState(() => _regions = regions);
    } catch (error) {
      if (mounted)
        setState(() => _addressError = 'Could not load regions. $error');
    } finally {
      if (mounted) setState(() => _loadingAddressOptions = false);
    }
  }

  Future<void> _loadSavedAddressOptions(
    RiderResidentialAddressData address,
  ) async {
    setState(() => _loadingAddressOptions = true);
    try {
      final List<AddressOption> regions =
          await PhilippineAddressService.fetchRegions();
      AddressOption? region = _findOption(
        regions,
        address.regionCode,
        address.regionName,
      );
      List<AddressOption> provinces = <AddressOption>[];
      List<AddressOption> municipalities = <AddressOption>[];
      List<AddressOption> barangays = <AddressOption>[];
      AddressOption? province;
      AddressOption? municipality;
      AddressOption? barangay;

      if (region == null && address.provinceCode.isNotEmpty) {
        for (final AddressOption candidate in regions) {
          final List<AddressOption> candidateProvinces =
              await PhilippineAddressService.fetchProvinces(candidate.code);
          final AddressOption? found = _findOption(
            candidateProvinces,
            address.provinceCode,
            address.provinceName,
          );
          if (found != null) {
            region = candidate;
            provinces = candidateProvinces;
            province = found;
            break;
          }
        }
      }
      if (region != null && provinces.isEmpty) {
        provinces = await PhilippineAddressService.fetchProvinces(region.code);
        province = _findOption(
          provinces,
          address.provinceCode,
          address.provinceName,
        );
      }
      if (province != null) {
        municipalities = await PhilippineAddressService.fetchMunicipalities(
          province.code,
        );
        municipality = _findOption(
          municipalities,
          address.municipalityCode,
          address.municipalityName,
        );
      }
      if (municipality != null) {
        barangays = await PhilippineAddressService.fetchBarangays(
          municipality.code,
        );
        barangay = _findOption(
          barangays,
          address.barangayCode,
          address.barangayName,
        );
      }
      if (!mounted) return;
      setState(() {
        _regions = regions;
        _region = region;
        _provinces = provinces;
        _province = province;
        _municipalities = municipalities;
        _municipality = municipality;
        _barangays = barangays;
        _barangay = barangay;
      });
    } catch (error) {
      if (mounted)
        setState(
          () => _addressError = 'Could not load saved address options. $error',
        );
    } finally {
      if (mounted) setState(() => _loadingAddressOptions = false);
    }
  }

  AddressOption? _findOption(
    List<AddressOption> options,
    String code,
    String name,
  ) {
    for (final AddressOption option in options) {
      if ((code.isNotEmpty && option.code == code) ||
          (name.isNotEmpty &&
              option.name.toLowerCase() == name.toLowerCase())) {
        return option;
      }
    }
    return null;
  }

  Future<void> _onRegionChanged(AddressOption? value) async {
    setState(() {
      _region = value;
      _province = null;
      _municipality = null;
      _barangay = null;
      _provinces = <AddressOption>[];
      _municipalities = <AddressOption>[];
      _barangays = <AddressOption>[];
      _addressError = null;
      _markAddressChanged();
    });
    if (value == null) return;
    try {
      final List<AddressOption> rows =
          await PhilippineAddressService.fetchProvinces(value.code);
      if (mounted && _region?.code == value.code) {
        setState(() => _provinces = rows);
      }
    } catch (error) {
      if (mounted)
        setState(() => _addressError = 'Could not load provinces. $error');
    }
  }

  Future<void> _onProvinceChanged(AddressOption? value) async {
    setState(() {
      _province = value;
      _municipality = null;
      _barangay = null;
      _municipalities = <AddressOption>[];
      _barangays = <AddressOption>[];
      _markAddressChanged();
    });
    if (value == null) return;
    try {
      final List<AddressOption> rows =
          await PhilippineAddressService.fetchMunicipalities(value.code);
      if (mounted && _province?.code == value.code) {
        setState(() => _municipalities = rows);
      }
    } catch (error) {
      if (mounted)
        setState(() => _addressError = 'Could not load cities. $error');
    }
  }

  Future<void> _onMunicipalityChanged(AddressOption? value) async {
    setState(() {
      _municipality = value;
      _barangay = null;
      _barangays = <AddressOption>[];
      _postalCode.clear();
      _markAddressChanged();
    });
    if (value == null) return;
    try {
      final List<AddressOption> rows =
          await PhilippineAddressService.fetchBarangays(value.code);
      if (mounted && _municipality?.code == value.code) {
        setState(() => _barangays = rows);
      }
    } catch (error) {
      if (mounted)
        setState(() => _addressError = 'Could not load barangays. $error');
    }
  }

  Future<void> _onBarangayChanged(AddressOption? value) async {
    setState(() {
      _barangay = value;
      _postalCode.clear();
      _loadingPostalCode = value != null;
      _markAddressChanged();
    });
    if (value == null || _municipality == null || _province == null) return;
    try {
      final String? postal = await PhilippineAddressService.fetchPostalCode(
        municipalityCode: _municipality!.code,
        barangayCode: value.code,
        provinceCode: _province!.code,
        provinceName: _province!.name,
        municipalityName: _municipality!.name,
      );
      if (!mounted || _barangay?.code != value.code) return;
      setState(() => _postalCode.text = postal ?? '');
    } catch (_) {
      // Postal codes may not exist for every barangay; the field stays editable.
    } finally {
      if (mounted && _barangay?.code == value.code) {
        setState(() => _loadingPostalCode = false);
      }
    }
  }

  void _markAddressChanged() {
    _addressChanged = true;
    _pinConfirmed = false;
    _selectedLocation = null;
    unawaited(_syncAddressMarker());
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final XFile? photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (photo == null) return;
      final Uint8List bytes = await photo.readAsBytes();
      if (!mounted) return;
      setState(() {
        _newProfilePhoto = bytes;
        _profilePhotoFileName = photo.name;
      });
    } catch (error) {
      _showMessage('Could not open the photo picker: $error', error: true);
    }
  }

  Future<void> _useDeviceLocation() async {
    if (_usingDeviceLocation) return;
    setState(() => _usingDeviceLocation = true);
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
          'Allow location access to pin this address.',
        );
      }
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      final LatLng location = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = location;
        _pinConfirmed = true;
        _addressError = null;
      });
      await _map?.setCamera(
        maplibre.CameraOptions(center: _mapPoint(location), zoom: 16),
      );
      await _syncAddressMarker();
    } catch (error) {
      if (mounted) setState(() => _addressError = error.toString());
    } finally {
      if (mounted) setState(() => _usingDeviceLocation = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate() || _savingProfile) return;
    setState(() => _savingProfile = true);
    try {
      final RiderProfileData updated = await RiderMobileService.updateProfile(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        contactNumber: _contact.text.trim(),
        profilePhotoBytes: _newProfilePhoto,
        profilePhotoFileName: _profilePhotoFileName,
      );
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _newProfilePhoto = null;
        _profilePhotoFileName = null;
        _hasSaved = true;
      });
      _showMessage('Profile updated and synced with your LIKHAE account.');
    } catch (error) {
      _showMessage('Could not update profile. $error', error: true);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _saveVehicle() async {
    if (!_vehicleFormKey.currentState!.validate() || _savingVehicle) return;
    setState(() => _savingVehicle = true);
    try {
      final String savedPlate = await RiderMobileService.updateVehiclePlate(
        _plateNumber.text,
      );
      if (!mounted) return;
      _plateNumber.text = savedPlate;
      _hasSaved = true;
      _showMessage('Vehicle plate number updated and synced with LIKHAE.');
    } catch (error) {
      _showMessage('Could not update plate number. $error', error: true);
    } finally {
      if (mounted) setState(() => _savingVehicle = false);
    }
  }

  Future<void> _saveAddress() async {
    if (!_addressFormKey.currentState!.validate() || _savingAddress) return;
    final LatLng? location = _selectedLocation;
    if (location == null || (!_pinConfirmed && _addressChanged)) {
      _showMessage('Tap the map to confirm the new address pin.', error: true);
      return;
    }
    setState(() => _savingAddress = true);
    try {
      final RiderProfileData updated =
          await RiderMobileService.updateResidentialAddress(<String, dynamic>{
            'region_code': _region!.code,
            'region_name': _region!.name,
            'province_code': _province!.code,
            'province_name': _province!.name,
            'municipality_code': _municipality!.code,
            'municipality_name': _municipality!.name,
            'barangay_code': _barangay!.code,
            'barangay_name': _barangay!.name,
            'postal_code': _postalCode.text.trim(),
            'house_number': _houseNumber.text.trim(),
            'street_address': _street.text.trim(),
            'landmark': _landmark.text.trim(),
            'latitude': location.latitude,
            'longitude': location.longitude,
          });
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _addressChanged = false;
        _pinConfirmed = true;
        _hasSaved = true;
      });
      _showMessage(
        'Residential address updated and synced with the web account.',
      );
    } catch (error) {
      _showMessage('Could not update address. $error', error: true);
    } finally {
      if (mounted) setState(() => _savingAddress = false);
    }
  }

  Future<void> _savePassword() async {
    if (!_passwordFormKey.currentState!.validate() || _savingPassword) return;
    setState(() => _savingPassword = true);
    try {
      await RiderMobileService.updatePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      setState(() => _hasSaved = true);
      _showMessage('Password updated for your LIKHAE account.');
    } catch (error) {
      _showMessage('Could not update password. $error', error: true);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _onMapCreated(maplibre.MapLibreSession map) async {
    _map = map;
    _markerManager = await map.annotations.createCircleAnnotationManager();
    await _syncAddressMarker();
  }

  void _onMapTap(maplibre.MapContentGestureContext context) {
    final maplibre.Position point = context.point.coordinates;
    setState(() {
      _selectedLocation = LatLng(point.lat.toDouble(), point.lng.toDouble());
      _pinConfirmed = true;
      _addressError = null;
    });
    unawaited(_syncAddressMarker());
  }

  Future<void> _syncAddressMarker() async {
    final maplibre.CircleAnnotationManager? manager = _markerManager;
    if (manager == null) return;
    await manager.deleteAll();
    final LatLng? location = _selectedLocation;
    if (location == null) return;
    await manager.create(
      maplibre.CircleAnnotationOptions(
        geometry: maplibre.Point(
          coordinates: maplibre.Position(location.longitude, location.latitude),
        ),
        circleColor: _maroon.toARGB32(),
        circleRadius: 10,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 3,
      ),
    );
  }

  maplibre.Point _mapPoint(LatLng location) => maplibre.Point(
    coordinates: maplibre.Position(location.longitude, location.latitude),
  );

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? const Color(0xFF9D3029) : _maroon,
        ),
      );
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Enter $label.' : null;

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your email.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final RiderResidentialAddressData? address = _profile.residentialAddress;
    final LatLng mapCenter = _selectedLocation ?? _defaultMapCenter;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _text,
        title: const Text('Edit Rider Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(_hasSaved),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
          children: <Widget>[
            const Text(
              'ACCOUNT MANAGEMENT',
              style: TextStyle(
                color: _maroon,
                fontSize: 10,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your rider profile',
              style: TextStyle(
                color: _text,
                fontSize: 27,
                height: 1.1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Changes saved here will appear on your LIKHAE web account too.',
              style: TextStyle(color: _muted, fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 16),
            _panel(
              title: 'Personal Information',
              subtitle: 'Edit the details used on your rider account.',
              icon: Icons.person_outline_rounded,
              child: Form(
                key: _profileFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildPhotoPicker(),
                    const SizedBox(height: 14),
                    _textField(
                      controller: _firstName,
                      label: 'First name',
                      validator: (String? value) =>
                          _required(value, 'your first name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    _textField(
                      controller: _lastName,
                      label: 'Last name',
                      validator: (String? value) =>
                          _required(value, 'your last name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    _textField(
                      controller: _email,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                    ),
                    _textField(
                      controller: _contact,
                      label: 'Contact number',
                      keyboardType: TextInputType.phone,
                      validator: (String? value) =>
                          _required(value, 'your contact number'),
                    ),
                    if (_profile.birthday != 'Not recorded' ||
                        _profile.status.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          'Birthday: ${_profile.birthday} · Status: ${_profile.status}',
                          style: const TextStyle(color: _muted, fontSize: 11.5),
                        ),
                      ),
                    _saveButton(
                      label: 'Save Profile',
                      saving: _savingProfile,
                      onPressed: _saveProfile,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _panel(
              title: 'Vehicle and Coverage',
              subtitle:
                  'Update your plate number when you replace your vehicle. Vehicle type and coverage are managed by your logistics center.',
              icon: Icons.two_wheeler_outlined,
              child: Form(
                key: _vehicleFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _readOnlyRow('Vehicle', _profile.vehicleType),
                    _textField(
                      controller: _plateNumber,
                      label: 'Plate number',
                      textCapitalization: TextCapitalization.characters,
                      validator: (String? value) {
                        final String plate = value?.trim() ?? '';
                        if (plate.isEmpty) return 'Enter your plate number.';
                        if (plate.length > 50 ||
                            !RegExp(
                              r'^[A-Za-z0-9][A-Za-z0-9 -]*$',
                            ).hasMatch(plate)) {
                          return 'Use letters, numbers, spaces, or hyphens.';
                        }
                        return null;
                      },
                    ),
                    _readOnlyRow('Logistics Center', _profile.logisticsCenter),
                    _readOnlyRow(
                      'Areas',
                      _profile.serviceAreas.isEmpty
                          ? 'No active area'
                          : _profile.serviceAreas.join(', '),
                    ),
                    _saveButton(
                      label: 'Save Plate Number',
                      saving: _savingVehicle,
                      onPressed: _saveVehicle,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _panel(
              title: 'Registered Residential Address',
              subtitle: 'Separate from your live delivery location.',
              icon: Icons.location_on_outlined,
              child: Form(
                key: _addressFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_loadingAddressOptions)
                      const LinearProgressIndicator(minHeight: 2),
                    _addressDropdown(
                      label: 'Region',
                      options: _regions,
                      value: _region,
                      enabled: !_loadingAddressOptions,
                      onChanged: _onRegionChanged,
                    ),
                    _addressDropdown(
                      label: 'Province',
                      options: _provinces,
                      value: _province,
                      enabled: _region != null,
                      onChanged: _onProvinceChanged,
                    ),
                    _addressDropdown(
                      label: 'City / Municipality',
                      options: _municipalities,
                      value: _municipality,
                      enabled: _province != null,
                      onChanged: _onMunicipalityChanged,
                    ),
                    _addressDropdown(
                      label: 'Barangay',
                      options: _barangays,
                      value: _barangay,
                      enabled: _municipality != null,
                      onChanged: _onBarangayChanged,
                    ),
                    _textField(
                      controller: _postalCode,
                      label: _loadingPostalCode
                          ? 'Postal code · filling…'
                          : 'Postal code',
                      keyboardType: TextInputType.number,
                    ),
                    _textField(
                      controller: _houseNumber,
                      label: 'House / Unit Number',
                      onChanged: (_) => _markAddressChanged(),
                    ),
                    _textField(
                      controller: _street,
                      label: 'Street / Purok',
                      validator: (String? value) =>
                          _required(value, 'your street or purok'),
                      onChanged: (_) => _markAddressChanged(),
                    ),
                    _textField(
                      controller: _landmark,
                      label:
                          'Building / Subdivision / Landmark / Additional Details',
                      onChanged: (_) => _markAddressChanged(),
                    ),
                    const SizedBox(height: 4),
                    _buildMap(mapCenter),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _usingDeviceLocation
                          ? null
                          : _useDeviceLocation,
                      icon: _usingDeviceLocation
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded, size: 18),
                      label: const Text('Use device location for the pin'),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _selectedLocation == null
                          ? 'Tap the map to pin the exact residential address.'
                          : 'Pinned location: ${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                      style: TextStyle(
                        color: _pinConfirmed ? const Color(0xFF2D705C) : _muted,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                    if (_addressError != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        _addressError!,
                        style: const TextStyle(
                          color: Color(0xFFB42318),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _saveButton(
                      label: 'Save Registered Address',
                      saving: _savingAddress,
                      onPressed: _saveAddress,
                    ),
                    if (address?.formatted.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Current address: ${address!.formatted}',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _panel(
              title: 'Change Password',
              subtitle:
                  'Enter your current password before choosing a new one.',
              icon: Icons.lock_outline_rounded,
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _textField(
                      controller: _currentPassword,
                      label: 'Current password',
                      obscureText: true,
                      validator: (String? value) =>
                          _required(value, 'your current password'),
                    ),
                    _textField(
                      controller: _newPassword,
                      label: 'New password',
                      obscureText: true,
                      validator: (String? value) {
                        if (value == null || value.length < 8) {
                          return 'Use at least 8 characters.';
                        }
                        return null;
                      },
                    ),
                    _textField(
                      controller: _confirmPassword,
                      label: 'Confirm new password',
                      obscureText: true,
                      validator: (String? value) => value != _newPassword.text
                          ? 'Passwords do not match.'
                          : null,
                    ),
                    _saveButton(
                      label: 'Update Password',
                      saving: _savingPassword,
                      onPressed: _savePassword,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    final ImageProvider<Object>? existingImage =
        _profile.profilePhotoUrl?.trim().isNotEmpty == true
        ? NetworkImage(_profile.profilePhotoUrl!)
        : null;
    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 32,
          backgroundColor: _maroonSoft,
          backgroundImage: _newProfilePhoto != null
              ? MemoryImage(_newProfilePhoto!)
              : existingImage,
          child: _newProfilePhoto == null && existingImage == null
              ? Text(
                  _profile.initials,
                  style: const TextStyle(
                    color: _maroon,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Profile photo',
                style: TextStyle(
                  color: _text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'JPG, PNG, or WebP · maximum 5 MB',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
              const SizedBox(height: 7),
              OutlinedButton(
                onPressed: _pickProfilePhoto,
                child: Text(
                  _newProfilePhoto == null ? 'Choose photo' : 'Change photo',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMap(LatLng center) {
    if (!_canShowMap) {
      return Container(
        height: 190,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF1ECE8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Interactive address maps are available on Android, iOS, and web. You can also use device location to set the address pin.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 12, height: 1.45),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 220,
        child: maplibre.MapLibreMapWidget(
          viewport: maplibre.MapLibreViewport(
            center: _mapPoint(center),
            zoom: _selectedLocation == null ? 5 : 16,
          ),
          onMapCreated: _onMapCreated,
          onTapListener: _onMapTap,
        ),
      ),
    );
  }

  Widget _addressDropdown({
    required String label,
    required List<AddressOption> options,
    required AddressOption? value,
    required bool enabled,
    required ValueChanged<AddressOption?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: _text,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<AddressOption>(
            initialValue: value,
            isExpanded: true,
            decoration: _inputDecoration(
              hintText: enabled
                  ? 'Select $label'
                  : 'Select previous location first',
            ),
            items: options
                .map(
                  (AddressOption option) => DropdownMenuItem<AddressOption>(
                    value: option,
                    child: Text(option.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            onChanged: enabled ? onChanged : null,
            validator: (AddressOption? option) =>
                option == null ? 'Select a $label.' : null,
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: _text,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            obscureText: obscureText,
            validator: validator,
            onChanged: onChanged,
            decoration: _inputDecoration(hintText: label),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String hintText}) =>
      InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: _muted, fontSize: 12),
        filled: true,
        fillColor: _surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _maroon, width: 1.3),
        ),
      );

  Widget _panel({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: _maroon, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _readOnlyRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 125,
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 11.5),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _saveButton({
    required String label,
    required bool saving,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 47,
      child: FilledButton(
        onPressed: saving ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _maroon,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: saving
            ? const SizedBox.square(
                dimension: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}
