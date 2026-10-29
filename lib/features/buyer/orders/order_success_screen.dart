import 'package:flutter/material.dart';

import '../../../shared/widgets/shop_ui.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({
    super.key,
    required this.order,
    required this.onViewOrders,
    required this.onContinueShopping,
  });

  final Map<String, dynamic> order;
  final VoidCallback onViewOrders;
  final VoidCallback onContinueShopping;

  @override
  Widget build(BuildContext context) {
    final String orderNumber = (order['order_number'] ?? '').toString();
    final String status = (order['status'] ?? 'PLACED').toString();
    final double total = double.tryParse(
          (order['grand_total'] ?? 0).toString(),
        ) ??
        0;
    final String amount = formatPesoAmount(total);

    return Scaffold(
      appBar: AppBar(title: const Text('Order placed')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Thanks for your order',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your order is confirmed and saved to your account.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: <Widget>[
                          _OrderValueRow(
                            label: 'Order number',
                            value: orderNumber.isEmpty ? 'Confirmed' : orderNumber,
                          ),
                          const Divider(height: 24),
                          _OrderValueRow(label: 'Status', value: status),
                          const SizedBox(height: 14),
                          _OrderValueRow(
                            label: 'Total',
                            value: amount,
                            strong: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onViewOrders,
                      child: const Text('View my orders'),
                    ),
                  ),
                  TextButton(
                    onPressed: onContinueShopping,
                    child: const Text('Continue shopping'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderValueRow extends StatelessWidget {
  const _OrderValueRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final TextStyle? base = Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: base)),
        Text(
          value,
          style: base?.copyWith(fontWeight: strong ? FontWeight.w800 : null),
        ),
      ],
    );
  }
}
