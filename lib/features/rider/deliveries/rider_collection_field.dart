import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/formatting/money_formatting.dart';

class RiderCollectionField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  const RiderCollectionField({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: const <TextInputFormatter>[MonetaryAmountInputFormatter()],
    decoration: const InputDecoration(
      labelText: 'Actual cash collected (₱)',
      hintText: '0.00',
      helperText: 'Enter the cash received from the buyer. Enter 0 if none.',
      helperMaxLines: 2,
      prefixIcon: Icon(Icons.payments_outlined),
      border: OutlineInputBorder(),
    ),
  );
}
