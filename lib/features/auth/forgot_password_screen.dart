import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Color _background = Color(0xFFF7F2E9);
  static const Color _surface = Color(0xFFFFFCF8);
  static const Color _primary = Color(0xFF9E171B);
  static const Color _primaryDark = Color(0xFF741015);
  static const Color _text = Color(0xFF3B261F);
  static const Color _muted = Color(0xFF8B7669);
  static const Color _border = Color(0xFFE5D5C3);
  static const Color _fieldBackground = Color(0xFFFFFAF5);
  static const Color _error = Color(0xFFB42318);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _sending = false;
  bool _requestSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _sending = true);
    try {
      await AuthService.sendPasswordResetLink(_emailController.text);
      if (!mounted) return;
      setState(() => _requestSent = true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: _primaryDark,
            content: Text(
              'If an account exists for this email, a reset link has been sent.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      final String message = error is FormatException
          ? error.message
          : ApiClient.formatError(error);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: _error,
            content: Text(message),
          ),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final bool compact = screenSize.height < 720 || screenSize.width < 360;
    final double horizontalPadding = screenSize.width < 360 ? 16 : 20;

    return Scaffold(
      backgroundColor: _background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double bottomPadding =
                MediaQuery.viewInsetsOf(context).bottom > 0
                    ? 22
                    : MediaQuery.paddingOf(context).bottom + 22;
            final double minContentHeight =
                constraints.maxHeight > bottomPadding
                    ? constraints.maxHeight - bottomPadding
                    : 0;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minContentHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildTopBar(),
                          SizedBox(height: compact ? 10 : 14),
                          _buildBrandPanel(compact: compact),
                          SizedBox(height: compact ? 12 : 16),
                          _buildRecoveryCard(compact: compact),
                          SizedBox(height: compact ? 12 : 16),
                          _buildFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: 46,
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          onPressed: () => context.pop(),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          color: _text,
          style: IconButton.styleFrom(
            backgroundColor: _surface.withValues(alpha: 0.75),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: _border),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandPanel({required bool compact}) {
    return Container(
      height: compact ? 154 : 174,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFFCF6), Color(0xFFEDE0D0)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -27,
            top: -41,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _primary.withValues(alpha: 0.08),
                  width: 22,
                ),
              ),
            ),
          ),
          Positioned(
            right: 27,
            bottom: -39,
            child: Icon(
              Icons.spa_outlined,
              size: compact ? 100 : 120,
              color: _primary.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, compact ? 14 : 16, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Image.asset(
                      'assets/icons/likhae_ai_logo.png',
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.handshake_outlined,
                        size: 32,
                        color: _primaryDark,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'LIKHAE',
                      style: TextStyle(
                        color: _text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: _primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'Marketplace',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _surface.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _primary.withValues(alpha: 0.18)),
                  ),
                  child: const Text(
                    'MARKETPLACE',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 9,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      const TextSpan(text: 'Your account,\n'),
                      TextSpan(
                        text: 'always within reach.',
                        style: TextStyle(
                          color: _primary,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  style: TextStyle(
                    color: _text,
                    fontSize: compact ? 22 : 24,
                    height: 1.04,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryCard({required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 19 : 22),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEDE2D7)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF4E2C21).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7EAE4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: _primaryDark,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'SECURE ACCOUNT RECOVERY',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 9.5,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Forgot Password?',
              style: TextStyle(
                color: _text,
                fontSize: compact ? 25 : 28,
                height: 1.1,
                letterSpacing: -0.6,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _requestSent
                  ? 'If an account exists for that email, a reset link was sent. Check your inbox and spam folder.'
                  : "Enter your email and we'll send you a secure link to reset your password.",
              style: TextStyle(color: _muted, fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 20),
            const Text(
              'Email address',
              style: TextStyle(
                color: _text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              decoration: _emailDecoration(),
              validator: (String? value) {
                final String email = value?.trim() ?? '';
                if (email.isEmpty) return 'Enter your email address.';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _sending ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: _primary.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            _requestSent ? 'Resend Reset Link' : 'Send Reset Link',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 17),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 5),
            TextButton(
              onPressed: () => context.pop(),
              style: TextButton.styleFrom(
                foregroundColor: _primaryDark,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _emailDecoration() {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: _border),
    );
    return InputDecoration(
      hintText: 'Enter your registered email',
      hintStyle: const TextStyle(color: Color(0xFFB4A49A), fontSize: 12),
      prefixIcon: const Icon(Icons.alternate_email_rounded, color: _muted),
      filled: true,
      fillColor: _fieldBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      errorStyle: const TextStyle(color: _error, fontSize: 10.5),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
      errorBorder: border.copyWith(borderSide: const BorderSide(color: _error)),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: _error, width: 1.4),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: <Widget>[
          const Divider(height: 1, color: _border),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 15,
            runSpacing: 6,
            children: const <Widget>[
              _FooterItem(
                icon: Icons.verified_user_outlined,
                label: 'Secure recovery',
              ),
              _FooterItem(
                icon: Icons.lock_outline_rounded,
                label: 'Privacy protected',
              ),
              _FooterItem(
                icon: Icons.storefront_outlined,
                label: 'LIKHAE marketplace',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FooterItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: const Color(0xFF9A897E)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8B7669), fontSize: 9.5),
        ),
      ],
    );
  }
}
