import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/auth_service.dart';
import 'rider_delivery_models.dart';
import 'rider_proof_watermark.dart';

class RiderDeliveryDetailsScreen extends StatefulWidget {
  final RiderDeliveryData? delivery;
  final String? statusMessage;
  final String? errorMessage;
  final bool showPreviewWhenNull;

  final RiderDeliveryTransitionCallback? onTransition;
  final RiderProofPickerCallback? onChooseProof;
  final RiderDeliveryCallback? onViewTracking;
  final VoidCallback? onBackToDeliveries;

  const RiderDeliveryDetailsScreen({
    super.key,
    this.delivery,
    this.statusMessage,
    this.errorMessage,
    this.showPreviewWhenNull = true,
    this.onTransition,
    this.onChooseProof,
    this.onViewTracking,
    this.onBackToDeliveries,
  });

  @override
  State<RiderDeliveryDetailsScreen> createState() =>
      _RiderDeliveryDetailsScreenState();
}

class _RiderDeliveryDetailsScreenState
    extends State<RiderDeliveryDetailsScreen> {
  static const Color _background = Color(0xFFFBF7F2);
  static const Color _surface = Color(0xFFFFFDF9);
  static const Color _soft = Color(0xFFF6EFE7);
  static const Color _border = Color(0xFFEADCCC);
  static const Color _maroon = Color(0xFF561C17);
  static const Color _text = Color(0xFF3B211B);
  static const Color _muted = Color(0xFF987865);
  static const Color _danger = Color(0xFFB42318);
  static const Color _success = Color(0xFF1B7A46);

  static const RiderDeliveryData _sampleDelivery = RiderDeliveryData(
    id: 39,
    trackingCode: 'LKH-DLV-2026-0039',
    buyerName: 'Angela Reyes',
    contact: '0919 765 4321',
    address: '1 Sample Street, Masico, Pila, Laguna, 4010',
    amount: 965,
    status: 'out_for_delivery',
    statusLabel: 'Out For Delivery',
    imageUrl:
        'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=600&q=85&auto=format&fit=crop',
    isPreview: true,
  );

  late RiderDeliveryData _delivery;
  final TextEditingController _receiverController = TextEditingController();
  final TextEditingController _failureController = TextEditingController();

  String? _proofPath;
  bool _submitting = false;

  bool get _usingPreview => widget.delivery == null && widget.showPreviewWhenNull;

  @override
  void initState() {
    super.initState();
    _delivery = widget.delivery ?? _sampleDelivery;
  }

  @override
  void didUpdateWidget(covariant RiderDeliveryDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.delivery != widget.delivery && widget.delivery != null) {
      _delivery = widget.delivery!;
    }
  }

  @override
  void dispose() {
    _receiverController.dispose();
    _failureController.dispose();
    super.dispose();
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
          backgroundColor: error ? _danger : const Color(0xFF3E130F),
          content: Text(message),
        ),
      );
  }

  Future<void> _chooseProof() async {
    if (widget.onChooseProof != null) {
      final String? path = await widget.onChooseProof!();
      if (!mounted || path == null || path.trim().isEmpty) {
        return;
      }
      setState(() {
        _proofPath = path;
      });
      return;
    }

    try {
      final String riderName = (await AuthService.getCurrentUser()).name.trim();
      if (riderName.isEmpty) {
        throw Exception('Unable to load the rider name for the watermark.');
      }
      final position = await RiderProofWatermark.requireCurrentPosition();

      if (!mounted) {
        return;
      }

      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (!mounted || image == null) {
        return;
      }

      final String stampedPath = await RiderProofWatermark.stamp(
        imagePath: image.path,
        riderName: riderName,
        capturedAt: DateTime.now(),
        position: position,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _proofPath = stampedPath;
      });

      _showMessage('Proof of delivery captured.');
    } catch (error) {
      _showMessage(
        'Unable to capture watermarked proof: $error',
        error: true,
      );
    }
  }

  Future<void> _transition(
    String status, {
    String? note,
    String? receiverName,
    String? proofPath,
  }) async {
    if (_submitting) {
      return;
    }

    final RiderDeliveryTransitionCallback? callback = widget.onTransition;

    if (callback == null && !_delivery.isPreview) {
      _showMessage('Delivery transition is not connected to Laravel yet.', error: true);
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      if (callback != null) {
        await callback(
          RiderDeliveryTransitionRequest(
            delivery: _delivery,
            status: status,
            note: note,
            receiverName: receiverName,
            proofPath: proofPath,
          ),
        );
      }

      if (!mounted) {
        return;
      }

      final String label = _labelForStatus(status);

      setState(() {
        _delivery = _delivery.copyWith(
          status: status,
          statusLabel: label,
          failureReason: status == 'failed' ? note : null,
        );
      });

      _showMessage(
        _delivery.isPreview
            ? 'Preview moved to $label. Nothing was saved.'
            : 'Parcel moved to $label.',
      );
    } catch (error) {
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _submitDelivered() async {
    final String receiver = _receiverController.text.trim();

    if (receiver.isEmpty) {
      _showMessage('Enter the receiver name.', error: true);
      return;
    }

    if (_proofPath == null || _proofPath!.trim().isEmpty) {
      _showMessage('Add a proof of delivery image.', error: true);
      return;
    }

    await _transition(
      'delivered',
      receiverName: receiver,
      proofPath: _proofPath,
    );
  }

  Future<void> _submitFailed() async {
    final String note = _failureController.text.trim();

    if (note.isEmpty) {
      _showMessage('Enter a reason for the failed delivery.', error: true);
      return;
    }

    await _transition('failed', note: note);
  }

  String _labelForStatus(String status) {
    switch (status) {
      case 'in_transit':
        return 'In Transit';
      case 'out_for_delivery':
        return 'Out For Delivery';
      case 'delivered':
        return 'Delivered';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: widget.onBackToDeliveries ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, color: _text),
        ),
        title: const Text(
          'Delivery Details',
          style: TextStyle(
            color: _text,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
          children: <Widget>[
            if (widget.statusMessage?.trim().isNotEmpty == true) ...<Widget>[
              _MessageBanner(
                message: widget.statusMessage!,
                error: false,
              ),
              const SizedBox(height: 12),
            ],
            if (widget.errorMessage?.trim().isNotEmpty == true) ...<Widget>[
              _MessageBanner(
                message: widget.errorMessage!,
                error: true,
              ),
              const SizedBox(height: 12),
            ],
            if (_usingPreview) ...<Widget>[
              const _PreviewDetailsNotice(),
              const SizedBox(height: 14),
            ],
            _buildHero(),
            const SizedBox(height: 14),
            _buildRecipientCard(),
            const SizedBox(height: 14),
            _buildActionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'DELIVERY DETAILS',
            style: TextStyle(
              color: _maroon,
              fontSize: 11.5,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _delivery.trackingCode,
            style: const TextStyle(
              color: _text,
              fontSize: 25,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_delivery.statusLabel} · Buyer: ${_delivery.buyerName}',
            style: const TextStyle(
              color: _muted,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientCard() {
    return _SectionCard(
      title: 'Recipient',
      icon: Icons.person_pin_circle_outlined,
      child: Column(
        children: <Widget>[
          _DetailRow(label: 'Buyer', value: _delivery.buyerName),
          const SizedBox(height: 13),
          _DetailRow(label: 'Contact', value: _delivery.contact),
          const SizedBox(height: 13),
          _DetailRow(label: 'Delivery Address', value: _delivery.address),
          const SizedBox(height: 13),
          _DetailRow(
            label: 'Order Amount',
            value: formatRiderMoney(_delivery.amount),
            valueColor: _maroon,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    final String status = _delivery.normalizedStatus;

    return _SectionCard(
      title: 'Delivery Actions',
      icon: Icons.local_shipping_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (status == 'picked_up')
            _PrimaryActionButton(
              text: _submitting ? 'Updating...' : 'Mark In Transit',
              icon: Icons.route_outlined,
              enabled: !_submitting,
              onPressed: () => _transition('in_transit'),
            ),
          if (status == 'in_transit')
            _PrimaryActionButton(
              text: _submitting ? 'Updating...' : 'Out For Delivery',
              icon: Icons.near_me_outlined,
              enabled: !_submitting,
              onPressed: () => _transition('out_for_delivery'),
            ),
          if (status == 'out_for_delivery') ...<Widget>[
            const Text(
              'CONFIRM DELIVERY',
              style: TextStyle(
                color: _maroon,
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _receiverController,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration('Receiver name'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _chooseProof,
              style: OutlinedButton.styleFrom(
                foregroundColor: _maroon,
                side: const BorderSide(color: _border),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(
                _proofPath == null ? 'Add Proof of Delivery' : 'Proof: ${_proofPath!.split('/').last}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submitDelivered,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.task_alt_rounded),
                label: Text(
                  _submitting ? 'Updating...' : 'Mark Delivered',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: _border),
            const SizedBox(height: 18),
            const Text(
              'FAILED DELIVERY',
              style: TextStyle(
                color: _danger,
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _failureController,
              enabled: !_submitting,
              minLines: 3,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: _inputDecoration('Reason for failed delivery'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _submitting ? null : _submitFailed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _danger,
                  backgroundColor: const Color(0xFFFCEBE8),
                  side: const BorderSide(color: Color(0xFFE5B4A9)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text(
                  'Record Delivery Failed',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
          if (!<String>{'picked_up', 'in_transit', 'out_for_delivery'}.contains(status))
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status == 'delivered'
                    ? 'This parcel has already been delivered.'
                    : status == 'failed' || status == 'delivery_failed'
                        ? 'This delivery is recorded as failed.'
                        : 'No delivery transition is available for the current status.',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: widget.onViewTracking == null
                ? null
                : () => widget.onViewTracking!(_delivery),
            style: OutlinedButton.styleFrom(
              foregroundColor: _text,
              side: const BorderSide(color: _border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.location_searching_rounded),
            label: const Text(
              'View Tracking',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: widget.onBackToDeliveries ?? () => Navigator.of(context).maybePop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: _text,
              side: const BorderSide(color: _border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text(
              'Back To Deliveries',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFA99386), fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEADCCC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1E4D7),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: const Color(0xFF561C17), size: 19),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF3B211B),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF987865),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.trim().isEmpty ? 'Not available' : value,
          style: TextStyle(
            color: valueColor ?? const Color(0xFF3B211B),
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  const _PrimaryActionButton({
    required this.text,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF561C17),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon),
        label: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
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
    final Color background = error ? const Color(0xFFFCEBE8) : const Color(0xFFEAF6EE);
    final Color foreground = error ? const Color(0xFFB42318) : const Color(0xFF1B7A46);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: foreground,
          fontSize: 13,
          height: 1.45,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PreviewDetailsNotice extends StatelessWidget {
  const _PreviewDetailsNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EFE7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEADCCC)),
      ),
      child: const Text(
        'Sample delivery details only. Preview actions update this screen locally and are not saved to Laravel.',
        style: TextStyle(
          color: Color(0xFF987865),
          fontSize: 12.5,
          height: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
