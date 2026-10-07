import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum MobileAccountType {
  buyer,
  rider,
}

enum RegistrationDocumentType {
  validId,
  vehicleOrCr,
  driversLicense,
}

class AddressOption {
  final String code;
  final String name;

  const AddressOption({
    required this.code,
    required this.name,
  });
}

class RegistrationDocument {
  final String name;
  final String? path;

  const RegistrationDocument({
    required this.name,
    this.path,
  });
}

class RegisterFormData {
  final MobileAccountType accountType;

  final String firstName;
  final String middleInitial;
  final String lastName;
  final String sex;

  final DateTime birthday;
  final int age;

  final String email;
  final String contactNumber;

  final AddressOption region;
  final AddressOption province;
  final AddressOption municipality;
  final AddressOption barangay;

  final String street;
  final String houseNumber;
  final String postalCode;
  final String landmark;

  final String? vehicleType;
  final String? plateNumber;

  final RegistrationDocument validId;
  final RegistrationDocument? vehicleOrCr;
  final RegistrationDocument? driversLicense;

  final String password;

  const RegisterFormData({
    required this.accountType,
    required this.firstName,
    required this.middleInitial,
    required this.lastName,
    required this.sex,
    required this.birthday,
    required this.age,
    required this.email,
    required this.contactNumber,
    required this.region,
    required this.province,
    required this.municipality,
    required this.barangay,
    required this.street,
    required this.houseNumber,
    required this.postalCode,
    required this.landmark,
    required this.vehicleType,
    required this.plateNumber,
    required this.validId,
    required this.vehicleOrCr,
    required this.driversLicense,
    required this.password,
  });
}

typedef RegistrationSubmitCallback = Future<void> Function(
  RegisterFormData data,
);

typedef AddressLoader = Future<List<AddressOption>> Function();

typedef ChildAddressLoader = Future<List<AddressOption>> Function(
  String parentCode,
);

typedef PostalCodeLoader = Future<String?> Function({
  required String municipalityCode,
  required String barangayCode,
});

typedef DocumentPickerCallback = Future<RegistrationDocument?> Function(
  RegistrationDocumentType type,
);

class RegisterScreen extends StatefulWidget {
  final RegistrationSubmitCallback? onSubmit;

  final AddressLoader? loadRegions;
  final ChildAddressLoader? loadProvinces;
  final ChildAddressLoader? loadMunicipalities;
  final ChildAddressLoader? loadBarangays;
  final PostalCodeLoader? loadPostalCode;

  final DocumentPickerCallback? onPickDocument;

  const RegisterScreen({
    super.key,
    this.onSubmit,
    this.loadRegions,
    this.loadProvinces,
    this.loadMunicipalities,
    this.loadBarangays,
    this.loadPostalCode,
    this.onPickDocument,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const Color _background = Color(0xFFF4F1EB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF191816);
  static const Color _secondaryText = Color(0xFF77716B);
  static const Color _border = Color(0xFFE4E0DA);
  static const Color _fieldBackground = Color(0xFFFBFAF8);
  static const Color _accent = Color(0xFFD94343);

  final PageController _pageController = PageController();

  final GlobalKey<FormState> _personalFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _contactFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _addressFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _vehicleFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _verificationFormKey =
      GlobalKey<FormState>();

  final TextEditingController _firstNameController =
      TextEditingController();

  final TextEditingController _middleNameController =
      TextEditingController();

  final TextEditingController _lastNameController =
      TextEditingController();

  final TextEditingController _birthdayController =
      TextEditingController();

  final TextEditingController _ageController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _contactController =
      TextEditingController();

  final TextEditingController _streetController =
      TextEditingController();

  final TextEditingController _houseNumberController =
      TextEditingController();

  final TextEditingController _postalController =
      TextEditingController();

  final TextEditingController _landmarkController =
      TextEditingController();

  final TextEditingController _plateNumberController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  MobileAccountType _accountType = MobileAccountType.buyer;

  int _currentStep = 0;

  String? _sex;
  DateTime? _birthday;

  String? _vehicleType;

  AddressOption? _region;
  AddressOption? _province;
  AddressOption? _municipality;
  AddressOption? _barangay;

  List<AddressOption> _regions = [];
  List<AddressOption> _provinces = [];
  List<AddressOption> _municipalities = [];
  List<AddressOption> _barangays = [];

  bool _loadingRegions = false;
  bool _loadingProvinces = false;
  bool _loadingMunicipalities = false;
  bool _loadingBarangays = false;

  RegistrationDocument? _validId;
  RegistrationDocument? _vehicleOrCr;
  RegistrationDocument? _driversLicense;

  bool _termsAccepted = false;

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _loadRegions();
  }

  @override
  void dispose() {
    _pageController.dispose();

    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();

    _birthdayController.dispose();
    _ageController.dispose();

    _emailController.dispose();
    _contactController.dispose();

    _streetController.dispose();
    _houseNumberController.dispose();
    _postalController.dispose();
    _landmarkController.dispose();

    _plateNumberController.dispose();

    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  List<_RegistrationStep> get _steps {
    if (_accountType == MobileAccountType.rider) {
      return const [
        _RegistrationStep(
          title: 'Personal Information',
          shortTitle: 'Personal',
          icon: Icons.person_outline_rounded,
        ),
        _RegistrationStep(
          title: 'Contact Information',
          shortTitle: 'Contact',
          icon: Icons.phone_outlined,
        ),
        _RegistrationStep(
          title: 'Address',
          shortTitle: 'Address',
          icon: Icons.location_on_outlined,
        ),
        _RegistrationStep(
          title: 'Vehicle Information',
          shortTitle: 'Vehicle',
          icon: Icons.two_wheeler_rounded,
        ),
        _RegistrationStep(
          title: 'Account Verification',
          shortTitle: 'Verify',
          icon: Icons.verified_user_outlined,
        ),
      ];
    }

    return const [
      _RegistrationStep(
        title: 'Personal Information',
        shortTitle: 'Personal',
        icon: Icons.person_outline_rounded,
      ),
      _RegistrationStep(
        title: 'Contact Information',
        shortTitle: 'Contact',
        icon: Icons.phone_outlined,
      ),
      _RegistrationStep(
        title: 'Address',
        shortTitle: 'Address',
        icon: Icons.location_on_outlined,
      ),
      _RegistrationStep(
        title: 'Account Verification',
        shortTitle: 'Verify',
        icon: Icons.verified_user_outlined,
      ),
    ];
  }

  bool get _isLastStep {
    return _currentStep == _steps.length - 1;
  }

  Future<void> _loadRegions() async {
    if (widget.loadRegions == null) {
      return;
    }

    setState(() {
      _loadingRegions = true;
    });

    try {
      final result = await widget.loadRegions!();

      if (!mounted) {
        return;
      }

      setState(() {
        _regions = result;
      });
    } catch (_) {
      _showMessage(
        'Unable to load regions.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingRegions = false;
        });
      }
    }
  }

  Future<void> _onRegionChanged(
    AddressOption? region,
  ) async {
    setState(() {
      _region = region;

      _province = null;
      _municipality = null;
      _barangay = null;

      _provinces = [];
      _municipalities = [];
      _barangays = [];

      _postalController.clear();
    });

    if (region == null || widget.loadProvinces == null) {
      return;
    }

    setState(() {
      _loadingProvinces = true;
    });

    try {
      final result = await widget.loadProvinces!(
        region.code,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _provinces = result;
      });
    } catch (_) {
      _showMessage(
        'Unable to load provinces.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingProvinces = false;
        });
      }
    }
  }

  Future<void> _onProvinceChanged(
    AddressOption? province,
  ) async {
    setState(() {
      _province = province;

      _municipality = null;
      _barangay = null;

      _municipalities = [];
      _barangays = [];

      _postalController.clear();
    });

    if (province == null ||
        widget.loadMunicipalities == null) {
      return;
    }

    setState(() {
      _loadingMunicipalities = true;
    });

    try {
      final result = await widget.loadMunicipalities!(
        province.code,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _municipalities = result;
      });
    } catch (_) {
      _showMessage(
        'Unable to load municipalities.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingMunicipalities = false;
        });
      }
    }
  }

  Future<void> _onMunicipalityChanged(
    AddressOption? municipality,
  ) async {
    setState(() {
      _municipality = municipality;
      _barangay = null;
      _barangays = [];
      _postalController.clear();
    });

    if (municipality == null ||
        widget.loadBarangays == null) {
      return;
    }

    setState(() {
      _loadingBarangays = true;
    });

    try {
      final result = await widget.loadBarangays!(
        municipality.code,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _barangays = result;
      });
    } catch (_) {
      _showMessage(
        'Unable to load barangays.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingBarangays = false;
        });
      }
    }
  }

  Future<void> _onBarangayChanged(
    AddressOption? barangay,
  ) async {
    setState(() {
      _barangay = barangay;
      _postalController.clear();
    });

    if (barangay == null ||
        _municipality == null ||
        widget.loadPostalCode == null) {
      return;
    }

    try {
      final String? postal =
          await widget.loadPostalCode!(
        municipalityCode: _municipality!.code,
        barangayCode: barangay.code,
      );

      if (!mounted) {
        return;
      }

      _postalController.text = postal ?? '';
    } catch (_) {
      _showMessage(
        'Postal code could not be loaded.',
        error: true,
      );
    }
  }

  Future<void> _chooseBirthday() async {
    final DateTime today = DateTime.now();

    final DateTime initialDate =
        _birthday ??
        DateTime(
          today.year - 18,
          today.month,
          today.day,
        );

    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Select birthday',
    );

    if (selected == null) {
      return;
    }

    final int age = _calculateAge(selected);

    setState(() {
      _birthday = selected;

      _birthdayController.text =
          '${selected.month.toString().padLeft(2, '0')}/'
          '${selected.day.toString().padLeft(2, '0')}/'
          '${selected.year}';

      _ageController.text = age.toString();
    });
  }

  int _calculateAge(DateTime birthday) {
    final DateTime now = DateTime.now();

    int age = now.year - birthday.year;

    final bool birthdayNotReached =
        now.month < birthday.month ||
        (now.month == birthday.month &&
            now.day < birthday.day);

    if (birthdayNotReached) {
      age--;
    }

    return age;
  }

  Future<void> _pickDocument(
    RegistrationDocumentType type,
  ) async {
    if (widget.onPickDocument == null) {
      _showMessage(
        'Document picker will be connected next.',
      );
      return;
    }

    try {
      final RegistrationDocument? document =
          await widget.onPickDocument!(
        type,
      );

      if (!mounted || document == null) {
        return;
      }

      setState(() {
        switch (type) {
          case RegistrationDocumentType.validId:
            _validId = document;
            break;

          case RegistrationDocumentType.vehicleOrCr:
            _vehicleOrCr = document;
            break;

          case RegistrationDocumentType.driversLicense:
            _driversLicense = document;
            break;
        }
      });
    } catch (_) {
      _showMessage(
        'Unable to select the document.',
        error: true,
      );
    }
  }

  void _changeAccountType(
    MobileAccountType type,
  ) {
    if (_accountType == type) {
      return;
    }

    setState(() {
      _accountType = type;
      _currentStep = 0;
    });

    _pageController.jumpToPage(0);
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      return _personalFormKey.currentState?.validate() ??
          false;
    }

    if (_currentStep == 1) {
      return _contactFormKey.currentState?.validate() ??
          false;
    }

    if (_currentStep == 2) {
      final bool valid =
          _addressFormKey.currentState?.validate() ??
          false;

      if (!valid) {
        return false;
      }

      if (_region == null ||
          _province == null ||
          _municipality == null ||
          _barangay == null) {
        _showMessage(
          'Complete your Philippine address before continuing.',
          error: true,
        );

        return false;
      }

      return true;
    }

    if (_accountType == MobileAccountType.rider &&
        _currentStep == 3) {
      return _vehicleFormKey.currentState?.validate() ??
          false;
    }

    return _validateVerification();
  }

  bool _validateVerification() {
    final bool fieldsValid =
        _verificationFormKey.currentState?.validate() ??
        false;

    if (!fieldsValid) {
      return false;
    }

    if (_validId == null) {
      _showMessage(
        'Please upload your valid ID.',
        error: true,
      );

      return false;
    }

    if (_accountType == MobileAccountType.rider) {
      if (_vehicleOrCr == null) {
        _showMessage(
          'Please upload the vehicle OR / CR.',
          error: true,
        );

        return false;
      }

      if (_driversLicense == null) {
        _showMessage(
          'Please upload your driver\'s license.',
          error: true,
        );

        return false;
      }
    }

    if (!_termsAccepted) {
      _showMessage(
        'Please agree to LIKHAE\'s terms and marketplace policies.',
        error: true,
      );

      return false;
    }

    return true;
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();

    if (!_validateCurrentStep()) {
      return;
    }

    if (_isLastStep) {
      await _submit();
      return;
    }

    setState(() {
      _currentStep++;
    });

    await _pageController.animateToPage(
      _currentStep,
      duration: const Duration(
        milliseconds: 280,
      ),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _back() async {
    FocusScope.of(context).unfocus();

    if (_currentStep == 0) {
      context.pop();
      return;
    }

    setState(() {
      _currentStep--;
    });

    await _pageController.animateToPage(
      _currentStep,
      duration: const Duration(
        milliseconds: 250,
      ),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _submit() async {
    if (!_validateVerification()) {
      return;
    }

    if (_birthday == null ||
        _region == null ||
        _province == null ||
        _municipality == null ||
        _barangay == null ||
        _validId == null) {
      return;
    }

    if (widget.onSubmit == null) {
      _showMessage(
        'Registration API will be connected to Laravel next.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final RegisterFormData data = RegisterFormData(
        accountType: _accountType,
        firstName: _firstNameController.text.trim(),
        middleInitial: _middleNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        sex: _sex!,
        birthday: _birthday!,
        age: int.parse(_ageController.text),
        email: _emailController.text.trim(),
        contactNumber: _contactController.text.trim(),
        region: _region!,
        province: _province!,
        municipality: _municipality!,
        barangay: _barangay!,
        street: _streetController.text.trim(),
        houseNumber: _houseNumberController.text.trim(),
        postalCode: _postalController.text.trim(),
        landmark: _landmarkController.text.trim(),
        vehicleType:
            _accountType == MobileAccountType.rider
            ? _vehicleType
            : null,
        plateNumber:
            _accountType == MobileAccountType.rider
            ? _plateNumberController.text.trim()
            : null,
        validId: _validId!,
        vehicleOrCr:
            _accountType == MobileAccountType.rider
            ? _vehicleOrCr
            : null,
        driversLicense:
            _accountType == MobileAccountType.rider
            ? _driversLicense
            : null,
        password: _passwordController.text,
      );

      await widget.onSubmit!(data);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.toString().replaceFirst(
          'Exception: ',
          '',
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
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

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              error ? const Color(0xFFB42318) : _primary,
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

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media =
        MediaQuery.of(context);

    final double screenWidth = media.size.width;

    final double horizontalPadding =
        screenWidth < 370 ? 14 : 18;

    return Scaffold(
      backgroundColor: _background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  bottom:
                      media.viewInsets.bottom > 0
                      ? 30
                      : media.padding.bottom + 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 560,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(
                          height: 8,
                        ),

                        _buildHeader(),

                        const SizedBox(
                          height: 24,
                        ),

                        _buildAccountType(),

                        const SizedBox(
                          height: 22,
                        ),

                        _buildProgress(),

                        const SizedBox(
                          height: 18,
                        ),

                        _buildFormCard(),

                        const SizedBox(
                          height: 16,
                        ),

                        _buildNavigation(),

                        const SizedBox(
                          height: 18,
                        ),

                        _buildSignInLink(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        10,
        6,
        14,
        4,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: _back,
            icon: const Icon(
              Icons.arrow_back_rounded,
            ),
          ),

          const SizedBox(
            width: 2,
          ),

          const _LikhaeBrand(),

          const Spacer(),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: _border,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: _secondaryText,
                ),
                SizedBox(
                  width: 4,
                ),
                Text(
                  'Secure',
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 4,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'ACCOUNT REGISTRATION',
            style: TextStyle(
              color: _accent,
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800,
            ),
          ),

          SizedBox(
            height: 7,
          ),

          Text(
            'Create your account',
            style: TextStyle(
              color: _primary,
              fontSize: 29,
              height: 1.05,
              letterSpacing: -0.8,
              fontWeight: FontWeight.w800,
            ),
          ),

          SizedBox(
            height: 8,
          ),

          Text(
            'Choose how you will use LIKHAE and complete each registration step.',
            style: TextStyle(
              color: _secondaryText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountType() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE6DF),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AccountTypeButton(
              selected:
                  _accountType ==
                  MobileAccountType.buyer,
              icon: Icons.shopping_bag_outlined,
              title: 'Buyer',
              subtitle: 'Shop & manage orders',
              onTap: () {
                _changeAccountType(
                  MobileAccountType.buyer,
                );
              },
            ),
          ),

          const SizedBox(
            width: 5,
          ),

          Expanded(
            child: _AccountTypeButton(
              selected:
                  _accountType ==
                  MobileAccountType.rider,
              icon: Icons.two_wheeler_rounded,
              title: 'Rider',
              subtitle: 'Pickup & delivery',
              onTap: () {
                _changeAccountType(
                  MobileAccountType.rider,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final List<_RegistrationStep> steps =
        _steps;

    final double progress =
        (_currentStep + 1) / steps.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Registration progress',
                      style: TextStyle(
                        color: _secondaryText,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      steps[_currentStep].title,
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                'Step ${_currentStep + 1} of ${steps.length}',
                style: const TextStyle(
                  color: _secondaryText,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor:
                  const Color(0xFFEDE9E3),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(
                _primary,
              ),
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          Row(
            children: List.generate(
              steps.length,
              (int index) {
                final bool active =
                    index == _currentStep;

                final bool completed =
                    index < _currentStep;

                return Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(
                          milliseconds: 200,
                        ),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              active || completed
                              ? _primary
                              : const Color(
                                  0xFFF3F0EB,
                                ),
                        ),
                        alignment: Alignment.center,
                        child: completed
                            ? const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Colors.white,
                              )
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: active
                                      ? Colors.white
                                      : _secondaryText,
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        steps[index].shortTitle,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active
                              ? _primary
                              : _secondaryText,
                          fontSize: 8.5,
                          fontWeight: active
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    final List<Widget> steps = _accountType == MobileAccountType.rider
        ? <Widget>[
            _buildPersonalStep(),
            _buildContactStep(),
            _buildAddressStep(),
            _buildVehicleStep(),
            _buildVerificationStep(),
          ]
        : <Widget>[
            _buildPersonalStep(),
            _buildContactStep(),
            _buildAddressStep(),
            _buildVerificationStep(),
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        18,
        20,
        18,
        22,
      ),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.035,
            ),
            blurRadius: 20,
            offset: const Offset(
              0,
              8,
            ),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: steps[_currentStep],
      ),
    );
  }

  Widget _stepHeader({
    required String number,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF2EFEA),
                borderRadius:
                    BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: _primary,
                size: 20,
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'STEP $number',
                    style: const TextStyle(
                      color: _accent,
                      fontSize: 9,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(
                    height: 2,
                  ),

                  Text(
                    title,
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(
                    height: 3,
                  ),

                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _secondaryText,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 24,
        ),
      ],
    );
  }

  Widget _buildPersonalStep() {
    return Form(
      key: _personalFormKey,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          _stepHeader(
            number: '01',
            title: 'Personal Information',
            subtitle:
                'Tell us a little about yourself.',
            icon: Icons.person_outline_rounded,
          ),

          _FieldLabel(
            text: 'First Name',
            required: true,
          ),

          const SizedBox(
            height: 7,
          ),

          TextFormField(
            controller: _firstNameController,
            textInputAction:
                TextInputAction.next,
            textCapitalization:
                TextCapitalization.words,
            autofillHints: const [
              AutofillHints.givenName,
            ],
            decoration: _inputDecoration(
              hintText: 'Juan',
              prefixIcon:
                  Icons.person_outline_rounded,
            ),
            validator: _requiredTextValidator,
          ),

          const SizedBox(
            height: 18,
          ),

          const _FieldLabel(
            text: 'Middle Name / Initial',
          ),

          const SizedBox(
            height: 7,
          ),

          TextFormField(
            controller:
                _middleNameController,
            textInputAction:
                TextInputAction.next,
            textCapitalization:
                TextCapitalization.words,
            decoration: _inputDecoration(
              hintText: 'Santos',
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          _FieldLabel(
            text: 'Last Name',
            required: true,
          ),

          const SizedBox(
            height: 7,
          ),

          TextFormField(
            controller: _lastNameController,
            textInputAction:
                TextInputAction.next,
            textCapitalization:
                TextCapitalization.words,
            autofillHints: const [
              AutofillHints.familyName,
            ],
            decoration: _inputDecoration(
              hintText: 'Dela Cruz',
            ),
            validator: _requiredTextValidator,
          ),

          const SizedBox(
            height: 18,
          ),

          _FieldLabel(
            text: 'Sex',
            required: true,
          ),

          const SizedBox(
            height: 7,
          ),

          DropdownButtonFormField<String>(
            initialValue: _sex,
            isExpanded: true,
            decoration: _inputDecoration(
              hintText: 'Select sex',
            ),
            items: const [
              DropdownMenuItem(
                value: 'Male',
                child: Text('Male'),
              ),
              DropdownMenuItem(
                value: 'Female',
                child: Text('Female'),
              ),
            ],
            onChanged: (String? value) {
              setState(() {
                _sex = value;
              });
            },
            validator: (String? value) {
              if (value == null ||
                  value.isEmpty) {
                return 'Please select your sex.';
              }

              return null;
            },
          ),

          const SizedBox(
            height: 18,
          ),

          _FieldLabel(
            text: 'Birthday',
            required: true,
          ),

          const SizedBox(
            height: 7,
          ),

          TextFormField(
            controller:
                _birthdayController,
            readOnly: true,
            onTap: _chooseBirthday,
            decoration: _inputDecoration(
              hintText: 'Select birthday',
              prefixIcon:
                  Icons.calendar_month_outlined,
              suffix: const Icon(
                Icons.keyboard_arrow_down_rounded,
              ),
            ),
            validator: (_) {
              if (_birthday == null) {
                return 'Please select your birthday.';
              }

              return null;
            },
          ),

          const SizedBox(
            height: 18,
          ),

          _FieldLabel(
            text: 'Age',
            required: true,
          ),

          const SizedBox(
            height: 7,
          ),

          TextFormField(
            controller: _ageController,
            readOnly: true,
            decoration: _inputDecoration(
              hintText:
                  'Automatically calculated',
              prefixIcon:
                  Icons.cake_outlined,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          const Text(
            'Automatically calculated from your birthday.',
            style: TextStyle(
              color: _secondaryText,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactStep() {
    return Form(
      key: _contactFormKey,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          _stepHeader(
            number: '02',
            title: 'Contact Information',
            subtitle:
                'We will use these details for important account updates.',
            icon: Icons.phone_outlined,
          ),

          _FieldLabel(
            text: 'Email Address',
            required: true,
          ),

          const SizedBox(
            height: 7,
          ),

          TextFormField(
            controller: _emailController,
            keyboardType:
                TextInputType.emailAddress,
            textInputAction:
                TextInputAction.next,
            autocorrect: false,
            autofillHints: const [
              AutofillHints.email,
            ],
            decoration: _inputDecoration(
              hintText: 'juan@email.com',
              prefixIcon:
                  Icons.alternate_email_rounded,
            ),
            validator: (String? value) {
              final String email =
                  value?.trim() ?? '';

              if (email.isEmpty) {
                return 'Please enter your email.';
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
            height: 18,
          ),

          _FieldLabel(
            text: 'Contact Number',
            required: true,
          ),

          const SizedBox(
            height: 7,
          ),

          TextFormField(
            controller: _contactController,
            keyboardType:
                TextInputType.phone,
            textInputAction:
                TextInputAction.done,
            decoration: _inputDecoration(
              hintText: '917 123 4567',
              prefixText: '+63 ',
              prefixIcon:
                  Icons.phone_outlined,
            ),
            validator: (String? value) {
              final String digits =
                  (value ?? '').replaceAll(
                RegExp(r'[^0-9]'),
                '',
              );

              if (digits.isEmpty) {
                return 'Please enter your contact number.';
              }

              if (digits.length != 10) {
                return 'Enter a 10-digit Philippine mobile number.';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddressStep() {
    return Form(
      key: _addressFormKey,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          _stepHeader(
            number: '03',
            title: 'Address',
            subtitle:
                'Select your Philippine location and enter your detailed address.',
            icon:
                Icons.location_on_outlined,
          ),

          if (widget.loadRegions == null)
            _buildApiNotice(),

          if (widget.loadRegions == null)
            const SizedBox(
              height: 18,
            ),

          _FieldLabel(
            text: 'Region',
            required: true,
          ),

          const SizedBox(
            height: 7,
          ),

          _AddressDropdown(
            value: _region,
            items: _regions,
            enabled:
                widget.loadRegions != null,
            loading: _loadingRegions,
            hint: 'Select region',
            onChanged: _onRegionChanged,
          ),

          const SizedBox(
            height: 18,
          ),

          _FieldLabel(
            text: 'Province',
            required: true,
          ),

          const SizedBox(
            height: 7,
          ),

          _AddressDropdown(
            value: _province,
            items: _provinces,
            enabled: _region != null &&
                widget.loadProvinces != null,
            loading: _loadingProvinces,
            hint: 'Select province',
            onChanged:
                _onProvinceChanged,
          ),

          const SizedBox(
            height: 18,
          ),

          _FieldLabel(
            text: 'Municipality / City',
            required: true,
          ),

          const SizedBox(
            height: 7,
          ),

          _AddressDropdown(
            value: _municipality,
            items: _municipalities,
            enabled: _province != null &&
                widget.loadMunicipalities !=
                    null,
            loading:
                _loadingMunicipalities,
            hint:
                'Select municipality / city',
            onChanged:
                _onMunicipalityChanged,
          ),

          const SizedBox(
            height: 18,
          ),

          _FieldLabel(
            text: 'Barangay',
            required: true,
          ),

          const SizedBox(
            height: 7,
          ),

          _AddressDropdown(
            value: _barangay,
            items: _barangays,
            enabled: _municipality !=
                    null &&
                widget.loadBarangays != null,
            loading: _loadingBarangays,
            hint: 'Select barangay',
            onChanged:
                _onBarangayChanged,
          ),

          const SizedBox(
            height: 18,
          ),

          _FieldLabel(
            text: 'Street / Purok',
            required: true,
          ),

          const SizedBox(
            height: 7,
          ),

          TextFormField(
            controller: _streetController,
            textCapitalization:
                TextCapitalization.words,
            textInputAction:
                TextInputAction.next,
            decoration: _inputDecoration(
              hintText:
                  'e.g. Mahogany Street / Purok 3',
              prefixIcon:
                  Icons.signpost_outlined,
            ),
            validator: _requiredTextValidator,
          ),

          const SizedBox(
            height: 18,
          ),

          const _FieldLabel(
            text: 'House / Unit Number',
          ),

          const SizedBox(
            height: 7,
          ),

          TextFormField(
            controller:
                _houseNumberController,
            textInputAction:
                TextInputAction.next,
            decoration: _inputDecoration(
              hintText: 'e.g. Blk 12 Lot 3',
              prefixIcon:
                  Icons.home_outlined,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          const _FieldLabel(
            text: 'Postal Code',
          ),

          const SizedBox(
            height: 7,
          ),

          TextFormField(
            controller: _postalController,
            readOnly: true,
            decoration: _inputDecoration(
              hintText:
                  'Auto-filled after barangay',
              prefixIcon:
                  Icons.markunread_mailbox_outlined,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          const _FieldLabel(
            text:
                'Landmark / Additional Details',
          ),

          const SizedBox(
            height: 7,
          ),

          TextFormField(
            controller:
                _landmarkController,
            textCapitalization:
                TextCapitalization.sentences,
            textInputAction:
                TextInputAction.done,
            decoration: _inputDecoration(
              hintText:
                  'e.g. Near barangay hall',
              prefixIcon:
                  Icons.flag_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleStep() {
    return Form(
      key: _vehicleFormKey,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          _stepHeader(
            number: '04',
            title: 'Vehicle Information',
            subtitle:
                'Enter the vehicle you will use for deliveries.',
            icon: Icons.two_wheeler_rounded,
          ),

          _FieldLabel(
            text: 'Vehicle Type',
            required: true,
          ),

          const SizedBox(
            height: 7,
          ),

          DropdownButtonFormField<String>(
            initialValue: _vehicleType,
            isExpanded: true,
            decoration: _inputDecoration(
              hintText:
                  'Select vehicle type',
              prefixIcon:
                  Icons.local_shipping_outlined,
            ),
            items: const [
              DropdownMenuItem(
                value: 'motorcycle',
                child: Text('Motorcycle'),
              ),
              DropdownMenuItem(
                value: 'car',
                child: Text('Car'),
              ),
              DropdownMenuItem(
                value: 'van',
                child: Text('Van'),
              ),
              DropdownMenuItem(
                value: 'truck',
                child: Text('Truck'),
              ),
            ],
            onChanged: (String? value) {
              setState(() {
                _vehicleType = value;
              });
            },
            validator: (String? value) {
              if (value == null ||
                  value.isEmpty) {
                return 'Select your vehicle type.';
              }

              return null;
            },
          ),

          const SizedBox(
            height: 18,
          ),

          _FieldLabel(
            text: 'Plate Number',
            required: true,
          ),

          const SizedBox(
            height: 7,
          ),

          TextFormField(
            controller:
                _plateNumberController,
            textCapitalization:
                TextCapitalization.characters,
            maxLength: 30,
            decoration: _inputDecoration(
              hintText: 'ABC 1234',
              prefixIcon:
                  Icons.pin_outlined,
            ).copyWith(
              counterText: '',
            ),
            validator: _requiredTextValidator,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStep() {
    final String stepNumber =
        _accountType ==
            MobileAccountType.rider
        ? '05'
        : '04';

    return Form(
      key: _verificationFormKey,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          _stepHeader(
            number: stepNumber,
            title: 'Account Verification',
            subtitle:
                'Upload the required documents and secure your account.',
            icon:
                Icons.verified_user_outlined,
          ),

          _DocumentUploadCard(
            title: 'Valid ID',
            description:
                'JPG, JPEG, PNG or PDF',
            required: true,
            document: _validId,
            icon:
                Icons.badge_outlined,
            onTap: () {
              _pickDocument(
                RegistrationDocumentType
                    .validId,
              );
            },
          ),

          if (_accountType ==
              MobileAccountType.rider) ...[
            const SizedBox(
              height: 12,
            ),

            _DocumentUploadCard(
              title: 'Vehicle OR / CR',
              description:
                  'JPG, JPEG, PNG or PDF',
              required: true,
              document: _vehicleOrCr,
              icon:
                  Icons.description_outlined,
              onTap: () {
                _pickDocument(
                  RegistrationDocumentType
                      .vehicleOrCr,
                );
              },
            ),

            const SizedBox(
              height: 12,
            ),

            _DocumentUploadCard(
              title: 'Driver\'s License',
              description:
                  'JPG, JPEG, PNG or PDF',
              required: true,
              document: _driversLicense,
              icon:
                  Icons.credit_card_outlined,
              onTap: () {
                _pickDocument(
                  RegistrationDocumentType
                      .driversLicense,
                );
              },
            ),
          ],

          const SizedBox(
            height: 24,
          ),

          _FieldLabel(
            text: 'Password',
            required: true,
          ),

          const SizedBox(
            height: 7,
          ),

          TextFormField(
            controller:
                _passwordController,
            obscureText:
                _obscurePassword,
            textInputAction:
                TextInputAction.next,
            autofillHints: const [
              AutofillHints.newPassword,
            ],
            decoration: _inputDecoration(
              hintText:
                  'Min. 8 chars, uppercase, number',
              prefixIcon:
                  Icons.lock_outline_rounded,
              suffix: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword =
                        !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons
                            .visibility_outlined
                      : Icons
                            .visibility_off_outlined,
                  size: 20,
                  color: _secondaryText,
                ),
              ),
            ),
            validator:
                _passwordValidator,
          ),

          const SizedBox(
            height: 18,
          ),

          _FieldLabel(
            text: 'Confirm Password',
            required: true,
          ),

          const SizedBox(
            height: 7,
          ),

          TextFormField(
            controller:
                _confirmPasswordController,
            obscureText:
                _obscureConfirmation,
            textInputAction:
                TextInputAction.done,
            autofillHints: const [
              AutofillHints.newPassword,
            ],
            decoration: _inputDecoration(
              hintText:
                  'Re-enter your password',
              prefixIcon:
                  Icons.lock_outline_rounded,
              suffix: IconButton(
                onPressed: () {
                  setState(() {
                    _obscureConfirmation =
                        !_obscureConfirmation;
                  });
                },
                icon: Icon(
                  _obscureConfirmation
                      ? Icons
                            .visibility_outlined
                      : Icons
                            .visibility_off_outlined,
                  size: 20,
                  color: _secondaryText,
                ),
              ),
            ),
            validator: (String? value) {
              if (value == null ||
                  value.isEmpty) {
                return 'Confirm your password.';
              }

              if (value !=
                  _passwordController.text) {
                return 'Passwords do not match.';
              }

              return null;
            },
          ),

          const SizedBox(
            height: 22,
          ),

          Container(
            padding: const EdgeInsets.all(
              14,
            ),
            decoration: BoxDecoration(
              color: const Color(
                0xFFFFF7E8,
              ),
              borderRadius:
                  BorderRadius.circular(15),
              border: Border.all(
                color: const Color(
                  0xFFF2DFC0,
                ),
              ),
            ),
            child: const Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(
                    0xFF8B6425,
                  ),
                  size: 20,
                ),

                SizedBox(
                  width: 10,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administrator approval required',
                        style: TextStyle(
                          color: Color(
                            0xFF6E4C18,
                          ),
                          fontSize: 12.5,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),

                      SizedBox(
                        height: 4,
                      ),

                      Text(
                        'After submitting your registration, wait for administrator approval before signing in.',
                        style: TextStyle(
                          color: Color(
                            0xFF846B45,
                          ),
                          fontSize: 10.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          InkWell(
            borderRadius:
                BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _termsAccepted =
                    !_termsAccepted;
              });
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 4,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _termsAccepted,
                    activeColor: _primary,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        4,
                      ),
                    ),
                    onChanged: (
                      bool? value,
                    ) {
                      setState(() {
                        _termsAccepted =
                            value ?? false;
                      });
                    },
                  ),

                  const SizedBox(
                    width: 2,
                  ),

                  const Expanded(
                    child: Padding(
                      padding:
                          EdgeInsets.only(
                        top: 10,
                      ),
                      child: Text(
                        'I confirm that the information provided is correct and I agree to LIKHAE\'s terms and marketplace policies.',
                        style: TextStyle(
                          color:
                              _secondaryText,
                          fontSize: 11,
                          height: 1.45,
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

  Widget _buildNavigation() {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed:
                    _isSubmitting
                    ? null
                    : _back,
                icon: const Icon(
                  Icons
                      .arrow_back_rounded,
                  size: 18,
                ),
                label: const Text(
                  'Back',
                ),
                style:
                    OutlinedButton.styleFrom(
                  foregroundColor:
                      _primary,
                  side: const BorderSide(
                    color: _border,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                ),
              ),
            ),
          ),

        if (_currentStep > 0)
          const SizedBox(
            width: 10,
          ),

        Expanded(
          flex: _currentStep > 0
              ? 2
              : 1,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : _next,
              style:
                  ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _primary,
                foregroundColor:
                    Colors.white,
                disabledBackgroundColor:
                    _primary.withValues(
                  alpha: 0.55,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        Text(
                          _isLastStep
                              ? _accountType ==
                                      MobileAccountType
                                          .rider
                                  ? 'Submit Rider Application'
                                  : 'Submit Buyer Application'
                              : 'Continue',
                          textAlign:
                              TextAlign.center,
                          style:
                              const TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),

                        const SizedBox(
                          width: 7,
                        ),

                        const Icon(
                          Icons
                              .arrow_forward_rounded,
                          size: 18,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInLink() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        const Text(
          'Already registered? ',
          style: TextStyle(
            color: _secondaryText,
            fontSize: 12,
          ),
        ),

        TextButton(
          onPressed: () {
            context.go('/login');
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize:
                MaterialTapTargetSize
                    .shrinkWrap,
          ),
          child: const Text(
            'Sign in',
            style: TextStyle(
              color: _primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApiNotice() {
    return Container(
      padding: const EdgeInsets.all(
        13,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FA),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: const Color(
            0xFFD9E2ED,
          ),
        ),
      ),
      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cloud_outlined,
            size: 18,
            color: Color(
              0xFF51677F,
            ),
          ),

          SizedBox(
            width: 9,
          ),

          Expanded(
            child: Text(
              'The Philippine address dropdowns will become active after the existing Laravel address API is connected to Flutter.',
              style: TextStyle(
                color: Color(
                  0xFF51677F,
                ),
                fontSize: 10.5,
                height: 1.4,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _requiredTextValidator(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'This field is required.';
    }

    return null;
  }

  String? _passwordValidator(
    String? value,
  ) {
    final String password = value ?? '';

    if (password.isEmpty) {
      return 'Please enter a password.';
    }

    if (password.length < 8 ||
        password.length > 72) {
      return 'Use 8–72 characters.';
    }

    if (!RegExp(r'[A-Z]')
        .hasMatch(password)) {
      return 'Include at least one uppercase letter.';
    }

    if (!RegExp(r'[a-z]')
        .hasMatch(password)) {
      return 'Include at least one lowercase letter.';
    }

    if (!RegExp(r'[0-9]')
        .hasMatch(password)) {
      return 'Include at least one number.';
    }

    return null;
  }

  InputDecoration _inputDecoration({
    required String hintText,
    IconData? prefixIcon,
    String? prefixText,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixText: prefixText,
      prefixIcon: prefixIcon == null
          ? null
          : Icon(
              prefixIcon,
              size: 19,
              color: const Color(
                0xFF6D6862,
              ),
            ),
      suffixIcon: suffix,
      filled: true,
      fillColor: _fieldBackground,
      hintStyle: const TextStyle(
        color: Color(0xFFA39E98),
        fontSize: 12.5,
      ),
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: _border,
        ),
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: _border,
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: _primary,
          width: 1.3,
        ),
      ),
      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: _accent,
        ),
      ),
      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: _accent,
          width: 1.3,
        ),
      ),
      errorStyle: const TextStyle(
        fontSize: 10,
      ),
    );
  }
}

class _RegistrationStep {
  final String title;
  final String shortTitle;
  final IconData icon;

  const _RegistrationStep({
    required this.title,
    required this.shortTitle,
    required this.icon,
  });
}

class _LikhaeBrand extends StatelessWidget {
  const _LikhaeBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'LIKHAE',
          style: TextStyle(
            color: Color(0xFF191816),
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),

        SizedBox(
          width: 7,
        ),

        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Color(0xFFD94343),
            shape: BoxShape.circle,
          ),
        ),

        SizedBox(
          width: 7,
        ),

        Text(
          'Marketplace',
          style: TextStyle(
            color: Color(0xFF89837D),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;

  const _FieldLabel({
    required this.text,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Color(0xFF292724),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(
            text: text,
          ),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: Color(0xFFD94343),
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountTypeButton
    extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AccountTypeButton({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.white
          : Colors.transparent,
      borderRadius:
          BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 180,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(13),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset:
                          const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(
                          0xFF191816,
                        )
                      : const Color(
                          0xFFDCD7CF,
                        ),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                alignment:
                    Alignment.center,
                child: Icon(
                  icon,
                  size: 17,
                  color: selected
                      ? Colors.white
                      : const Color(
                          0xFF706A64,
                        ),
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color:
                            const Color(
                          0xFF191816,
                        ),
                        fontSize: 11.5,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 2,
                    ),

                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color: Color(
                          0xFF847E78,
                        ),
                        fontSize: 8.5,
                      ),
                    ),
                  ],
                ),
              ),

              if (selected)
                const Icon(
                  Icons
                      .check_circle_rounded,
                  size: 17,
                  color: Color(
                    0xFF227A42,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressDropdown
    extends StatelessWidget {
  final AddressOption? value;

  final List<AddressOption> items;

  final bool enabled;
  final bool loading;

  final String hint;

  final ValueChanged<AddressOption?>
  onChanged;

  const _AddressDropdown({
    required this.value,
    required this.items,
    required this.enabled,
    required this.loading,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<
      AddressOption
    >(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor:
            const Color(0xFFFBFAF8),
        prefixIcon: loading
            ? const Padding(
                padding:
                    EdgeInsets.all(14),
                child:
                    SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              )
            : const Icon(
                Icons
                    .location_on_outlined,
                size: 19,
                color:
                    Color(0xFF6D6862),
              ),
        hintText: loading
            ? 'Loading...'
            : hint,
        hintStyle: const TextStyle(
          color: Color(0xFFA39E98),
          fontSize: 12.5,
        ),
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(13),
          borderSide:
              const BorderSide(
            color: Color(
              0xFFE4E0DA,
            ),
          ),
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(13),
          borderSide:
              const BorderSide(
            color: Color(
              0xFFE4E0DA,
            ),
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(13),
          borderSide:
              const BorderSide(
            color: Color(
              0xFF191816,
            ),
            width: 1.3,
          ),
        ),
      ),
      items: items
          .map(
            (
              AddressOption option,
            ) {
              return DropdownMenuItem<
                AddressOption
              >(
                value: option,
                child: Text(
                  option.name,
                  overflow:
                      TextOverflow.ellipsis,
                ),
              );
            },
          )
          .toList(),
      onChanged:
          enabled && !loading
          ? onChanged
          : null,
      validator: (
        AddressOption? selected,
      ) {
        if (selected == null) {
          return 'This field is required.';
        }

        return null;
      },
    );
  }
}

class _DocumentUploadCard
    extends StatelessWidget {
  final String title;
  final String description;
  final bool required;

  final RegistrationDocument? document;

  final IconData icon;

  final VoidCallback onTap;

  const _DocumentUploadCard({
    required this.title,
    required this.description,
    required this.required,
    required this.document,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected =
        document != null;

    return Material(
      color: selected
          ? const Color(0xFFF2F8F4)
          : const Color(0xFFFBFAF8),
      borderRadius:
          BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(
            15,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(
                      0xFFCFE4D5,
                    )
                  : const Color(
                      0xFFE4E0DA,
                    ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(
                          0xFFDFF0E4,
                        )
                      : const Color(
                          0xFFF0ECE6,
                        ),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                alignment:
                    Alignment.center,
                child: Icon(
                  selected
                      ? Icons
                            .check_rounded
                      : icon,
                  color: selected
                      ? const Color(
                          0xFF227A42,
                        )
                      : const Color(
                          0xFF65605A,
                        ),
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style:
                            const TextStyle(
                          color: Color(
                            0xFF292724,
                          ),
                          fontSize: 12.5,
                          fontWeight:
                              FontWeight.w800,
                        ),
                        children: [
                          TextSpan(
                            text: title,
                          ),
                          if (required)
                            const TextSpan(
                              text: ' *',
                              style:
                                  TextStyle(
                                color: Color(
                                  0xFFD94343,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      document?.name ??
                          description,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color: Color(
                          0xFF7F7973,
                        ),
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Icon(
                selected
                    ? Icons
                          .check_circle_rounded
                    : Icons
                          .upload_file_outlined,
                color: selected
                    ? const Color(
                        0xFF227A42,
                      )
                    : const Color(
                        0xFF77716B,
                      ),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
