import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

typedef RiderScannerCallback =
    Future<void> Function(String trackingCode);

typedef RiderScannerSignOutCallback =
    Future<void> Function();

class RiderScannerScreen extends StatefulWidget {
  /// Optional callback when a QR/barcode/manual tracking code is accepted.
  ///
  /// If this is null and this screen was opened using context.push(),
  /// the scanned code is returned using context.pop(code).
  final RiderScannerCallback? onScanned;

  /// Optional real logout handler.
  ///
  /// Connect this to Laravel logout + secure-token cleanup.
  final RiderScannerSignOutCallback? onSignOut;

  /// Optional expected tracking code.
  ///
  /// When supplied, the scanner will only accept this exact tracking code.
  /// Useful when scanning from a specific pickup assignment.
  final String? expectedTrackingCode;

  final bool showSignOut;

  const RiderScannerScreen({
    super.key,
    this.onScanned,
    this.onSignOut,
    this.expectedTrackingCode,
    this.showSignOut = true,
  });

  @override
  State<RiderScannerScreen> createState() =>
      _RiderScannerScreenState();
}

class _RiderScannerScreenState
    extends State<RiderScannerScreen> {
  static const Color _primary = Color(0xFF561C17);
  static const Color _background = Color(0xFFFBF7F2);
  static const Color _surface = Color(0xFFFFFDF9);
  static const Color _soft = Color(0xFFF6EFE7);

  static const Color _border = Color(0xFFEADCCC);

  static const Color _text = Color(0xFF3B211B);
  static const Color _muted = Color(0xFF987865);

  static const Color _success = Color(0xFF237A44);
  static const Color _successSoft = Color(0xFFEAF6EE);

  static const Color _danger = Color(0xFFB42318);
  static const Color _dangerSoft = Color(0xFFFFF1F0);

  final MobileScannerController _scannerController =
      MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    torchEnabled: false,
  );

  final TextEditingController _manualCodeController =
      TextEditingController();

  bool _handlingScan = false;
  bool _scannerPaused = false;
  bool _signingOut = false;

  String? _scannedCode;
  String? _errorMessage;

  @override
  void dispose() {
    _manualCodeController.dispose();
    _scannerController.dispose();

    super.dispose();
  }

  Future<void> _onDetect(
    BarcodeCapture capture,
  ) async {
    if (_handlingScan || _scannerPaused) {
      return;
    }

    String? detectedCode;

    for (final Barcode barcode in capture.barcodes) {
      final String code =
          barcode.rawValue?.trim() ?? '';

      if (code.isNotEmpty) {
        detectedCode = code;
        break;
      }
    }

    if (detectedCode == null ||
        detectedCode.isEmpty) {
      return;
    }

    await _processTrackingCode(
      detectedCode,
    );
  }

  Future<void> _processTrackingCode(
    String rawCode,
  ) async {
    if (_handlingScan) {
      return;
    }

    final String code = rawCode.trim();

    if (code.isEmpty) {
      setState(() {
        _errorMessage =
            'Enter or scan a valid tracking code.';
      });

      return;
    }

    setState(() {
      _handlingScan = true;
      _errorMessage = null;
    });

    try {
      final String? expected =
          widget.expectedTrackingCode
              ?.trim();

      if (expected != null &&
          expected.isNotEmpty &&
          code != expected) {
        await _scannerController.stop();

        if (!mounted) {
          return;
        }

        setState(() {
          _scannerPaused = true;

          _scannedCode = code;

          _errorMessage =
              'The scanned tracking number does not match this pickup assignment.';
        });

        return;
      }

      await _scannerController.stop();

      if (!mounted) {
        return;
      }

      setState(() {
        _scannerPaused = true;
        _scannedCode = code;
        _manualCodeController.text = code;
      });

      final RiderScannerCallback? callback =
          widget.onScanned;

      if (callback != null) {
        await callback(
          code,
        );

        return;
      }

      if (!mounted) {
        return;
      }

      /// If scanner was pushed from another page,
      /// return the scanned tracking code.
      if (context.canPop()) {
        context.pop(
          code,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Unable to process parcel: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _handlingScan = false;
        });
      }
    }
  }

  Future<void> _submitManualCode() async {
    final String code =
        _manualCodeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _errorMessage =
            'Enter the parcel tracking code.';
      });

      return;
    }

    await _processTrackingCode(
      code,
    );
  }

  Future<void> _scanAgain() async {
    if (_handlingScan) {
      return;
    }

    setState(() {
      _scannedCode = null;
      _errorMessage = null;
      _scannerPaused = false;
    });

    try {
      await _scannerController.start();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Unable to restart camera: $error';
      });
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Unable to control flashlight: $error';
      });
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _scannerController.switchCamera();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Unable to switch camera: $error';
      });
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) {
      return;
    }

    setState(() {
      _signingOut = true;
    });

    try {
      if (widget.onSignOut != null) {
        await widget.onSignOut!();
      }

      if (!mounted) {
        return;
      }

      context.go(
        '/login',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to sign out: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _signingOut = false;
        });
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Parcel Scanner',
          style: TextStyle(
            color: _text,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          if (widget.showSignOut)
            TextButton.icon(
              onPressed:
                  _signingOut
                      ? null
                      : _signOut,
              icon:
                  _signingOut
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _primary,
                          ),
                        )
                      : const Icon(
                          Icons.logout_rounded,
                          size: 18,
                        ),
              label: Text(
                _signingOut
                    ? 'Signing Out'
                    : 'Sign Out',
              ),
              style: TextButton.styleFrom(
                foregroundColor:
                    _primary,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            100,
          ),
          children: <Widget>[
            _buildHeading(),

            const SizedBox(
              height: 18,
            ),

            _buildScanner(),

            const SizedBox(
              height: 16,
            ),

            if (_errorMessage != null) ...<
                Widget>[
              _buildErrorMessage(),

              const SizedBox(
                height: 16,
              ),
            ],

            if (_scannedCode != null &&
                _errorMessage == null) ...<
                Widget>[
              _buildSuccessMessage(),

              const SizedBox(
                height: 16,
              ),
            ],

            _buildManualEntry(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeading() {
    final String? expected =
        widget.expectedTrackingCode
            ?.trim();

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'PARCEL VERIFICATION',
          style: TextStyle(
            color: _primary,
            fontSize: 10.5,
            letterSpacing: 1.7,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(
          height: 7,
        ),

        const Text(
          'Scan Waybill',
          style: TextStyle(
            color: _text,
            fontSize: 28,
            height: 1.1,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(
          height: 8,
        ),

        const Text(
          'Scan the QR code or barcode printed on the seller\'s parcel waybill.',
          style: TextStyle(
            color: _muted,
            fontSize: 13,
            height: 1.5,
          ),
        ),

        if (expected != null &&
            expected.isNotEmpty) ...<Widget>[
          const SizedBox(
            height: 10,
          ),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Text(
              'Expected: $expected',
              style: const TextStyle(
                color: _primary,
                fontSize: 11.5,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScanner() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: _border,
        ),
      ),
      child: Column(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 0.90,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: MobileScanner(
                    controller:
                        _scannerController,
                    onDetect:
                        _onDetect,
                  ),
                ),

                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter:
                          _ScannerOverlayPainter(),
                    ),
                  ),
                ),

                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                    children: <Widget>[
                      _ScannerControlButton(
                        icon:
                            Icons
                                .flashlight_on_rounded,
                        tooltip:
                            'Flashlight',
                        onTap:
                            _toggleTorch,
                      ),
                      _ScannerControlButton(
                        icon:
                            Icons
                                .cameraswitch_rounded,
                        tooltip:
                            'Switch Camera',
                        onTap:
                            _switchCamera,
                      ),
                    ],
                  ),
                ),

                const Positioned(
                  left: 24,
                  right: 24,
                  bottom: 22,
                  child: Text(
                    'Place the QR code or barcode inside the frame.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight:
                          FontWeight.w700,
                      shadows: <Shadow>[
                        Shadow(
                          color:
                              Colors.black,
                          blurRadius:
                              6,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_handlingScan)
                  Positioned.fill(
                    child: Container(
                      color:
                          const Color(
                        0x66000000,
                      ),
                      alignment:
                          Alignment.center,
                      child:
                          const Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: <
                            Widget>[
                          CircularProgressIndicator(
                            color:
                                Colors.white,
                          ),
                          SizedBox(
                            height:
                                12,
                          ),
                          Text(
                            'Processing parcel...',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(
              14,
            ),
            color: _surface,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _scannerPaused
                        ? 'Scanner paused'
                        : 'Camera scanner active',
                    style:
                        const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),

                if (_scannerPaused)
                  TextButton.icon(
                    onPressed:
                        _scanAgain,
                    icon:
                        const Icon(
                      Icons
                          .refresh_rounded,
                      size:
                          18,
                    ),
                    label:
                        const Text(
                      'Scan Again',
                    ),
                    style:
                        TextButton.styleFrom(
                      foregroundColor:
                          _primary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntry() {
    return Container(
      padding: const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: _border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Manual Tracking Code',
            style: TextStyle(
              color: _text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          const Text(
            'If the camera cannot read the waybill, enter the parcel tracking code manually.',
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          TextField(
            controller:
                _manualCodeController,
            enabled:
                !_handlingScan,
            autocorrect: false,
            textCapitalization:
                TextCapitalization
                    .characters,
            textInputAction:
                TextInputAction.done,
            onSubmitted:
                (
              String value,
            ) {
              _submitManualCode();
            },
            decoration: InputDecoration(
              hintText:
                  'Enter tracking code',
              prefixIcon:
                  const Icon(
                Icons
                    .confirmation_number_outlined,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                borderSide:
                    const BorderSide(
                  color: _border,
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
                  color: _primary,
                  width: 1.4,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          SizedBox(
            width: double.infinity,
            height: 49,
            child: ElevatedButton.icon(
              onPressed:
                  _handlingScan
                      ? null
                      : _submitManualCode,
              style:
                  ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor:
                    _primary,
                foregroundColor:
                    Colors.white,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
              icon: const Icon(
                Icons
                    .verified_outlined,
              ),
              label: const Text(
                'Use Tracking Code',
                style: TextStyle(
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

  Widget _buildSuccessMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        14,
      ),
      decoration: BoxDecoration(
        color: _successSoft,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color: const Color(
            0xFFB7DFC5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons
                .check_circle_rounded,
            color: _success,
            size: 22,
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Parcel code scanned',
                  style: TextStyle(
                    color: _success,
                    fontSize: 12.5,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  _scannedCode ?? '',
                  style: const TextStyle(
                    color: _success,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: 'Scan Again',
            onPressed:
                _scanAgain,
            icon: const Icon(
              Icons.refresh_rounded,
              color: _success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        14,
      ),
      decoration: BoxDecoration(
        color: _dangerSoft,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color: const Color(
            0xFFF4C3BE,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            color: _danger,
            size: 22,
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: _danger,
                fontSize: 12.5,
                height: 1.45,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),

          IconButton(
            tooltip: 'Scan Again',
            onPressed:
                _scanAgain,
            icon: const Icon(
              Icons.refresh_rounded,
              color: _danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerControlButton
    extends StatelessWidget {
  final IconData icon;

  final String tooltip;

  final Future<void> Function()
      onTap;

  const _ScannerControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: const Color(
        0x99000000,
      ),
      borderRadius:
          BorderRadius.circular(
        100,
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        color: Colors.white,
        icon: Icon(
          icon,
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter
    extends CustomPainter {
  static const Color _overlay =
      Color(0x77000000);

  static const Color _frame =
      Colors.white;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final double frameWidth =
        size.width * 0.72;

    final double frameHeight =
        frameWidth * 0.62;

    final Rect frameRect =
        Rect.fromCenter(
      center: Offset(
        size.width / 2,
        size.height / 2,
      ),
      width: frameWidth,
      height: frameHeight,
    );

    final RRect frame =
        RRect.fromRectAndRadius(
      frameRect,
      const Radius.circular(
        20,
      ),
    );

    final Path fullScreen =
        Path()
          ..addRect(
            Offset.zero &
                size,
          );

    final Path hole =
        Path()
          ..addRRect(
            frame,
          );

    final Path overlayPath =
        Path.combine(
      PathOperation.difference,
      fullScreen,
      hole,
    );

    canvas.drawPath(
      overlayPath,
      Paint()
        ..color =
            _overlay,
    );

    final Paint cornerPaint =
        Paint()
          ..color =
              _frame
          ..strokeWidth =
              4
          ..style =
              PaintingStyle.stroke
          ..strokeCap =
              StrokeCap.round;

    const double corner =
        30;

    /// Top left.
    canvas.drawLine(
      Offset(
        frameRect.left,
        frameRect.top + corner,
      ),
      Offset(
        frameRect.left,
        frameRect.top,
      ),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(
        frameRect.left,
        frameRect.top,
      ),
      Offset(
        frameRect.left + corner,
        frameRect.top,
      ),
      cornerPaint,
    );

    /// Top right.
    canvas.drawLine(
      Offset(
        frameRect.right - corner,
        frameRect.top,
      ),
      Offset(
        frameRect.right,
        frameRect.top,
      ),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(
        frameRect.right,
        frameRect.top,
      ),
      Offset(
        frameRect.right,
        frameRect.top + corner,
      ),
      cornerPaint,
    );

    /// Bottom left.
    canvas.drawLine(
      Offset(
        frameRect.left,
        frameRect.bottom - corner,
      ),
      Offset(
        frameRect.left,
        frameRect.bottom,
      ),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(
        frameRect.left,
        frameRect.bottom,
      ),
      Offset(
        frameRect.left + corner,
        frameRect.bottom,
      ),
      cornerPaint,
    );

    /// Bottom right.
    canvas.drawLine(
      Offset(
        frameRect.right - corner,
        frameRect.bottom,
      ),
      Offset(
        frameRect.right,
        frameRect.bottom,
      ),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(
        frameRect.right,
        frameRect.bottom,
      ),
      Offset(
        frameRect.right,
        frameRect.bottom - corner,
      ),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter
        oldDelegate,
  ) {
    return false;
  }
}
