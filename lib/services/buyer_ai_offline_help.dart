class BuyerAiOfflineAnswer {
  final String reply;
  final List<String> options;

  const BuyerAiOfflineAnswer({required this.reply, this.options = const []});
}

/// Deterministic buyer and rider guidance used when the mobile API is off.
class BuyerAiOfflineHelp {
  BuyerAiOfflineHelp._();

  static BuyerAiOfflineAnswer answer(
    String message, {
    String workspace = 'buyer',
  }) {
    final String question = message.toLowerCase();
    if (workspace == 'rider') {
      if (_containsAny(question, const <String>[
        'payout',
        'earning',
        'payment',
      ])) {
        return const BuyerAiOfflineAnswer(
          reply:
              'Open Earnings in your Rider workspace to review recorded payouts and earnings. Live balances and trip details need an active connection.',
          options: <String>['How do I view my assignments?'],
        );
      }
      if (_containsAny(question, const <String>[
        'assignment',
        'pickup',
        'delivery',
        'trip',
      ])) {
        return const BuyerAiOfflineAnswer(
          reply:
              'Open Assignments in your Rider workspace to review assigned pickups and deliveries. Current assignment status needs an active connection.',
          options: <String>['How do I check my earnings?'],
        );
      }
      return const BuyerAiOfflineAnswer(
        reply:
            'I can help with rider assignments, pickups, deliveries, earnings, and account settings. Ask about one of those topics for guidance.',
        options: <String>[
          'How do I view my assignments?',
          'How do I check my earnings?',
        ],
      );
    }

    if (_containsAny(question, const <String>[
      'track',
      'tracking',
      'delivery',
      'parcel',
      'order status',
    ])) {
      return const BuyerAiOfflineAnswer(
        reply:
            'Open Orders, choose the order, then tap Track Order to see its delivery updates. Current order status is only available when the app is connected to your account.',
        options: <String>['How do I check out?', 'Where are my vouchers?'],
      );
    }
    if (_containsAny(question, const <String>[
      'checkout',
      'check out',
      'place an order',
      'payment',
    ])) {
      return const BuyerAiOfflineAnswer(
        reply:
            'Add products to your cart, open Cart, and continue to checkout. Confirm your delivery address, choose a payment method, review any voucher or discount, then place your order.',
        options: <String>['Where are my vouchers?', 'How do I track my order?'],
      );
    }
    if (_containsAny(question, const <String>[
      'voucher',
      'coupon',
      'discount',
      'rewards',
    ])) {
      return const BuyerAiOfflineAnswer(
        reply:
            'Open Rewards from your Buyer navigation to see available vouchers and points. You can apply eligible vouchers from Cart before checkout.',
        options: <String>['How do I check out?', 'How do I track my order?'],
      );
    }
    if (_containsAny(question, const <String>['cart', 'basket'])) {
      return const BuyerAiOfflineAnswer(
        reply:
            'Open Cart from the Buyer navigation to review products, change quantities, apply eligible vouchers, and continue to checkout.',
        options: <String>['How do I check out?', 'Where are my vouchers?'],
      );
    }
    if (_containsAny(question, const <String>[
      'search',
      'find',
      'product',
      'item',
    ])) {
      return const BuyerAiOfflineAnswer(
        reply:
            'Open Categories or use product search from the Buyer Home page. Select a product to review its details and options, then add it to your cart.',
        options: <String>['How do I check out?', 'Where are my vouchers?'],
      );
    }
    if (_containsAny(question, const <String>['return', 'refund', 'cancel'])) {
      return const BuyerAiOfflineAnswer(
        reply:
            'Open Orders and select the order to review its available return, refund, or cancellation options. Eligibility depends on the order status.',
        options: <String>['How do I track my order?'],
      );
    }
    if (_containsAny(question, const <String>[
      'account',
      'profile',
      'address',
      'password',
    ])) {
      return const BuyerAiOfflineAnswer(
        reply:
            'Open My Account to manage your profile, delivery addresses, password, and account settings.',
        options: <String>['Where are my vouchers?'],
      );
    }
    if (RegExp(r'^\s*(hi|hello|hey)\b').hasMatch(question)) {
      return const BuyerAiOfflineAnswer(
        reply:
            'Hi! I can help with shopping, cart, checkout, orders, delivery, vouchers, returns, and your account. What would you like help with?',
        options: <String>[
          'How do I track my order?',
          'How do I check out?',
          'Where are my vouchers?',
        ],
      );
    }

    return const BuyerAiOfflineAnswer(
      reply:
          'I can help with products, cart, checkout, orders, delivery updates, vouchers, returns, and account settings. For live order details or open-ended AI answers, connect the app to the LIKHAE API.',
      options: <String>[
        'How do I track my order?',
        'How do I check out?',
        'Where are my vouchers?',
      ],
    );
  }

  static bool _containsAny(String value, List<String> terms) =>
      terms.any(value.contains);
}
