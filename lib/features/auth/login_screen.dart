import 'package:flutter/material.dart';

typedef LoginCallback = Future<void> Function(
  String email,
  String password,
  bool rememberMe,
);

class LoginScreen extends StatefulWidget {
  final LoginCallback? onSignIn;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onRegister;
  final VoidCallback? onGoogleSignIn;
  final VoidCallback? onFacebookSignIn;
  final VoidCallback? onContinueAsBuyer;
  final VoidCallback? onContinueAsRider;

  const LoginScreen({
    super.key,
    this.onSignIn,
    this.onForgotPassword,
    this.onRegister,
    this.onGoogleSignIn,
    this.onFacebookSignIn,
    this.onContinueAsBuyer,
    this.onContinueAsRider,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isSubmitting = false;

  static const Color _background = Color(0xFFF4F1EB);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _primary = Color(0xFF191816);
  static const Color _secondaryText = Color(0xFF76716B);
  static const Color _border = Color(0xFFE4E0DA);
  static const Color _fieldBackground = Color(0xFFFBFAF8);
  static const Color _accent = Color(0xFFD94343);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String email = _emailController.text.trim().toLowerCase();
    final String password = _passwordController.text;

    if (widget.onSignIn == null) {
      _showMessage(
        'Login API is not connected yet.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onSignIn!(
        email,
        password,
        _rememberMe,
      );
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
          backgroundColor: error
              ? const Color(0xFFB42318)
              : const Color(0xFF252320),
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

  void _googleLogin() {
    if (widget.onGoogleSignIn != null) {
      widget.onGoogleSignIn!();
      return;
    }

    _showMessage(
      'Google authentication will be connected later.',
    );
  }

  void _facebookLogin() {
    if (widget.onFacebookSignIn != null) {
      widget.onFacebookSignIn!();
      return;
    }

    _showMessage(
      'Facebook authentication will be connected later.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);

    final double screenWidth = media.size.width;
    final double screenHeight = media.size.height;

    final bool verySmallDevice = screenWidth < 350;
    final bool compactHeight = screenHeight < 720;

    final double horizontalPadding = screenWidth < 380 ? 16 : 20;

    final double heroHeight = compactHeight ? 175 : 205;

    return Scaffold(
      backgroundColor: _background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (
            BuildContext context,
            BoxConstraints constraints,
          ) {
            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                bottom: media.viewInsets.bottom > 0
                    ? 24
                    : media.padding.bottom + 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 520,
                  ),
                  child: Column(
                    children: [
                      _buildHero(
                        height: heroHeight,
                        compact: compactHeight,
                      ),

                      Transform.translate(
                        offset: const Offset(
                          0,
                          -26,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          child: _buildLoginCard(
                            verySmallDevice: verySmallDevice,
                            compactHeight: compactHeight,
                          ),
                        ),
                      ),

                      Transform.translate(
                        offset: const Offset(
                          0,
                          -10,
                        ),
                        child: _buildBottomTrust(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero({
    required double height,
    required bool compact,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login-page-bg.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stackTrace,
            ) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF332D27),
                      Color(0xFF171512),
                    ],
                  ),
                ),
              );
            },
          ),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.28),
                  Colors.black.withValues(alpha: 0.78),
                ],
              ),
            ),
          ),

          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                compact ? 20 : 26,
                22,
                40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: Colors.white,
                        ),
                        SizedBox(
                          width: 6,
                        ),
                        Text(
                          'Your Philippine marketplace',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Your local marketplace,\n',
                        ),
                        TextSpan(
                          text: 'reimagined.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 24 : 27,
                      height: 1.05,
                      letterSpacing: -0.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    'Discover everyday essentials and local finds.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 11.5,
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

  Widget _buildLoginCard({
    required bool verySmallDevice,
    required bool compactHeight,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        verySmallDevice ? 18 : 22,
        compactHeight ? 22 : 26,
        verySmallDevice ? 18 : 22,
        24,
      ),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(
              0,
              12,
            ),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _LikhaeBrand(),

              SizedBox(
                height: compactHeight ? 22 : 28,
              ),

              const Text(
                'Welcome back',
                style: TextStyle(
                  color: _primary,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  height: 1.1,
                ),
              ),

              const SizedBox(
                height: 7,
              ),

              const Text(
                'Sign in to continue shopping on LIKHAE.',
                style: TextStyle(
                  color: _secondaryText,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),

              SizedBox(
                height: compactHeight ? 24 : 30,
              ),

              const _FieldLabel(
                text: 'Email address',
              ),

              const SizedBox(
                height: 8,
              ),

              TextFormField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [
                  AutofillHints.email,
                ],
                onFieldSubmitted: (_) {
                  _passwordFocusNode.requestFocus();
                },
                decoration: _inputDecoration(
                  hintText: 'juan@email.com',
                  prefixIcon: Icons.alternate_email_rounded,
                ),
                validator: (String? value) {
                  final String email = value?.trim() ?? '';

                  if (email.isEmpty) {
                    return 'Enter your email address.';
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

              const SizedBox(
                height: 20,
              ),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: _FieldLabel(
                      text: 'Password',
                    ),
                  ),

                  TextButton(
                    onPressed: widget.onForgotPassword,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 8,
              ),

              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                enableSuggestions: false,
                autocorrect: false,
                autofillHints: const [
                  AutofillHints.password,
                ],
                onFieldSubmitted: (_) {
                  _submit();
                },
                decoration: _inputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: Icons.lock_outline_rounded,
                  suffix: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: _secondaryText,
                      size: 20,
                    ),
                  ),
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter your password.';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 14,
              ),

              Row(
                children: [
                  Transform.scale(
                    scale: 0.90,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: _primary,
                      checkColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFFA6A19B),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (bool? value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                    ),
                  ),

                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _rememberMe = !_rememberMe;
                      });
                    },
                    child: const Text(
                      'Remember me',
                      style: TextStyle(
                        color: _secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const Spacer(),

                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 13,
                    color: _secondaryText,
                  ),

                  const SizedBox(
                    width: 4,
                  ),

                  const Text(
                    'Secure login',
                    style: TextStyle(
                      color: _secondaryText,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 22,
              ),

              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          _submit();
                        },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        _primary.withValues(alpha: 0.55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(
                              width: 9,
                            ),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              const _DividerLabel(
                text: 'or continue with',
              ),

              const SizedBox(
                height: 18,
              ),

              LayoutBuilder(
                builder: (
                  BuildContext context,
                  BoxConstraints constraints,
                ) {
                  if (constraints.maxWidth < 315) {
                    return Column(
                      children: [
                        _SocialButton(
                          label: 'Google',
                          icon: const _GoogleLogo(),
                          onTap: _googleLogin,
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        _SocialButton(
                          label: 'Facebook',
                          icon: const _FacebookLogo(),
                          onTap: _facebookLogin,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: _SocialButton(
                          label: 'Google',
                          icon: const _GoogleLogo(),
                          onTap: _googleLogin,
                        ),
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child: _SocialButton(
                          label: 'Facebook',
                          icon: const _FacebookLogo(),
                          onTap: _facebookLogin,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(
                height: 24,
              ),

              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: _secondaryText,
                      fontSize: 12.5,
                    ),
                  ),

                  GestureDetector(
                    onTap: widget.onRegister,
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

                const SizedBox(height: 24),

                const _DividerLabel(text: 'or quick access'),

                const SizedBox(height: 16),

                // â”€â”€ Role selection (if/else navigation) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Row(
                  children: [
                    Expanded(
                      child: _RoleButton(
                        label: 'Buyer',
                        icon: Icons.storefront_outlined,
                        onTap: () {
                          if (widget.onContinueAsBuyer != null) {
                            widget.onContinueAsBuyer!();
                          }
                        },
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: _RoleButton(
                        label: 'Rider',
                        icon: Icons.delivery_dining_outlined,
                        onTap: () {
                          if (widget.onContinueAsRider != null) {
                            widget.onContinueAsRider!();
                          }
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomTrust() {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 8,
        children: [
          _TrustBadge(
            icon: Icons.lock_outline_rounded,
            label: 'Secure',
          ),
          _TrustBadge(
            icon: Icons.verified_user_outlined,
            label: 'Buyer protected',
          ),
          _TrustBadge(
            icon: Icons.public_rounded,
            label: 'Philippine marketplace',
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFFA8A39E),
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: const Color(0xFF68635E),
        size: 20,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: _fieldBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      errorStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _primary,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _accent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _accent,
          width: 1.4,
        ),
      ),
    );
  }
}

class _LikhaeBrand extends StatelessWidget {
  const _LikhaeBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'LIKHAE',
          style: TextStyle(
            color: Color(0xFF191816),
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),

        SizedBox(
          width: 8,
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
          width: 8,
        ),

        Text(
          'Marketplace',
          style: TextStyle(
            color: Color(0xFF8A857F),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF2A2825),
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  final String text;

  const _DividerLabel({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            color: Color(0xFFE4E0DA),
            height: 1,
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF928D87),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const Expanded(
          child: Divider(
            color: Color(0xFFE4E0DA),
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF24221F),
          side: const BorderSide(
            color: Color(0xFFE4E0DA),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,

            const SizedBox(
              width: 7,
            ),

            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _FacebookLogo extends StatelessWidget {
  const _FacebookLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        color: Color(0xFF1877F2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'f',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TrustBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: const Color(0xFF827D77),
        ),

        const SizedBox(
          width: 4,
        ),


        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF827D77),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFFF5F3EF),
          foregroundColor: const Color(0xFF191816),
          side: const BorderSide(color: Color(0xFFD8D4CE)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
