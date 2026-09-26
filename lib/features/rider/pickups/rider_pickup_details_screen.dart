import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'rider_pickups_screen.dart';

class RiderPickupDetailsScreen
    extends StatefulWidget {
  final RiderPickupData pickup;

  final bool initialVerified;

  final String? initialTrackingCode;

  final String? statusMessage;

  final RiderPickupVerifyCallback?
      onVerifyTracking;

  final RiderPickupTransitionCallback?
      onTransition;

  final VoidCallback? onBack;

  final VoidCallback?
      onBackToPickups;

  const RiderPickupDetailsScreen({
    super.key,
    required this.pickup,
    this.initialVerified = false,
    this.initialTrackingCode,
    this.statusMessage,
    this.onVerifyTracking,
    this.onTransition,
    this.onBack,
    this.onBackToPickups,
  });

  @override
  State<RiderPickupDetailsScreen>
      createState() {
    return _RiderPickupDetailsScreenState();
  }
}

class _RiderPickupDetailsScreenState
    extends State<
        RiderPickupDetailsScreen> {
  static const Color _background =
      Color(0xFFFBF7F2);

  static const Color _surface =
      Color(0xFFFFFDF9);

  static const Color _border =
      Color(0xFFEADCCC);

  static const Color _maroon =
      Color(0xFF561C17);

  static const Color _text =
      Color(0xFF3B211B);

  static const Color _muted =
      Color(0xFF987865);

  static const Color _success =
      Color(0xFF237A44);

  static const Color _successSoft =
      Color(0xFFEAF6EE);

  static const Color _danger =
      Color(0xFFB42318);

  static const Color _dangerSoft =
      Color(0xFFFFF1F0);

  static const Color _warning =
      Color(0xFF946514);

  static const Color _warningSoft =
      Color(0xFFFFF3DC);

  late RiderPickupData _pickup;

  late bool _verified;

  final TextEditingController
      _trackingController =
      TextEditingController();

  bool _verifying = false;

  bool _submitting = false;

  String? _verificationError;

  @override
  void initState() {
    super.initState();

    _pickup =
        widget.pickup;

    _verified =
        widget.initialVerified;

    _trackingController.text =
        widget.initialTrackingCode
                ?.trim() ??
            '';
  }

  @override
  void didUpdateWidget(
    covariant RiderPickupDetailsScreen
        oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.pickup.id !=
            widget.pickup.id ||
        oldWidget.pickup.status !=
            widget.pickup.status ||
        oldWidget
                .pickup
                .trackingCode !=
            widget
                .pickup
                .trackingCode) {
      _pickup =
          widget.pickup;

      _verified =
          widget.initialVerified;

      _verificationError =
          null;

      _trackingController.text =
          widget.initialTrackingCode
                  ?.trim() ??
              '';
    }
  }

  @override
  void dispose() {
    _trackingController.dispose();

    super.dispose();
  }

  Future<void> _openScanner() async {
    final String? scannedCode =
        await Navigator.of(
      context,
    ).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog:
            true,
        builder:
            (
          BuildContext context,
        ) {
          return const RiderParcelScannerScreen();
        },
      ),
    );

    if (!mounted ||
        scannedCode == null ||
        scannedCode
            .trim()
            .isEmpty) {
      return;
    }

    _trackingController.text =
        scannedCode.trim();

    setState(() {
      _verified =
          false;

      _verificationError =
          null;
    });

    await _verifyParcel();
  }

  Future<void> _verifyParcel() async {
    if (_verifying) {
      return;
    }

    final String tracking =
        _trackingController.text
            .trim();

    if (tracking.isEmpty) {
      setState(() {
        _verified =
            false;

        _verificationError =
            'Enter or scan the parcel tracking code.';
      });

      return;
    }

    setState(() {
      _verifying =
          true;

      _verified =
          false;

      _verificationError =
          null;
    });

    try {
      final RiderPickupVerifyCallback?
          callback =
          widget.onVerifyTracking;

      final bool verified =
          callback == null
              ? tracking ==
                  _pickup.trackingCode
              : await callback(
                  _pickup,
                  tracking,
                );

      if (!mounted) {
        return;
      }

      setState(() {
        _verified =
            verified;

        _verificationError =
            verified
                ? null
                : 'The scanned tracking number does not match this pickup assignment.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _verified =
            false;

        _verificationError =
            'Unable to verify parcel: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _verifying =
              false;
        });
      }
    }
  }

  Future<void> _confirmPickedUp() async {
    if (!_verified) {
      _showMessage(
        'Scan and verify the seller waybill before confirming pickup.',
      );

      return;
    }

    final bool updated =
        await _transition(
      'picked_up',
    );

    if (updated &&
        mounted) {
      setState(() {
        _pickup =
            _pickup.copyWith(
          status:
              'PICKED_UP',
          statusLabel:
              'Picked Up',
        );

        _verified =
            false;
      });
    }
  }

  Future<void> _markInTransit() async {
    final bool updated =
        await _transition(
      'in_transit',
    );

    if (updated &&
        mounted) {
      setState(() {
        _pickup =
            _pickup.copyWith(
          status:
              'IN_TRANSIT',
          statusLabel:
              'In Transit',
        );
      });
    }
  }

  Future<bool> _transition(
    String status,
  ) async {
    if (_submitting) {
      return false;
    }

    final RiderPickupTransitionCallback?
        callback =
        widget.onTransition;

    if (callback == null) {
      _showMessage(
        'Rider pickup transition API is not connected yet.',
      );

      return false;
    }

    setState(() {
      _submitting =
          true;
    });

    try {
      await callback(
        RiderPickupTransitionRequest(
          pickup:
              _pickup,
          status:
              status,
        ),
      );

      if (!mounted) {
        return false;
      }

      _showMessage(
        'Pickup status updated.',
      );

      return true;
    } catch (error) {
      if (mounted) {
        _showMessage(
          'Unable to update pickup: $error',
        );
      }

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _submitting =
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
        leading:
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
          ),
        ),
        title:
            const Text(
          'Pickup Details',
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
            ListView(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            10,
            16,
            100,
          ),
          children: <Widget>[
            if (widget
                    .statusMessage
                    ?.trim()
                    .isNotEmpty ==
                true) ...<Widget>[
              _buildStatusMessage(
                widget
                    .statusMessage!,
              ),

              const SizedBox(
                height:
                    14,
              ),
            ],

            _buildHero(),

            const SizedBox(
              height:
                  14,
            ),

            _buildParcelInformation(),

            const SizedBox(
              height:
                  14,
            ),

            _buildPickupActions(),

            if (_pickup
                .isPickupAssigned) ...<
                Widget>[
              const SizedBox(
                height:
                    14,
              ),

              _buildScannerSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
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
          const Text(
            'PICKUP DETAILS',
            style:
                TextStyle(
              color:
                  _maroon,
              fontSize:
                  11.5,
              letterSpacing:
                  1.7,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height:
                7,
          ),

          Text(
            _pickup.trackingCode,
            style:
                const TextStyle(
              color:
                  _text,
              fontSize:
                  25,
              height:
                  1.1,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height:
                8,
          ),

          Text(
            '${_pickup.statusLabel} - Seller: ${_pickup.sellerName}',
            style:
                const TextStyle(
              color:
                  _muted,
              fontSize:
                  13.5,
              height:
                  1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParcelInformation() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        16,
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
          const Text(
            'Parcel Information',
            style:
                TextStyle(
              color:
                  _text,
              fontSize:
                  17,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height:
                16,
          ),

          _PickupInfoRow(
            label:
                'Buyer',
            value:
                _pickup.buyerName,
          ),

          const SizedBox(
            height:
                12,
          ),

          _PickupInfoRow(
            label:
                'Delivery Address',
            value:
                _pickup.address,
          ),

          const SizedBox(
            height:
                12,
          ),

          _PickupInfoRow(
            label:
                'Items',
            value:
                _pickup.itemCount
                    .toString(),
          ),

          const SizedBox(
            height:
                12,
          ),

          _PickupInfoRow(
            label:
                'Order Amount',
            value:
                _pickup.amount,
          ),
        ],
      ),
    );
  }

  Widget _buildPickupActions() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        16,
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
            CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Pickup Actions',
            style:
                TextStyle(
              color:
                  _text,
              fontSize:
                  17,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height:
                14,
          ),

          if (_pickup
                  .isPickupAssigned &&
              _verified) ...<Widget>[
            Container(
              padding:
                  const EdgeInsets.all(
                13,
              ),
              decoration:
                  BoxDecoration(
                color:
                    _successSoft,
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                border:
                    Border.all(
                  color:
                      const Color(
                    0xFFB7DFC5,
                  ),
                ),
              ),
              child:
                  Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons
                        .verified_rounded,
                    color:
                        _success,
                    size:
                        20,
                  ),

                  const SizedBox(
                    width:
                        8,
                  ),

                  Expanded(
                    child:
                        Text(
                      'Parcel Verified: ${_pickup.trackingCode}',
                      style:
                          const TextStyle(
                        color:
                            _success,
                        fontSize:
                            12.5,
                        height:
                            1.4,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height:
                  12,
            ),

            _PickupPrimaryButton(
              label:
                  'Confirm Picked Up',
              icon:
                  Icons
                      .inventory_2_outlined,
              loading:
                  _submitting,
              onPressed:
                  _confirmPickedUp,
            ),
          ],

          if (_pickup
                  .isPickupAssigned &&
              !_verified)
            const Text(
              'Scan and verify the seller\'s waybill below before confirming collection.',
              style:
                  TextStyle(
                color:
                    _muted,
                fontSize:
                    13,
                height:
                    1.5,
              ),
            ),

          if (_pickup.isPickedUp)
            _PickupPrimaryButton(
              label:
                  'Mark In Transit',
              icon:
                  Icons
                      .local_shipping_outlined,
              loading:
                  _submitting,
              onPressed:
                  _markInTransit,
            ),

          if (!_pickup
                  .isPickupAssigned &&
              !_pickup.isPickedUp)
            Container(
              padding:
                  const EdgeInsets.all(
                12,
              ),
              decoration:
                  BoxDecoration(
                color:
                    _warningSoft,
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child:
                  Text(
                'Current pickup status: ${_pickup.statusLabel}',
                style:
                    const TextStyle(
                  color:
                      _warning,
                  fontSize:
                      12.5,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),

          const SizedBox(
            height:
                10,
          ),

          SizedBox(
            height:
                48,
            child:
                OutlinedButton.icon(
              onPressed:
                  widget.onBackToPickups ??
                      () {
                        Navigator.of(
                          context,
                        ).maybePop();
                      },
              icon:
                  const Icon(
                Icons
                    .arrow_back_rounded,
              ),
              label:
                  const Text(
                'Back To Pickups',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    _text,
                side:
                    const BorderSide(
                  color:
                      _border,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerSection() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        16,
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
            CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width:
                    42,
                height:
                    42,
                alignment:
                    Alignment.center,
                decoration:
                    BoxDecoration(
                  color:
                      _warningSoft,
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .qr_code_scanner_rounded,
                  color:
                      _warning,
                  size:
                      22,
                ),
              ),

              const SizedBox(
                width:
                    10,
              ),

              const Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Scan Parcel At Seller',
                      style:
                          TextStyle(
                        color:
                            _text,
                        fontSize:
                            17,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    SizedBox(
                      height:
                          4,
                    ),

                    Text(
                      'The tracking code must match this pickup assignment. Scanning alone does not mark the parcel picked up.',
                      style:
                          TextStyle(
                        color:
                            _muted,
                        fontSize:
                            12,
                        height:
                            1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                16,
          ),

          SizedBox(
            height:
                50,
            child:
                ElevatedButton.icon(
              onPressed:
                  _verifying
                      ? null
                      : _openScanner,
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
                    12,
                  ),
                ),
              ),
              icon:
                  const Icon(
                Icons
                    .qr_code_scanner_rounded,
              ),
              label:
                  const Text(
                'Scan QR / Barcode',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ),

          const SizedBox(
            height:
                14,
          ),

          const Row(
            children: <Widget>[
              Expanded(
                child:
                    Divider(
                  color:
                      _border,
                ),
              ),

              Padding(
                padding:
                    EdgeInsets.symmetric(
                  horizontal:
                      10,
                ),
                child:
                    Text(
                  'OR ENTER TRACKING CODE',
                  style:
                      TextStyle(
                    color:
                        _muted,
                    fontSize:
                        10,
                    letterSpacing:
                        0.7,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),

              Expanded(
                child:
                    Divider(
                  color:
                      _border,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                14,
          ),

          TextField(
            controller:
                _trackingController,
            enabled:
                !_verifying,
            autocorrect:
                false,
            textCapitalization:
                TextCapitalization.characters,
            decoration:
                InputDecoration(
              hintText:
                  'Tracking code',
              prefixIcon:
                  const Icon(
                Icons
                    .confirmation_number_outlined,
              ),
              filled:
                  true,
              fillColor:
                  Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal:
                    14,
                vertical:
                    14,
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
                      _border,
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
                      _maroon,
                  width:
                      1.4,
                ),
              ),
            ),
            onChanged:
                (
              String value,
            ) {
              if (_verified ||
                  _verificationError !=
                      null) {
                setState(() {
                  _verified =
                      false;

                  _verificationError =
                      null;
                });
              }
            },
          ),

          const SizedBox(
            height:
                12,
          ),

          SizedBox(
            height:
                48,
            child:
                OutlinedButton.icon(
              onPressed:
                  _verifying
                      ? null
                      : _verifyParcel,
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    _maroon,
                side:
                    const BorderSide(
                  color:
                      _border,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
              icon:
                  _verifying
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
                                _maroon,
                          ),
                        )
                      : const Icon(
                          Icons
                              .verified_outlined,
                        ),
              label:
                  Text(
                _verifying
                    ? 'Verifying...'
                    : 'Verify Parcel',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ),

          if (_verified) ...<Widget>[
            const SizedBox(
              height:
                  12,
            ),

            Container(
              padding:
                  const EdgeInsets.all(
                12,
              ),
              decoration:
                  BoxDecoration(
                color:
                    _successSoft,
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child:
                  const Row(
                children: <Widget>[
                  Icon(
                    Icons
                        .check_circle_rounded,
                    color:
                        _success,
                    size:
                        20,
                  ),

                  SizedBox(
                    width:
                        8,
                  ),

                  Expanded(
                    child:
                        Text(
                      'Parcel verified successfully.',
                      style:
                          TextStyle(
                        color:
                            _success,
                        fontSize:
                            12.5,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_verificationError !=
              null) ...<Widget>[
            const SizedBox(
              height:
                  12,
            ),

            Container(
              padding:
                  const EdgeInsets.all(
                12,
              ),
              decoration:
                  BoxDecoration(
                color:
                    _dangerSoft,
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                border:
                    Border.all(
                  color:
                      const Color(
                    0xFFF5C5C1,
                  ),
                ),
              ),
              child:
                  Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons
                        .error_outline_rounded,
                    color:
                        _danger,
                    size:
                        20,
                  ),

                  const SizedBox(
                    width:
                        8,
                  ),

                  Expanded(
                    child:
                        Text(
                      _verificationError!,
                      style:
                          const TextStyle(
                        color:
                            _danger,
                        fontSize:
                            12.5,
                        height:
                            1.45,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusMessage(
    String message,
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
            _successSoft,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFB7DFC5,
          ),
        ),
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons
                .check_circle_outline_rounded,
            color:
                _success,
            size:
                20,
          ),

          const SizedBox(
            width:
                9,
          ),

          Expanded(
            child:
                Text(
              message,
              style:
                  const TextStyle(
                color:
                    _success,
                fontSize:
                    13,
                height:
                    1.45,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RiderParcelScannerScreen
    extends StatefulWidget {
  const RiderParcelScannerScreen({
    super.key,
  });

  @override
  State<RiderParcelScannerScreen>
      createState() {
    return _RiderParcelScannerScreenState();
  }
}

class _RiderParcelScannerScreenState
    extends State<
        RiderParcelScannerScreen> {
  bool _handled =
      false;

  void _onDetect(
    BarcodeCapture capture,
  ) {
    if (_handled) {
      return;
    }

    for (final Barcode barcode
        in capture.barcodes) {
      final String value =
          barcode.rawValue
                  ?.trim() ??
              '';

      if (value.isEmpty) {
        continue;
      }

      _handled =
          true;

      Navigator.of(
        context,
      ).pop(
        value,
      );

      return;
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Colors.black,
      appBar:
          AppBar(
        backgroundColor:
            Colors.black,
        foregroundColor:
            Colors.white,
        elevation:
            0,
        title:
            const Text(
          'Scan Parcel At Seller',
          style:
              TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
      body:
          Stack(
        children: <Widget>[
          Positioned.fill(
            child:
                MobileScanner(
              onDetect:
                  _onDetect,
            ),
          ),

          Positioned.fill(
            child:
                IgnorePointer(
              child:
                  Center(
                child:
                    Container(
                  width:
                      260,
                  height:
                      180,
                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(
                      22,
                    ),
                    border:
                        Border.all(
                      color:
                          Colors.white,
                      width:
                          3,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            left:
                18,
            right:
                18,
            bottom:
                30,
            child:
                Container(
              padding:
                  const EdgeInsets.all(
                15,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.black.withValues(
                  alpha: 0.72,
                ),
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
              ),
              child:
                  const Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons
                        .qr_code_scanner_rounded,
                    color:
                        Colors.white,
                    size:
                        30,
                  ),

                  SizedBox(
                    height:
                        8,
                  ),

                  Text(
                    'Point the camera at the seller\'s waybill QR code or barcode.',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          13,
                      height:
                          1.4,
                      fontWeight:
                          FontWeight.w700,
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
}

class _PickupInfoRow
    extends StatelessWidget {
  final String label;

  final String value;

  const _PickupInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style:
              const TextStyle(
            color:
                Color(
              0xFF987865,
            ),
            fontSize:
                11.5,
          ),
        ),

        const SizedBox(
          height:
              3,
        ),

        Text(
          value,
          style:
              const TextStyle(
            color:
                Color(
              0xFF3B211B,
            ),
            fontSize:
                13.5,
            height:
                1.45,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PickupPrimaryButton
    extends StatelessWidget {
  final String label;

  final IconData icon;

  final bool loading;

  final VoidCallback onPressed;

  const _PickupPrimaryButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      height:
          50,
      child:
          ElevatedButton.icon(
        onPressed:
            loading
                ? null
                : onPressed,
        style:
            ElevatedButton.styleFrom(
          elevation:
              0,
          backgroundColor:
              const Color(
            0xFF561C17,
          ),
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
        icon:
            loading
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
                          Colors.white,
                    ),
                  )
                : Icon(
                    icon,
                  ),
        label:
            Text(
          label,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
