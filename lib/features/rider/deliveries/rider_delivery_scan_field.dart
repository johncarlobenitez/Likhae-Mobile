import 'package:flutter/material.dart';
import '../../../shared/widgets/app_motion.dart';

import '../pickups/rider_pickup_details_screen.dart';
import '../scanner/rider_parcel_scan_result.dart';

/// Captures a real scan or manually entered waybill; never fills in the code
/// from assignment data. Laravel performs the authoritative match on submit.
class RiderDeliveryScanField extends StatefulWidget {
  final String expectedTrackingCode;
  final ValueChanged<RiderParcelScanResult?> onChanged;
  final bool enabled;

  const RiderDeliveryScanField({
    super.key,
    required this.expectedTrackingCode,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<RiderDeliveryScanField> createState() => _RiderDeliveryScanFieldState();
}

class _RiderDeliveryScanFieldState extends State<RiderDeliveryScanField> {
  final _controller = TextEditingController();
  bool _scanning = false;
  String? _error;

  void _accept(String value, String method) {
    final code = value.trim();
    final matches =
        code.isNotEmpty && code == widget.expectedTrackingCode.trim();
    setState(
      () => _error = code.isNotEmpty && !matches
          ? 'This code does not match the assigned parcel.'
          : null,
    );
    widget.onChanged(
      matches ? RiderParcelScanResult(code: code, method: method) : null,
    );
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final result = await Navigator.of(context).push<RiderParcelScanResult>(
        MaterialPageRoute(
          builder: (_) =>
              const RiderParcelScannerScreen(returnScanDetails: true),
        ),
      );
      if (!mounted || result == null) return;
      _controller.text = result.code;
      _accept(result.code, result.method);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _controller,
        enabled: widget.enabled && !_scanning,
        autocorrect: false,
        onChanged: (value) => _accept(value, 'MANUAL'),
        decoration: InputDecoration(
          labelText: 'Parcel tracking code',
          helperText: 'Scan the waybill or enter its code to confirm delivery.',
          helperMaxLines: 2,
          errorText: _error,
          errorMaxLines: 2,
          suffixIcon:
              _controller.text.trim().isNotEmpty &&
                  _controller.text.trim() == widget.expectedTrackingCode.trim()
              ? AppReveal(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    semanticLabel: 'Tracking code matches',
                  ),
                )
              : null,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: widget.enabled && !_scanning ? _scan : null,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan parcel'),
      ),
      if (_controller.text.trim().isNotEmpty &&
          _controller.text.trim() == widget.expectedTrackingCode.trim())
        AppReveal(child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF173A29) : const Color(0xFFEAF6EE),
            borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF48A578), size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text('Parcel matched\nReady to confirm delivery',
              style: TextStyle(color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF6FD19A) : const Color(0xFF1B7A46), fontSize: 12))),
          ]))),
    ],
  );
}
