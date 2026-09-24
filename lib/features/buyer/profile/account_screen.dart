import 'dart:typed_data';

import 'package:flutter/material.dart';

enum BuyerAccountTab {
  profile,
  addresses,
  password,
}

extension BuyerAccountTabInfo on BuyerAccountTab {
  String get label {
    switch (this) {
      case BuyerAccountTab.profile:
        return 'Profile';

      case BuyerAccountTab.addresses:
        return 'Addresses';

      case BuyerAccountTab.password:
        return 'Change Password';
    }
  }

  String get description {
    switch (this) {
      case BuyerAccountTab.profile:
        return 'Personal information';

      case BuyerAccountTab.addresses:
        return 'Delivery locations';

      case BuyerAccountTab.password:
        return 'Account security';
    }
  }

  IconData get icon {
    switch (this) {
      case BuyerAccountTab.profile:
        return Icons.person_outline_rounded;

      case BuyerAccountTab.addresses:
        return Icons.location_on_outlined;

      case BuyerAccountTab.password:
        return Icons.lock_outline_rounded;
    }
  }
}

enum BuyerGender {
  male,
  female,
  other,
}

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

  static BuyerGender? fromValue(
    String? value,
  ) {
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

  final DateTime? birthday;
  final BuyerGender? gender;

  final String? profilePhotoUrl;

  const BuyerProfileData({
    required this.name,
    required this.email,
    this.phone = '',
    this.birthday,
    this.gender,
    this.profilePhotoUrl,
  });

  String get initial {
    final String cleanName =
        name.trim();

    if (cleanName.isEmpty) {
      return 'B';
    }

    return cleanName[0].toUpperCase();
  }
}

class SelectedProfilePhoto {
  final String fileName;

  /// Bytes selected by image_picker/file_picker.
  ///
  /// The picker stays outside this screen so this file has
  /// no plugin dependency.
  final Uint8List bytes;

  const SelectedProfilePhoto({
    required this.fileName,
    required this.bytes,
  });

  int get sizeInBytes {
    return bytes.lengthInBytes;
  }

  double get sizeInMegabytes {
    return sizeInBytes /
        (1024 * 1024);
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

  const UpdateBuyerProfileRequest({
    required this.name,
    required this.email,
    required this.phone,
    required this.birthday,
    required this.gender,
    this.profilePhoto,
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
    this.isDefault = false,
    this.formattedAddress,
  });

  String get displayAddress {
    final String? serverFormatted =
        formattedAddress?.trim();

    if (serverFormatted != null &&
        serverFormatted.isNotEmpty) {
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
        .map(
          (String value) =>
              value.trim(),
        )
        .where(
          (String value) =>
              value.isNotEmpty,
        )
        .join(', ');
  }

  BuyerAddressData copyWith({
    bool? isDefault,
  }) {
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
      isDefault:
          isDefault ?? this.isDefault,
      formattedAddress:
          formattedAddress,
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
  final String postalCode;
  final String landmark;

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
    required this.postalCode,
    required this.landmark,
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

typedef PickProfilePhotoCallback =
    Future<SelectedProfilePhoto?> Function();

typedef UpdateBuyerProfileCallback =
    Future<BuyerProfileData> Function(
  UpdateBuyerProfileRequest request,
);

typedef RemoveProfilePhotoCallback =
    Future<BuyerProfileData> Function();

typedef AddBuyerAddressCallback =
    Future<BuyerAddressData> Function(
  CreateBuyerAddressRequest request,
);

typedef DeleteBuyerAddressCallback =
    Future<void> Function(
  BuyerAddressData address,
);

typedef ChangeBuyerPasswordCallback =
    Future<void> Function(
  ChangeBuyerPasswordRequest request,
);

typedef RefreshBuyerAccountCallback =
    Future<void> Function();

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

  final PickProfilePhotoCallback?
      onPickProfilePhoto;

  final UpdateBuyerProfileCallback?
      onUpdateProfile;

  final RemoveProfilePhotoCallback?
      onRemoveProfilePhoto;

  final AddBuyerAddressCallback?
      onAddAddress;

  final DeleteBuyerAddressCallback?
      onDeleteAddress;

  final ChangeBuyerPasswordCallback?
      onChangePassword;

  final RefreshBuyerAccountCallback?
      onRefresh;

  /// Optional parent synchronization callbacks.
  final ValueChanged<BuyerProfileData>?
      onProfileChanged;

  final ValueChanged<List<BuyerAddressData>>?
      onAddressesChanged;

  final ValueChanged<BuyerAccountTab>?
      onTabChanged;

  const AccountScreen({
    super.key,
    required this.profile,
    this.addresses =
        const <BuyerAddressData>[],
    this.initialTab =
        BuyerAccountTab.profile,
    this.buyerNotice,
    this.errorMessage,
    this.accountActive,
    this.onBack,
    this.onPickProfilePhoto,
    this.onUpdateProfile,
    this.onRemoveProfilePhoto,
    this.onAddAddress,
    this.onDeleteAddress,
    this.onChangePassword,
    this.onRefresh,
    this.onProfileChanged,
    this.onAddressesChanged,
    this.onTabChanged,
  });

  @override
  State<AccountScreen> createState() =>
      _AccountScreenState();
}

class _AccountScreenState
    extends State<AccountScreen> {
  static const Color _background =
      Color(0xFFFBF7F2);

  static const Color _surface =
      Color(0xFFFFFDF9);

  static const Color _soft =
      Color(0xFFF6EFE7);

  static const Color _border =
      Color(0xFFEADCCC);

  static const Color _maroon =
      Color(0xFF561C17);

  static const Color _maroonDark =
      Color(0xFF3E130F);

  static const Color _text =
      Color(0xFF3B211B);

  static const Color _brown =
      Color(0xFF6C4936);

  static const Color _muted =
      Color(0xFF987865);

  static const Color _muted2 =
      Color(0xFFA99386);

  static const Color _tan =
      Color(0xFFC19771);

  static const Color _danger =
      Color(0xFFB42318);

  static const int _maxProfilePhotoBytes =
      2 * 1024 * 1024;

  late BuyerProfileData _profile;

  late List<BuyerAddressData>
      _addresses;

  late BuyerAccountTab _activeTab;

  SelectedProfilePhoto? _selectedPhoto;

  bool _savingProfile = false;
  bool _removingPhoto = false;

  bool _addingAddress = false;

  final Set<String> _deletingAddressIds =
      <String>{};

  bool _changingPassword = false;
  bool _refreshing = false;

  final GlobalKey<FormState>
      _profileFormKey =
      GlobalKey<FormState>();

  final GlobalKey<FormState>
      _addressFormKey =
      GlobalKey<FormState>();

  final GlobalKey<FormState>
      _passwordFormKey =
      GlobalKey<FormState>();

  late final TextEditingController
      _nameController;

  late final TextEditingController
      _emailController;

  late final TextEditingController
      _phoneController;

  DateTime? _birthday;

  BuyerGender? _gender;

  late final TextEditingController
      _addressLabelController;

  late final TextEditingController
      _recipientNameController;

  late final TextEditingController
      _addressPhoneController;

  final TextEditingController
      _houseNumberController =
      TextEditingController();

  final TextEditingController
      _streetController =
      TextEditingController();

  final TextEditingController
      _barangayController =
      TextEditingController();

  final TextEditingController
      _municipalityController =
      TextEditingController();

  final TextEditingController
      _provinceController =
      TextEditingController();

  final TextEditingController
      _regionController =
      TextEditingController();

  final TextEditingController
      _postalCodeController =
      TextEditingController();

  final TextEditingController
      _landmarkController =
      TextEditingController();

  bool _newAddressIsDefault = false;

  final TextEditingController
      _currentPasswordController =
      TextEditingController();

  final TextEditingController
      _newPasswordController =
      TextEditingController();

  final TextEditingController
      _confirmPasswordController =
      TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();

    _profile = widget.profile;

    _addresses =
        List<BuyerAddressData>.from(
      widget.addresses,
    );

    _activeTab =
        widget.initialTab;

    _nameController =
        TextEditingController(
      text: _profile.name,
    );

    _emailController =
        TextEditingController(
      text: _profile.email,
    );

    _phoneController =
        TextEditingController(
      text: _profile.phone,
    );

    _birthday =
        _profile.birthday;

    _gender =
        _profile.gender;

    _addressLabelController =
        TextEditingController(
      text: 'Home',
    );

    _recipientNameController =
        TextEditingController(
      text: _profile.name,
    );

    _addressPhoneController =
        TextEditingController(
      text: _profile.phone,
    );
  }

  @override
  void didUpdateWidget(
    covariant AccountScreen oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.profile !=
        widget.profile) {
      final BuyerProfileData
          previousProfile =
          _profile;

      _profile =
          widget.profile;

      _nameController.text =
          _profile.name;

      _emailController.text =
          _profile.email;

      _phoneController.text =
          _profile.phone;

      _birthday =
          _profile.birthday;

      _gender =
          _profile.gender;

      if (_recipientNameController.text
              .trim()
              .isEmpty ||
          _recipientNameController.text
                  .trim() ==
              previousProfile.name
                  .trim()) {
        _recipientNameController.text =
            _profile.name;
      }

      if (_addressPhoneController.text
              .trim()
              .isEmpty ||
          _addressPhoneController.text
                  .trim() ==
              previousProfile.phone
                  .trim()) {
        _addressPhoneController.text =
            _profile.phone;
      }
    }

    if (oldWidget.addresses !=
        widget.addresses) {
      _addresses =
          List<BuyerAddressData>.from(
        widget.addresses,
      );

      _cleanupDeletingAddressIds();
    }

    if (oldWidget.initialTab !=
        widget.initialTab) {
      _activeTab =
          widget.initialTab;
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

    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  void _cleanupDeletingAddressIds() {
    final Set<String> currentIds =
        _addresses
            .map(
              (
                BuyerAddressData address,
              ) =>
                  address.id,
            )
            .toSet();

    _deletingAddressIds.removeWhere(
      (String id) =>
          !currentIds.contains(
        id,
      ),
    );
  }

  Future<void> _refresh() async {
    final RefreshBuyerAccountCallback?
        callback =
        widget.onRefresh;

    if (callback == null ||
        _refreshing) {
      return;
    }

    setState(() {
      _refreshing = true;
    });

    try {
      await callback();
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  void _changeTab(
    BuyerAccountTab tab,
  ) {
    if (_activeTab == tab) {
      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    setState(() {
      _activeTab =
          tab;
    });

    widget.onTabChanged?.call(
      tab,
    );
  }

  Future<void> _pickPhoto() async {
    if (_savingProfile ||
        _removingPhoto) {
      return;
    }

    final PickProfilePhotoCallback?
        callback =
        widget.onPickProfilePhoto;

    if (callback == null) {
      _showMessage(
        'Profile photo selection will be connected later.',
      );

      return;
    }

    try {
      final SelectedProfilePhoto? photo =
          await callback();

      if (!mounted ||
          photo == null) {
        return;
      }

      if (photo.bytes.isEmpty) {
        _showMessage(
          'The selected image is empty.',
          error: true,
        );

        return;
      }

      if (photo.sizeInBytes >
          _maxProfilePhotoBytes) {
        _showMessage(
          'Profile photo must not exceed 2 MB.',
          error: true,
        );

        return;
      }

      setState(() {
        _selectedPhoto =
            photo;
      });
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    }
  }

  Future<void> _saveProfile() async {
    FocusScope.of(
      context,
    ).unfocus();

    if (_savingProfile ||
        _removingPhoto) {
      return;
    }

    if (!(_profileFormKey.currentState
            ?.validate() ??
        false)) {
      return;
    }

    final SelectedProfilePhoto?
        photo =
        _selectedPhoto;

    if (photo != null &&
        photo.sizeInBytes >
            _maxProfilePhotoBytes) {
      _showMessage(
        'Profile photo must not exceed 2 MB.',
        error: true,
      );

      return;
    }

    final UpdateBuyerProfileCallback?
        callback =
        widget.onUpdateProfile;

    if (callback == null) {
      _showMessage(
        'Profile saving will be connected to Laravel later.',
      );

      return;
    }

    setState(() {
      _savingProfile = true;
    });

    try {
      final BuyerProfileData
          previousProfile =
          _profile;

      final BuyerProfileData updated =
          await callback(
        UpdateBuyerProfileRequest(
          name:
              _nameController.text
                  .trim(),
          email:
              _emailController.text
                  .trim(),
          phone:
              _phoneController.text
                  .trim(),
          birthday:
              _birthday,
          gender:
              _gender,
          profilePhoto:
              _selectedPhoto,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _profile =
            updated;

        _selectedPhoto =
            null;

        _nameController.text =
            updated.name;

        _emailController.text =
            updated.email;

        _phoneController.text =
            updated.phone;

        _birthday =
            updated.birthday;

        _gender =
            updated.gender;

        if (_recipientNameController
                    .text
                    .trim()
                    .isEmpty ||
            _recipientNameController
                    .text
                    .trim() ==
                previousProfile.name
                    .trim()) {
          _recipientNameController.text =
              updated.name;
        }

        if (_addressPhoneController
                    .text
                    .trim()
                    .isEmpty ||
            _addressPhoneController
                    .text
                    .trim() ==
                previousProfile.phone
                    .trim()) {
          _addressPhoneController.text =
              updated.phone;
        }
      });

      widget.onProfileChanged?.call(
        updated,
      );

      _showMessage(
        'Profile updated.',
      );
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingProfile = false;
        });
      }
    }
  }

  Future<void> _removeProfilePhoto() async {
    if (_removingPhoto ||
        _savingProfile) {
      return;
    }

    /*
     * A newly selected local photo has not been sent to
     * Laravel yet. Removing it only clears the local preview.
     */
    if (_selectedPhoto != null) {
      setState(() {
        _selectedPhoto =
            null;
      });

      return;
    }

    final String? remotePhoto =
        _profile.profilePhotoUrl
            ?.trim();

    if (remotePhoto == null ||
        remotePhoto.isEmpty) {
      return;
    }

    final RemoveProfilePhotoCallback?
        callback =
        widget.onRemoveProfilePhoto;

    if (callback == null) {
      _showMessage(
        'Profile photo removal will be connected to Laravel later.',
      );

      return;
    }

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
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
            'Remove profile photo?',
            style:
                TextStyle(
              color:
                  _text,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          content:
              const Text(
            'Your account will use your initial when no profile photo is saved.',
            style:
                TextStyle(
              color:
                  _muted,
              fontSize:
                  12.5,
              height:
                  1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  false,
                );
              },
              child:
                  const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  true,
                );
              },
              style:
                  ElevatedButton
                      .styleFrom(
                backgroundColor:
                    _danger,
                foregroundColor:
                    Colors.white,
                elevation:
                    0,
              ),
              child:
                  const Text(
                'Remove',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    setState(() {
      _removingPhoto = true;
    });

    try {
      final BuyerProfileData updated =
          await callback();

      if (!mounted) {
        return;
      }

      setState(() {
        _profile =
            updated;

        _selectedPhoto =
            null;
      });

      widget.onProfileChanged?.call(
        updated,
      );

      _showMessage(
        'Profile photo removed.',
      );
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _removingPhoto = false;
        });
      }
    }
  }

  Future<void> _selectBirthday() async {
    final DateTime now =
        DateTime.now();

    final DateTime fallback =
        DateTime(
      now.year - 18,
      now.month,
      now.day,
    );

    DateTime initialDate =
        _birthday ??
            fallback;

    if (initialDate.isAfter(
      now,
    )) {
      initialDate =
          fallback;
    }

    if (initialDate.isBefore(
      DateTime(1900),
    )) {
      initialDate =
          DateTime(1900);
    }

    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate:
          initialDate,
      firstDate:
          DateTime(1900),
      lastDate:
          now,
      helpText:
          'Select date of birth',
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    setState(() {
      _birthday =
          selected;
    });
  }

  Future<void> _addAddress() async {
    FocusScope.of(
      context,
    ).unfocus();

    if (_addingAddress) {
      return;
    }

    if (!(_addressFormKey.currentState
            ?.validate() ??
        false)) {
      return;
    }

    final AddBuyerAddressCallback?
        callback =
        widget.onAddAddress;

    if (callback == null) {
      _showMessage(
        'Address saving will be connected to Laravel later.',
      );

      return;
    }

    setState(() {
      _addingAddress = true;
    });

    try {
      final BuyerAddressData address =
          await callback(
        CreateBuyerAddressRequest(
          label:
              _addressLabelController
                  .text
                  .trim(),
          recipientName:
              _recipientNameController
                  .text
                  .trim(),
          contactNumber:
              _addressPhoneController
                  .text
                  .trim(),
          houseNumber:
              _houseNumberController
                  .text
                  .trim(),
          street:
              _streetController
                  .text
                  .trim(),
          barangay:
              _barangayController
                  .text
                  .trim(),
          municipality:
              _municipalityController
                  .text
                  .trim(),
          province:
              _provinceController
                  .text
                  .trim(),
          region:
              _regionController
                  .text
                  .trim(),
          postalCode:
              _postalCodeController
                  .text
                  .trim(),
          landmark:
              _landmarkController
                  .text
                  .trim(),
          isDefault:
              _newAddressIsDefault,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        if (address.isDefault) {
          _addresses =
              _addresses
                  .map(
                    (
                      BuyerAddressData current,
                    ) =>
                        current.copyWith(
                      isDefault:
                          false,
                    ),
                  )
                  .toList();
        }

        _addresses.add(
          address,
        );

        _resetAddressForm();
      });

      _notifyAddressesChanged();

      _showMessage(
        'Delivery address saved.',
      );
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _addingAddress = false;
        });
      }
    }
  }

  void _resetAddressForm() {
    _addressLabelController.text =
        'Home';

    _recipientNameController.text =
        _profile.name;

    _addressPhoneController.text =
        _profile.phone;

    _houseNumberController.clear();
    _streetController.clear();
    _barangayController.clear();
    _municipalityController.clear();
    _provinceController.clear();
    _regionController.clear();
    _postalCodeController.clear();
    _landmarkController.clear();

    _newAddressIsDefault =
        false;
  }

  Future<void> _deleteAddress(
    BuyerAddressData address,
  ) async {
    if (_deletingAddressIds.contains(
      address.id,
    )) {
      return;
    }

    final DeleteBuyerAddressCallback?
        callback =
        widget.onDeleteAddress;

    if (callback == null) {
      _showMessage(
        'Address deletion will be connected to Laravel later.',
      );

      return;
    }

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
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
            'Delete address?',
            style:
                TextStyle(
              color:
                  _text,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          content:
              Text(
            'Remove "${address.label}" from your saved delivery addresses?',
            style:
                const TextStyle(
              color:
                  _muted,
              fontSize:
                  12.5,
              height:
                  1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  false,
                );
              },
              child:
                  const Text(
                'Keep Address',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  true,
                );
              },
              style:
                  ElevatedButton
                      .styleFrom(
                backgroundColor:
                    _danger,
                foregroundColor:
                    Colors.white,
                elevation:
                    0,
              ),
              child:
                  const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    setState(() {
      _deletingAddressIds.add(
        address.id,
      );
    });

    try {
      await callback(
        address,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _addresses.removeWhere(
          (
            BuyerAddressData current,
          ) =>
              current.id ==
              address.id,
        );
      });

      _notifyAddressesChanged();

      _showMessage(
        'Address deleted.',
      );
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingAddressIds.remove(
            address.id,
          );
        });
      }
    }
  }

  void _notifyAddressesChanged() {
    widget.onAddressesChanged?.call(
      List<BuyerAddressData>.unmodifiable(
        _addresses,
      ),
    );
  }

  Future<void> _changePassword() async {
    FocusScope.of(
      context,
    ).unfocus();

    if (_changingPassword) {
      return;
    }

    if (!(_passwordFormKey.currentState
            ?.validate() ??
        false)) {
      return;
    }

    final ChangeBuyerPasswordCallback?
        callback =
        widget.onChangePassword;

    if (callback == null) {
      _showMessage(
        'Password changing will be connected to Laravel later.',
      );

      return;
    }

    setState(() {
      _changingPassword = true;
    });

    try {
      await callback(
        ChangeBuyerPasswordRequest(
          currentPassword:
              _currentPasswordController
                  .text,
          newPassword:
              _newPasswordController
                  .text,
          newPasswordConfirmation:
              _confirmPasswordController
                  .text,
        ),
      );

      if (!mounted) {
        return;
      }

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      setState(() {
        _showCurrentPassword =
            false;

        _showNewPassword =
            false;

        _showConfirmPassword =
            false;
      });

      _showMessage(
        'Password updated.',
      );
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _changingPassword = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              error
                  ? _danger
                  : _maroonDark,
          margin:
              const EdgeInsets.all(
            16,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          content:
              Text(
            message,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ),
      );
  }

  String _errorText(
    Object error,
  ) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          _background,
      body:
          SafeArea(
        bottom:
            false,
        child:
            Column(
          children: [
            _buildTopBar(),

            Expanded(
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
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior
                          .onDrag,
                  padding:
                      const EdgeInsets.fromLTRB(
                    14,
                    15,
                    14,
                    100,
                  ),
                  children: [
                    if (widget.buyerNotice
                            ?.trim()
                            .isNotEmpty ==
                        true) ...[
                      _MessageBanner(
                        message:
                            widget.buyerNotice!,
                        error:
                            false,
                      ),

                      const SizedBox(
                        height:
                            10,
                      ),
                    ],

                    if (widget.errorMessage
                            ?.trim()
                            .isNotEmpty ==
                        true) ...[
                      _MessageBanner(
                        message:
                            widget.errorMessage!,
                        error:
                            true,
                      ),

                      const SizedBox(
                        height:
                            10,
                      ),
                    ],

                    _buildHeading(),

                    const SizedBox(
                      height:
                          16,
                    ),

                    _buildAccountSummary(),

                    const SizedBox(
                      height:
                          13,
                    ),

                    _buildTabs(),

                    const SizedBox(
                      height:
                          13,
                    ),

                    AnimatedSwitcher(
                      duration:
                          const Duration(
                        milliseconds:
                            200,
                      ),
                      child:
                          KeyedSubtree(
                        key:
                            ValueKey<BuyerAccountTab>(
                          _activeTab,
                        ),
                        child:
                            _buildActiveContent(),
                      ),
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

  Widget _buildTopBar() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        7,
        5,
        12,
        7,
      ),
      decoration:
          const BoxDecoration(
        color:
            _background,
        border:
            Border(
          bottom:
              BorderSide(
            color:
                Color(
              0xFFF0E8DF,
            ),
          ),
        ),
      ),
      child:
          Row(
        children: [
          IconButton(
            tooltip:
                'Back',
            onPressed:
                widget.onBack ??
                () {
                  Navigator.of(
                    context,
                  ).maybePop();
                },
            icon:
                const Icon(
              Icons
                  .arrow_back_rounded,
              color:
                  _text,
            ),
          ),

          const SizedBox(
            width:
                2,
          ),

          const Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Account',
                  style:
                      TextStyle(
                    color:
                        _text,
                    fontSize:
                        19,
                    height:
                        1.1,
                    letterSpacing:
                        -0.4,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                SizedBox(
                  height:
                      2,
                ),

                Text(
                  'Profile, addresses and security',
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      TextStyle(
                    color:
                        _muted,
                    fontSize:
                        9.5,
                  ),
                ),
              ],
            ),
          ),

          if (_refreshing) ...[
            const SizedBox(
              width:
                  17,
              height:
                  17,
              child:
                  CircularProgressIndicator(
                strokeWidth:
                    2,
                color:
                    _maroon,
              ),
            ),

            const SizedBox(
              width:
                  9,
            ),
          ],

          if (widget.accountActive !=
              null)
            _AccountStatusBadge(
              active:
                  widget.accountActive!,
            ),
        ],
      ),
    );
  }

  Widget _buildHeading() {
    return const Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'BUYER CENTER',
          style:
              TextStyle(
            color:
                _maroon,
            fontSize:
                8.5,
            letterSpacing:
                1.7,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        SizedBox(
          height:
              5,
        ),

        Text(
          'Account Management',
          style:
              TextStyle(
            color:
                _text,
            fontSize:
                27,
            height:
                1.05,
            letterSpacing:
                -0.7,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        SizedBox(
          height:
              7,
        ),

        Text(
          'Manage your profile, delivery addresses, and account security.',
          style:
              TextStyle(
            color:
                _muted,
            fontSize:
                10.5,
            height:
                1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSummary() {
    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            _surface,
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        border:
            Border.all(
          color:
              _border,
        ),
      ),
      child:
          Row(
        children: [
          _ProfileAvatar(
            profile:
                _profile,
            selectedPhoto:
                _selectedPhoto,
            size:
                50,
          ),

          const SizedBox(
            width:
                11,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _profile.name,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        _text,
                    fontSize:
                        12.5,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height:
                      3,
                ),

                Text(
                  _profile.email,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        _muted,
                    fontSize:
                        9.5,
                  ),
                ),

                if (_profile.phone
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(
                    height:
                        3,
                  ),

                  Text(
                    _profile.phone,
                    maxLines:
                        1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color:
                          _muted2,
                      fontSize:
                          8.5,
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

  Widget _buildTabs() {
    return SizedBox(
      height:
          58,
      child:
          ListView.separated(
        scrollDirection:
            Axis.horizontal,
        physics:
            const BouncingScrollPhysics(),
        itemCount:
            BuyerAccountTab.values.length,
        separatorBuilder:
            (
          BuildContext context,
          int index,
        ) {
          return const SizedBox(
            width:
                7,
          );
        },
        itemBuilder:
            (
          BuildContext context,
          int index,
        ) {
          final BuyerAccountTab tab =
              BuyerAccountTab.values[index];

          final bool selected =
              tab ==
                  _activeTab;

          return Material(
            color:
                selected
                    ? const Color(
                        0xFFF1E4D7,
                      )
                    : _surface,
            borderRadius:
                BorderRadius.circular(
              13,
            ),
            child:
                InkWell(
              onTap:
                  () {
                _changeTab(
                  tab,
                );
              },
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
              child:
                  Container(
                constraints:
                    const BoxConstraints(
                  minWidth:
                      130,
                ),
                padding:
                    const EdgeInsets.symmetric(
                  horizontal:
                      13,
                ),
                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                  border:
                      Border.all(
                    color:
                        selected
                            ? _tan
                            : _border,
                  ),
                ),
                child:
                    Row(
                  children: [
                    Icon(
                      tab.icon,
                      color:
                          selected
                              ? _maroon
                              : _muted,
                      size:
                          18,
                    ),

                    const SizedBox(
                      width:
                          8,
                    ),

                    Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          tab.label,
                          style:
                              TextStyle(
                            color:
                                selected
                                    ? _maroon
                                    : _text,
                            fontSize:
                                10,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),

                        const SizedBox(
                          height:
                              2,
                        ),

                        Text(
                          tab.description,
                          style:
                              const TextStyle(
                            color:
                                _muted2,
                            fontSize:
                                7.5,
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

      case BuyerAccountTab.password:
        return _buildPasswordSection();
    }
  }

  Widget _buildProfileSection() {
    return _AccountPanel(
      title:
          'Profile Information',
      subtitle:
          'Update your personal details and profile photo.',
      icon:
          Icons.person_outline_rounded,
      child:
          Form(
        key:
            _profileFormKey,
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Container(
              padding:
                  const EdgeInsets.all(
                14,
              ),
              decoration:
                  BoxDecoration(
                color:
                    _soft,
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                border:
                    Border.all(
                  color:
                      _border,
                ),
              ),
              child:
                  Column(
                children: [
                  _ProfileAvatar(
                    profile:
                        _profile,
                    selectedPhoto:
                        _selectedPhoto,
                    size:
                        82,
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  const Text(
                    'Profile photo',
                    style:
                        TextStyle(
                      color:
                          _text,
                      fontSize:
                          12,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  const SizedBox(
                    height:
                        4,
                  ),

                  const Text(
                    'Choose an image up to 2 MB. Laravel will perform the final image validation.',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          _muted,
                      fontSize:
                          9.5,
                      height:
                          1.4,
                    ),
                  ),

                  if (_selectedPhoto !=
                      null) ...[
                    const SizedBox(
                      height:
                          6,
                    ),

                    Text(
                      '${_selectedPhoto!.fileName} · ${_formatFileSize(_selectedPhoto!.sizeInBytes)}',
                      maxLines:
                          1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color:
                            _brown,
                        fontSize:
                            8.5,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],

                  const SizedBox(
                    height:
                        12,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child:
                            ElevatedButton.icon(
                          onPressed:
                              _savingProfile ||
                                      _removingPhoto
                                  ? null
                                  : _pickPhoto,
                          style:
                              ElevatedButton.styleFrom(
                            elevation:
                                0,
                            backgroundColor:
                                _maroon,
                            foregroundColor:
                                Colors.white,
                            minimumSize:
                                const Size.fromHeight(
                              44,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                11,
                              ),
                            ),
                          ),
                          icon:
                              const Icon(
                            Icons
                                .photo_camera_outlined,
                            size:
                                17,
                          ),
                          label:
                              const Text(
                            'Choose Photo',
                            style:
                                TextStyle(
                              fontSize:
                                  10,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        width:
                            8,
                      ),

                      Expanded(
                        child:
                            OutlinedButton.icon(
                          onPressed:
                              _removingPhoto ||
                                      _savingProfile ||
                                      (_selectedPhoto ==
                                              null &&
                                          (_profile.profilePhotoUrl ==
                                                  null ||
                                              _profile.profilePhotoUrl!
                                                  .trim()
                                                  .isEmpty))
                                  ? null
                                  : _removeProfilePhoto,
                          style:
                              OutlinedButton.styleFrom(
                            foregroundColor:
                                _brown,
                            side:
                                const BorderSide(
                              color:
                                  _border,
                            ),
                            minimumSize:
                                const Size.fromHeight(
                              44,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                11,
                              ),
                            ),
                          ),
                          icon:
                              _removingPhoto
                                  ? const SizedBox(
                                      width:
                                          16,
                                      height:
                                          16,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth:
                                            2,
                                        color:
                                            _maroon,
                                      ),
                                    )
                                  : const Icon(
                                      Icons
                                          .delete_outline_rounded,
                                      size:
                                          16,
                                    ),
                          label:
                              const Text(
                            'Remove',
                            style:
                                TextStyle(
                              fontSize:
                                  10,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(
              height:
                  18,
            ),

            const _FieldLabel(
              text:
                  'Full name',
            ),

            const SizedBox(
              height:
                  7,
            ),

            TextFormField(
              controller:
                  _nameController,
              textCapitalization:
                  TextCapitalization.words,
              textInputAction:
                  TextInputAction.next,
              maxLength:
                  160,
              decoration:
                  _inputDecoration(
                hintText:
                    'Full name',
                prefixIcon:
                    Icons
                        .person_outline,
              ).copyWith(
                counterText:
                    '',
              ),
              validator:
                  (
                String? value,
              ) {
                final String name =
                    value?.trim() ??
                        '';

                if (name.isEmpty) {
                  return 'Enter your full name.';
                }

                if (name.length >
                    160) {
                  return 'Full name must not exceed 160 characters.';
                }

                return null;
              },
            ),

            const SizedBox(
              height:
                  15,
            ),

            const _FieldLabel(
              text:
                  'Email address',
            ),

            const SizedBox(
              height:
                  7,
            ),

            TextFormField(
              controller:
                  _emailController,
              keyboardType:
                  TextInputType.emailAddress,
              textInputAction:
                  TextInputAction.next,
              maxLength:
                  255,
              autofillHints:
                  const <String>[
                AutofillHints.email,
              ],
              decoration:
                  _inputDecoration(
                hintText:
                    'Email address',
                prefixIcon:
                    Icons
                        .email_outlined,
              ).copyWith(
                counterText:
                    '',
              ),
              validator:
                  (
                String? value,
              ) {
                final String email =
                    value?.trim() ??
                        '';

                if (email.isEmpty) {
                  return 'Enter your email address.';
                }

                if (email.length >
                    255) {
                  return 'Email must not exceed 255 characters.';
                }

                final RegExp emailPattern =
                    RegExp(
                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                );

                if (!emailPattern.hasMatch(
                  email,
                )) {
                  return 'Enter a valid email address.';
                }

                return null;
              },
            ),

            const SizedBox(
              height:
                  15,
            ),

            const _FieldLabel(
              text:
                  'Mobile number',
              requiredField:
                  false,
            ),

            const SizedBox(
              height:
                  7,
            ),

            TextFormField(
              controller:
                  _phoneController,
              keyboardType:
                  TextInputType.phone,
              textInputAction:
                  TextInputAction.next,
              maxLength:
                  40,
              autofillHints:
                  const <String>[
                AutofillHints.telephoneNumber,
              ],
              decoration:
                  _inputDecoration(
                hintText:
                    'Contact number',
                prefixIcon:
                    Icons
                        .phone_outlined,
              ).copyWith(
                counterText:
                    '',
              ),
              validator:
                  (
                String? value,
              ) {
                if ((value ?? '')
                        .trim()
                        .length >
                    40) {
                  return 'Contact number must not exceed 40 characters.';
                }

                return null;
              },
            ),

            const SizedBox(
              height:
                  15,
            ),

            const _FieldLabel(
              text:
                  'Date of birth',
              requiredField:
                  false,
            ),

            const SizedBox(
              height:
                  7,
            ),

            InkWell(
              onTap:
                  _savingProfile
                      ? null
                      : _selectBirthday,
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
              child:
                  InputDecorator(
                decoration:
                    _inputDecoration(
                  hintText:
                      'Select birthday',
                  prefixIcon:
                      Icons
                          .calendar_today_outlined,
                ),
                child:
                    Text(
                  _birthday ==
                          null
                      ? 'Select birthday'
                      : _formatDate(
                          _birthday!,
                        ),
                  style:
                      TextStyle(
                    color:
                        _birthday ==
                                null
                            ? _muted2
                            : _text,
                    fontSize:
                        11.5,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height:
                  15,
            ),

            const _FieldLabel(
              text:
                  'Gender',
              requiredField:
                  false,
            ),

            const SizedBox(
              height:
                  7,
            ),

            DropdownButtonFormField<
                BuyerGender?>(
              initialValue:
                  _gender,
              isExpanded:
                  true,
              decoration:
                  _inputDecoration(
                hintText:
                    'Prefer not to say',
                prefixIcon:
                    Icons
                        .wc_outlined,
              ),
              items:
                  <DropdownMenuItem<BuyerGender?>>[
                const DropdownMenuItem<
                    BuyerGender?>(
                  value:
                      null,
                  child:
                      Text(
                    'Prefer not to say',
                  ),
                ),
                ...BuyerGender.values.map(
                  (
                    BuyerGender gender,
                  ) {
                    return DropdownMenuItem<
                        BuyerGender?>(
                      value:
                          gender,
                      child:
                          Text(
                        gender.label,
                      ),
                    );
                  },
                ),
              ],
              onChanged:
                  _savingProfile
                      ? null
                      : (
                          BuyerGender? value,
                        ) {
                          setState(() {
                            _gender =
                                value;
                          });
                        },
            ),

            const SizedBox(
              height:
                  20,
            ),

            SizedBox(
              height:
                  49,
              child:
                  ElevatedButton(
                onPressed:
                    _savingProfile ||
                            _removingPhoto
                        ? null
                        : _saveProfile,
                style:
                    ElevatedButton.styleFrom(
                  elevation:
                      0,
                  backgroundColor:
                      _maroon,
                  foregroundColor:
                      Colors.white,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      13,
                    ),
                  ),
                ),
                child:
                    _savingProfile
                        ? const SizedBox(
                            width:
                                20,
                            height:
                                20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style:
                                TextStyle(
                              fontSize:
                                  11,
                              fontWeight:
                                  FontWeight.w800,
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
      title:
          'Delivery Addresses',
      subtitle:
          'Saved addresses are used for future checkouts. Existing orders keep their original delivery details.',
      icon:
          Icons.location_on_outlined,
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          if (_addresses.isEmpty)
            Container(
              padding:
                  const EdgeInsets.all(
                18,
              ),
              decoration:
                  BoxDecoration(
                color:
                    _soft,
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child:
                  const Column(
                children: [
                  Icon(
                    Icons
                        .location_off_outlined,
                    color:
                        _muted2,
                    size:
                        30,
                  ),

                  SizedBox(
                    height:
                        9,
                  ),

                  Text(
                    'No saved delivery address yet.',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          _muted,
                      fontSize:
                          10.5,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._addresses.map(
              (
                BuyerAddressData address,
              ) {
                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom:
                        10,
                  ),
                  child:
                      _AddressCard(
                    address:
                        address,
                    deleting:
                        _deletingAddressIds.contains(
                      address.id,
                    ),
                    onDelete:
                        () {
                      _deleteAddress(
                        address,
                      );
                    },
                  ),
                );
              },
            ),

          const SizedBox(
            height:
                8,
          ),

          Container(
            padding:
                const EdgeInsets.all(
              14,
            ),
            decoration:
                BoxDecoration(
              color:
                  _soft,
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
              border:
                  Border.all(
                color:
                    _border,
              ),
            ),
            child:
                Form(
              key:
                  _addressFormKey,
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons
                            .add_location_alt_outlined,
                        color:
                            _maroon,
                        size:
                            19,
                      ),

                      SizedBox(
                        width:
                            7,
                      ),

                      Text(
                        'Add delivery address',
                        style:
                            TextStyle(
                          color:
                              _text,
                          fontSize:
                              12.5,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height:
                        7,
                  ),

                  const Text(
                    'Region, province, municipality and barangay can later use the same Philippine address API as registration. The save request remains compatible with Laravel address fields.',
                    style:
                        TextStyle(
                      color:
                          _muted,
                      fontSize:
                          8.5,
                      height:
                          1.45,
                    ),
                  ),

                  const SizedBox(
                    height:
                        16,
                  ),

                  _AddressInput(
                    label:
                        'Label',
                    controller:
                        _addressLabelController,
                    hint:
                        'Home, Work',
                    requiredField:
                        true,
                    maxLength:
                        80,
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _AddressInput(
                    label:
                        'Recipient name',
                    controller:
                        _recipientNameController,
                    hint:
                        'Recipient name',
                    requiredField:
                        true,
                    maxLength:
                        160,
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _AddressInput(
                    label:
                        'Contact number',
                    controller:
                        _addressPhoneController,
                    hint:
                        'Contact number',
                    keyboardType:
                        TextInputType.phone,
                    requiredField:
                        true,
                    maxLength:
                        40,
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _AddressInput(
                    label:
                        'House / unit number',
                    controller:
                        _houseNumberController,
                    hint:
                        'House / unit number',
                    maxLength:
                        80,
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _AddressInput(
                    label:
                        'Street',
                    controller:
                        _streetController,
                    hint:
                        'Street',
                    maxLength:
                        255,
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _AddressInput(
                    label:
                        'Barangay',
                    controller:
                        _barangayController,
                    hint:
                        'Barangay',
                    maxLength:
                        160,
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _AddressInput(
                    label:
                        'Municipality / City',
                    controller:
                        _municipalityController,
                    hint:
                        'Municipality / City',
                    maxLength:
                        160,
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _AddressInput(
                    label:
                        'Province',
                    controller:
                        _provinceController,
                    hint:
                        'Province',
                    maxLength:
                        160,
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _AddressInput(
                    label:
                        'Region',
                    controller:
                        _regionController,
                    hint:
                        'Region',
                    maxLength:
                        160,
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _AddressInput(
                    label:
                        'Postal code',
                    controller:
                        _postalCodeController,
                    hint:
                        'Postal code',
                    keyboardType:
                        TextInputType.text,
                    maxLength:
                        20,
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _AddressInput(
                    label:
                        'Landmark',
                    controller:
                        _landmarkController,
                    hint:
                        'Landmark',
                    maxLength:
                        255,
                  ),

                  const SizedBox(
                    height:
                        13,
                  ),

                  Material(
                    color:
                        Colors.transparent,
                    child:
                        InkWell(
                      onTap:
                          _addingAddress
                              ? null
                              : () {
                                  setState(() {
                                    _newAddressIsDefault =
                                        !_newAddressIsDefault;
                                  });
                                },
                      borderRadius:
                          BorderRadius.circular(
                        11,
                      ),
                      child:
                          Padding(
                        padding:
                            const EdgeInsets.symmetric(
                          vertical:
                              5,
                        ),
                        child:
                            Row(
                          children: [
                            Checkbox(
                              value:
                                  _newAddressIsDefault,
                              activeColor:
                                  _maroon,
                              onChanged:
                                  _addingAddress
                                      ? null
                                      : (
                                          bool? value,
                                        ) {
                                          setState(() {
                                            _newAddressIsDefault =
                                                value ??
                                                    false;
                                          });
                                        },
                            ),

                            const Expanded(
                              child:
                                  Text(
                                'Set as default address',
                                style:
                                    TextStyle(
                                  color:
                                      _text,
                                  fontSize:
                                      10.5,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  SizedBox(
                    height:
                        49,
                    child:
                        ElevatedButton(
                      onPressed:
                          _addingAddress
                              ? null
                              : _addAddress,
                      style:
                          ElevatedButton.styleFrom(
                        elevation:
                            0,
                        backgroundColor:
                            _maroon,
                        foregroundColor:
                            Colors.white,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            13,
                          ),
                        ),
                      ),
                      child:
                          _addingAddress
                              ? const SizedBox(
                                  width:
                                      20,
                                  height:
                                      20,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                    color:
                                        Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Address',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        11,
                                    fontWeight:
                                        FontWeight.w800,
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

  Widget _buildPasswordSection() {
    return _AccountPanel(
      title:
          'Change Password',
      subtitle:
          'Enter your current password before setting a new one.',
      icon:
          Icons.lock_outline_rounded,
      child:
          Form(
        key:
            _passwordFormKey,
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            const _FieldLabel(
              text:
                  'Current password',
            ),

            const SizedBox(
              height:
                  7,
            ),

            TextFormField(
              controller:
                  _currentPasswordController,
              obscureText:
                  !_showCurrentPassword,
              textInputAction:
                  TextInputAction.next,
              autofillHints:
                  const <String>[
                AutofillHints.password,
              ],
              decoration:
                  _passwordDecoration(
                hintText:
                    'Current password',
                visible:
                    _showCurrentPassword,
                onToggle:
                    () {
                  setState(() {
                    _showCurrentPassword =
                        !_showCurrentPassword;
                  });
                },
              ),
              validator:
                  (
                String? value,
              ) {
                if (value == null ||
                    value.isEmpty) {
                  return 'Enter your current password.';
                }

                return null;
              },
            ),

            const SizedBox(
              height:
                  15,
            ),

            const _FieldLabel(
              text:
                  'New password',
            ),

            const SizedBox(
              height:
                  7,
            ),

            TextFormField(
              controller:
                  _newPasswordController,
              obscureText:
                  !_showNewPassword,
              textInputAction:
                  TextInputAction.next,
              autofillHints:
                  const <String>[
                AutofillHints.newPassword,
              ],
              decoration:
                  _passwordDecoration(
                hintText:
                    'New password',
                visible:
                    _showNewPassword,
                onToggle:
                    () {
                  setState(() {
                    _showNewPassword =
                        !_showNewPassword;
                  });
                },
              ),
              validator:
                  (
                String? value,
              ) {
                final String password =
                    value ??
                        '';

                if (password.isEmpty) {
                  return 'Enter a new password.';
                }

                /*
                 * Match Laravel:
                 *
                 * required
                 * string
                 * minimum 8
                 * confirmed
                 *
                 * Do not invent uppercase/number/special-
                 * character requirements here.
                 */
                if (password.length <
                    8) {
                  return 'Use at least 8 characters.';
                }

                return null;
              },
            ),

            const SizedBox(
              height:
                  15,
            ),

            const _FieldLabel(
              text:
                  'Confirm new password',
            ),

            const SizedBox(
              height:
                  7,
            ),

            TextFormField(
              controller:
                  _confirmPasswordController,
              obscureText:
                  !_showConfirmPassword,
              textInputAction:
                  TextInputAction.done,
              autofillHints:
                  const <String>[
                AutofillHints.newPassword,
              ],
              decoration:
                  _passwordDecoration(
                hintText:
                    'Confirm new password',
                visible:
                    _showConfirmPassword,
                onToggle:
                    () {
                  setState(() {
                    _showConfirmPassword =
                        !_showConfirmPassword;
                  });
                },
              ),
              onFieldSubmitted:
                  (_) {
                if (!_changingPassword) {
                  _changePassword();
                }
              },
              validator:
                  (
                String? value,
              ) {
                if (value == null ||
                    value.isEmpty) {
                  return 'Confirm your new password.';
                }

                if (value !=
                    _newPasswordController
                        .text) {
                  return 'Passwords do not match.';
                }

                return null;
              },
            ),

            const SizedBox(
              height:
                  17,
            ),

            Container(
              padding:
                  const EdgeInsets.all(
                13,
              ),
              decoration:
                  BoxDecoration(
                color:
                    _soft,
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                border:
                    Border.all(
                  color:
                      _border,
                ),
              ),
              child:
                  const Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons
                        .shield_outlined,
                    color:
                        _maroon,
                    size:
                        18,
                  ),

                  SizedBox(
                    width:
                        8,
                  ),

                  Expanded(
                    child:
                        Text(
                      'Your new password must contain at least 8 characters and must match the confirmation field.',
                      style:
                          TextStyle(
                        color:
                            _brown,
                        fontSize:
                            9.5,
                        height:
                            1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height:
                  18,
            ),

            SizedBox(
              height:
                  49,
              child:
                  ElevatedButton(
                onPressed:
                    _changingPassword
                        ? null
                        : _changePassword,
                style:
                    ElevatedButton.styleFrom(
                  elevation:
                      0,
                  backgroundColor:
                      _maroon,
                  foregroundColor:
                      Colors.white,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      13,
                    ),
                  ),
                ),
                child:
                    _changingPassword
                        ? const SizedBox(
                            width:
                                20,
                            height:
                                20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Text(
                            'Update Password',
                            style:
                                TextStyle(
                              fontSize:
                                  11,
                              fontWeight:
                                  FontWeight.w800,
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
      hintText:
          hintText,
      hintStyle:
          const TextStyle(
        color:
            _muted2,
        fontSize:
            11,
      ),
      prefixIcon:
          prefixIcon ==
                  null
              ? null
              : Icon(
                  prefixIcon,
                  color:
                      _muted,
                  size:
                      19,
                ),
      filled:
          true,
      fillColor:
          _surface,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal:
            13,
        vertical:
            14,
      ),
      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        borderSide:
            const BorderSide(
          color:
              _border,
        ),
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        borderSide:
            const BorderSide(
          color:
              _border,
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        borderSide:
            const BorderSide(
          color:
              _maroon,
          width:
              1.3,
        ),
      ),
      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        borderSide:
            const BorderSide(
          color:
              _danger,
        ),
      ),
      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        borderSide:
            const BorderSide(
          color:
              _danger,
          width:
              1.3,
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
      hintText:
          hintText,
      prefixIcon:
          Icons.lock_outline_rounded,
    ).copyWith(
      suffixIcon:
          IconButton(
        tooltip:
            visible
                ? 'Hide password'
                : 'Show password',
        onPressed:
            onToggle,
        icon:
            Icon(
          visible
              ? Icons
                  .visibility_off_outlined
              : Icons
                  .visibility_outlined,
          color:
              _muted,
          size:
              19,
        ),
      ),
    );
  }

  static String _formatDate(
    DateTime value,
  ) {
    final String month =
        value.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String day =
        value.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '${value.year}-$month-$day';
  }

  static String _formatFileSize(
    int bytes,
  ) {
    if (bytes >=
        1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }

    if (bytes >=
        1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '$bytes B';
  }
}

class _AccountStatusBadge
    extends StatelessWidget {
  final bool active;

  const _AccountStatusBadge({
    required this.active,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            9,
        vertical:
            6,
      ),
      decoration:
          BoxDecoration(
        color:
            active
                ? const Color(
                    0xFFEEF8F1,
                  )
                : const Color(
                    0xFFF6EFE7,
                  ),
        borderRadius:
            BorderRadius.circular(
          100,
        ),
        border:
            Border.all(
          color:
              active
                  ? const Color(
                      0xFFCDE5D4,
                    )
                  : const Color(
                      0xFFEADCCC,
                    ),
        ),
      ),
      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Container(
            width:
                7,
            height:
                7,
            decoration:
                BoxDecoration(
              color:
                  active
                      ? const Color(
                          0xFF256F4A,
                        )
                      : const Color(
                          0xFFA99386,
                        ),
              shape:
                  BoxShape.circle,
            ),
          ),

          const SizedBox(
            width:
                5,
          ),

          Text(
            active
                ? 'Active'
                : 'Inactive',
            style:
                TextStyle(
              color:
                  active
                      ? const Color(
                          0xFF256F4A,
                        )
                      : const Color(
                          0xFF987865,
                        ),
              fontSize:
                  8.5,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountPanel
    extends StatelessWidget {
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
  Widget build(
    BuildContext context,
  ) {
    return Container(
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFFFFDF9,
        ),
        borderRadius:
            BorderRadius.circular(
          19,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFEADCCC,
          ),
        ),
        boxShadow:
            <BoxShadow>[
          BoxShadow(
            color:
                const Color(
              0xFF561C17,
            ).withValues(
              alpha: 0.035,
            ),
            blurRadius:
                18,
            offset:
                const Offset(
              0,
              7,
            ),
          ),
        ],
      ),
      child:
          Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.all(
              15,
            ),
            child:
                Row(
              children: [
                Container(
                  width:
                      40,
                  height:
                      40,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFF1E4D7,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  alignment:
                      Alignment.center,
                  child:
                      Icon(
                    icon,
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
                    children: [
                      Text(
                        title,
                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xFF3B211B,
                          ),
                          fontSize:
                              13,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),

                      const SizedBox(
                        height:
                            3,
                      ),

                      Text(
                        subtitle,
                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xFF987865,
                          ),
                          fontSize:
                              9.5,
                          height:
                              1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height:
                1,
            color:
                Color(
              0xFFF0E8DF,
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.all(
              15,
            ),
            child:
                child,
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar
    extends StatelessWidget {
  final BuyerProfileData profile;

  final SelectedProfilePhoto?
      selectedPhoto;

  final double size;

  const _ProfileAvatar({
    required this.profile,
    required this.selectedPhoto,
    required this.size,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final SelectedProfilePhoto? local =
        selectedPhoto;

    final String? remote =
        profile.profilePhotoUrl
            ?.trim();

    return Container(
      width:
          size,
      height:
          size,
      clipBehavior:
          Clip.antiAlias,
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFF1E4D7,
        ),
        shape:
            BoxShape.circle,
        border:
            Border.all(
          color:
              const Color(
            0xFFEADCCC,
          ),
        ),
      ),
      child:
          local !=
                  null
              ? Image.memory(
                  local.bytes,
                  fit:
                      BoxFit.cover,
                  errorBuilder:
                      (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) {
                    return _AvatarInitial(
                      value:
                          profile.initial,
                    );
                  },
                )
              : remote !=
                          null &&
                      remote.isNotEmpty
                  ? Image.network(
                      remote,
                      fit:
                          BoxFit.cover,
                      errorBuilder:
                          (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return _AvatarInitial(
                          value:
                              profile.initial,
                        );
                      },
                      loadingBuilder:
                          (
                        BuildContext context,
                        Widget child,
                        ImageChunkEvent? progress,
                      ) {
                        if (progress ==
                            null) {
                          return child;
                        }

                        return const Center(
                          child:
                              SizedBox(
                            width:
                                18,
                            height:
                                18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  Color(
                                0xFF561C17,
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : _AvatarInitial(
                      value:
                          profile.initial,
                    ),
    );
  }
}

class _AvatarInitial
    extends StatelessWidget {
  final String value;

  const _AvatarInitial({
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      alignment:
          Alignment.center,
      color:
          const Color(
        0xFFF1E4D7,
      ),
      child:
          Text(
        value,
        style:
            const TextStyle(
          color:
              Color(
            0xFF561C17,
          ),
          fontSize:
              18,
          fontWeight:
              FontWeight.w900,
        ),
      ),
    );
  }
}

class _AddressCard
    extends StatelessWidget {
  final BuyerAddressData address;

  final bool deleting;

  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    required this.deleting,
    required this.onDelete,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        13,
      ),
      decoration:
          BoxDecoration(
        color:
            address.isDefault
                ? const Color(
                    0xFFFFF4F0,
                  )
                : const Color(
                    0xFFFFFDF9,
                  ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border:
            Border.all(
          color:
              address.isDefault
                  ? const Color(
                      0xFFD9B09D,
                    )
                  : const Color(
                      0xFFEADCCC,
                    ),
        ),
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width:
                39,
            height:
                39,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF1E4D7,
              ),
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            alignment:
                Alignment.center,
            child:
                const Icon(
              Icons
                  .location_on_outlined,
              color:
                  Color(
                0xFF561C17,
              ),
              size:
                  19,
            ),
          ),

          const SizedBox(
            width:
                9,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing:
                      6,
                  runSpacing:
                      5,
                  crossAxisAlignment:
                      WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${address.label} · ${address.recipientName}',
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF3B211B,
                        ),
                        fontSize:
                            11,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    if (address.isDefault)
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal:
                              7,
                          vertical:
                              3,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFF1E4D7,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            100,
                          ),
                        ),
                        child:
                            const Text(
                          'DEFAULT',
                          style:
                              TextStyle(
                            color:
                                Color(
                              0xFF561C17,
                            ),
                            fontSize:
                                7,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),

                if (address.contactNumber
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(
                    height:
                        5,
                  ),

                  Text(
                    address.contactNumber,
                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xFF6C4936,
                      ),
                      fontSize:
                          9.5,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(
                  height:
                      7,
                ),

                Text(
                  address.displayAddress
                          .isEmpty
                      ? 'No formatted address available.'
                      : address.displayAddress,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF987865,
                    ),
                    fontSize:
                        10,
                    height:
                        1.5,
                  ),
                ),

                if (address.landmark
                        ?.trim()
                        .isNotEmpty ==
                    true) ...[
                  const SizedBox(
                    height:
                        5,
                  ),

                  Text(
                    'Landmark: ${address.landmark}',
                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xFFA99386,
                      ),
                      fontSize:
                          9,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(
            width:
                6,
          ),

          IconButton(
            tooltip:
                'Delete address',
            onPressed:
                deleting
                    ? null
                    : onDelete,
            icon:
                deleting
                    ? const SizedBox(
                        width:
                            17,
                        height:
                            17,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,
                          color:
                              Color(
                            0xFFB42318,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons
                            .delete_outline_rounded,
                        color:
                            Color(
                          0xFFB42318,
                        ),
                        size:
                            19,
                      ),
          ),
        ],
      ),
    );
  }
}

class _AddressInput
    extends StatelessWidget {
  final String label;

  final TextEditingController controller;

  final String hint;

  final TextInputType keyboardType;

  final bool requiredField;

  final int maxLength;

  const _AddressInput({
    required this.label,
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.keyboardType =
        TextInputType.text,
    this.requiredField =
        false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _FieldLabel(
          text:
              label,
          requiredField:
              requiredField,
        ),

        const SizedBox(
          height:
              6,
        ),

        TextFormField(
          controller:
              controller,
          keyboardType:
              keyboardType,
          maxLength:
              maxLength,
          textCapitalization:
              keyboardType ==
                          TextInputType.phone ||
                      keyboardType ==
                          TextInputType.number
                  ? TextCapitalization.none
                  : TextCapitalization.words,
          decoration:
              _accountInputDecoration(
            hintText:
                hint,
          ).copyWith(
            counterText:
                '',
          ),
          validator:
              (
            String? value,
          ) {
            final String text =
                value?.trim() ??
                    '';

            if (requiredField &&
                text.isEmpty) {
              return 'Required.';
            }

            if (text.length >
                maxLength) {
              return 'Maximum $maxLength characters.';
            }

            return null;
          },
        ),
      ],
    );
  }
}

class _FieldLabel
    extends StatelessWidget {
  final String text;

  final bool requiredField;

  const _FieldLabel({
    required this.text,
    this.requiredField =
        true,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Text.rich(
      TextSpan(
        children:
            <InlineSpan>[
          TextSpan(
            text:
                text,
          ),

          if (requiredField)
            const TextSpan(
              text:
                  ' *',
              style:
                  TextStyle(
                color:
                    Color(
                  0xFFB42318,
                ),
              ),
            ),
        ],
      ),
      style:
          const TextStyle(
        color:
            Color(
          0xFF3B211B,
        ),
        fontSize:
            10.5,
        fontWeight:
            FontWeight.w700,
      ),
    );
  }
}

class _MessageBanner
    extends StatelessWidget {
  final String message;

  final bool error;

  const _MessageBanner({
    required this.message,
    required this.error,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            error
                ? const Color(
                    0xFFFCECE7,
                  )
                : const Color(
                    0xFFEEF8F1,
                  ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border:
            Border.all(
          color:
              error
                  ? const Color(
                      0xFFEBC9C0,
                    )
                  : const Color(
                      0xFFCDE5D4,
                    ),
        ),
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            error
                ? Icons
                    .error_outline_rounded
                : Icons
                    .check_circle_outline_rounded,
            color:
                error
                    ? const Color(
                        0xFFB42318,
                      )
                    : const Color(
                        0xFF256F4A,
                      ),
            size:
                18,
          ),

          const SizedBox(
            width:
                8,
          ),

          Expanded(
            child:
                Text(
              message,
              style:
                  TextStyle(
                color:
                    error
                        ? const Color(
                            0xFFB42318,
                          )
                        : const Color(
                            0xFF256F4A,
                          ),
                fontSize:
                    10,
                height:
                    1.45,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _accountInputDecoration({
  required String hintText,
}) {
  return InputDecoration(
    hintText:
        hintText,
    hintStyle:
        const TextStyle(
      color:
          Color(
        0xFFA99386,
      ),
      fontSize:
          11,
    ),
    filled:
        true,
    fillColor:
        const Color(
      0xFFFFFDF9,
    ),
    contentPadding:
        const EdgeInsets.symmetric(
      horizontal:
          13,
      vertical:
          14,
    ),
    border:
        OutlineInputBorder(
      borderRadius:
          BorderRadius.circular(
        12,
      ),
      borderSide:
          const BorderSide(
        color:
            Color(
          0xFFEADCCC,
        ),
      ),
    ),
    enabledBorder:
        OutlineInputBorder(
      borderRadius:
          BorderRadius.circular(
        12,
      ),
      borderSide:
          const BorderSide(
        color:
            Color(
          0xFFEADCCC,
        ),
      ),
    ),
    focusedBorder:
        OutlineInputBorder(
      borderRadius:
          BorderRadius.circular(
        12,
      ),
      borderSide:
          const BorderSide(
        color:
            Color(
          0xFF561C17,
        ),
        width:
            1.3,
      ),
    ),
    errorBorder:
        OutlineInputBorder(
      borderRadius:
          BorderRadius.circular(
        12,
      ),
      borderSide:
          const BorderSide(
        color:
            Color(
          0xFFB42318,
        ),
      ),
    ),
    focusedErrorBorder:
        OutlineInputBorder(
      borderRadius:
          BorderRadius.circular(
        12,
      ),
      borderSide:
          const BorderSide(
        color:
            Color(
          0xFFB42318,
        ),
        width:
            1.3,
      ),
    ),
  );
}