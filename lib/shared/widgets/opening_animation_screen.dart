import 'dart:async';
import 'dart:ui' show PathMetric;
import 'motion_timeline.dart';
import 'package:flutter/material.dart';
import '../../features/buyer/home/home_screen.dart';
import '../../features/buyer/wishlist/wishlist_screen.dart';
import '../../features/buyer/cart/cart_screen.dart';
import '../../features/buyer/orders/order_success_screen.dart';
import '../../features/buyer/orders/order_tracking_screen.dart';
import '../../features/buyer/orders/orders_screen.dart';
import '../../features/rider/deliveries/rider_delivery_details_screen.dart';
import '../../features/rider/deliveries/rider_delivery_models.dart';
import 'app_motion.dart';
import 'glass_navigation.dart';

/// Finite, read-only tour. Only the visible production screen is mounted.
class OpeningAnimationScreen extends StatefulWidget {
  const OpeningAnimationScreen({super.key, required this.onFinished});
  final VoidCallback onFinished;
  @override
  State<OpeningAnimationScreen> createState() => _OpeningAnimationScreenState();
}

class _OpeningAnimationScreenState extends State<OpeningAnimationScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock;
  Timer? _deadline;
  final _homeScroll = ScrollController();
  int _stage = 0;
  bool _finished = false;
  static const _ends = [0.18, 0.34, 0.43, 0.52, 0.65, 0.80, 0.89, 1.0];
  static const _labels = [
    'Welcome',
    'Discover',
    'Wishlist',
    'Cart',
    'Order confirmation',
    'Tracking',
    'Delivery',
    'LIKHAE',
  ];
  static void _noop() {}

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    )..addListener(_tick);
    // Navigation never relies on a painter, image, or ticker completing.
    _deadline = Timer(const Duration(seconds: 8), _finish);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (appReduceMotion(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    } else if (!TickerMode.valuesOf(context).enabled) {
      _clock.stop();
    } else if (!_finished &&
        !_clock.isAnimating &&
        TickerMode.valuesOf(context).enabled &&
        (WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed)) {
      _clock.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _clock.stop();
    } else if (!_finished) {
      _clock.forward();
    }
  }

  void _tick() {
    if (_clock.isCompleted) {
      _finish();
      return;
    }
    final next = _ends.indexWhere((end) => _clock.value < end);
    if (next >= 0 && next != _stage) setState(() => _stage = next);
    if (_stage == 1 && _homeScroll.hasClients) {
      final progress = ((_clock.value - 0.21) / 0.12).clamp(0.0, 1.0);
      _homeScroll.jumpTo(
        (900 * Curves.easeInOut.transform(progress)).clamp(
          0.0,
          _homeScroll.position.maxScrollExtent,
        ),
      );
    }
  }

  void _finish() {
    if (!mounted || _finished) return;
    _deadline?.cancel();
    _clock.stop();
    setState(() => _finished = true);
    widget.onFinished();
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _clock.dispose();
    _homeScroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static const _products = [
    BuyerHomeProduct(
      id: 1,
      name: 'Minimal Ceramic Vase',
      price: 799,
      originalPrice: 999,
      category: 'Home Decor',
      sellerName: 'Mira Studio',
      imageUrl: 'assets/opening/vase.jpg',
      rating: 4.8,
      stock: 8,
      soldCount: 182,
      isFeatured: true,
      isRecommended: true,
    ),
    BuyerHomeProduct(
      id: 3,
      name: 'Wireless Noise Cancelling Headphones',
      price: 5399,
      category: 'Electronics',
      sellerName: 'Echo Labs',
      imageUrl: 'assets/opening/headphones.jpg',
      rating: 4.9,
      stock: 15,
      soldCount: 96,
      isRecommended: true,
    ),
  ];

  Widget _page() => switch (_stage) {
    0 => const Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: AppOpeningContent(),
      ),
    ),
    1 => GlassNavigationFrame(
      navigation: GlassNavigationBar(
        currentIndex: 0,
        destinations: [
          for (final item in const [
            (Icons.home_outlined, 'Home'),
            (Icons.chat_bubble_outline, 'Messages'),
            (Icons.receipt_long_outlined, 'Orders'),
            (Icons.person_outline, 'Account'),
          ])
            GlassNavigationDestination(
              icon: item.$1,
              selectedIcon: item.$1,
              label: item.$2,
              onTap: _noop,
            ),
        ],
      ),
      child: BuyerHomeScreen(
        scrollController: _homeScroll,
        localPreview: true,
        products: _products,
        featuredProducts: _products,
        recommendedProducts: _products,
        heroProduct: _products[0],
      ),
    ),
    2 => const WishlistScreen(
      products: [
        WishlistProduct(
          id: 1,
          name: 'Minimal Ceramic Vase',
          price: 799,
          category: 'Home Decor',
          sellerName: 'Mira Studio',
          imageUrl: 'assets/opening/vase.jpg',
          stock: 8,
        ),
      ],
    ),
    3 => const CartScreen(
      items: [
        CartItemData(
          id: 'preview',
          name: 'Minimal Ceramic Vase',
          category: 'Home Decor',
          variant: 'Standard',
          seller: 'Mira Studio',
          price: 799,
          quantity: 1,
          stock: 8,
          imageUrl: 'assets/opening/vase.jpg',
        ),
      ],
    ),
    4 => const OrderSuccessScreen(
      order: {
        'order_number': 'DEMO-001',
        'status': 'PLACED',
        'grand_total': 799,
      },
      onViewOrders: _noop,
      onContinueShopping: _noop,
    ),
    5 => OrderTrackingScreen(
      order: const BuyerOrderData(
        id: 'preview',
        status: 'to-receive',
        statusLabel: 'Out for delivery',
        payment: 'Cash',
        products: [],
        total: 799,
        buyerName: 'Preview customer',
        shippingAddress: 'Pila, Laguna',
        tracking: 'DEMO-001',
        isPreview: true,
      ),
      previewMap: RepaintBoundary(
        child: CustomPaint(
          painter: _RoutePreview(
            _clock.drive(
              CurveTween(
                curve: const Interval(.65, .80, curve: Curves.easeInOut),
              ),
            ),
            Theme.of(context).colorScheme,
          ),
        ),
      ),
    ),
    6 => const RiderDeliveryDetailsScreen(
      delivery: RiderDeliveryData(
        id: 0,
        trackingCode: 'DEMO-001',
        buyerName: 'Preview customer',
        contact: '',
        address: 'Pila, Laguna',
        amount: 799,
        status: 'out_for_delivery',
        statusLabel: 'Out For Delivery',
        isPreview: true,
      ),
    ),
    _ => const Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: AppOpeningContent(closing: true),
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final brand = _stage == 0 || _stage == 7;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(painter: _OpeningBackdrop(colors)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: 'LIKHAE preview: ${_labels[_stage]}',
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: brand || _finished
                                ? const SizedBox(height: 48)
                                : Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primaryContainer,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Text(
                                      _stage == 5
                                          ? 'TRACKING'
                                          : _stage == 6
                                          ? 'RIDER'
                                          : 'BUYER',
                                      style: TextStyle(
                                        fontSize: 10,
                                        letterSpacing: 1,
                                        fontWeight: FontWeight.w700,
                                        color: colors.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      if (!_finished)
                        TextButton(
                          onPressed: _finish,
                          child: const Text('Skip'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _finished
                      ? const Center(child: Text('Getting things ready…'))
                      : ExcludeSemantics(
                          child: IgnorePointer(
                            child: _StageEntrance(
                              key: ValueKey(_stage),
                              child: brand
                                  ? _page()
                                  : Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        0,
                                        12,
                                        18,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.contain,
                                        child: SizedBox(
                                          width: 430,
                                          height: 820,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            child: MediaQuery(
                                              data: MediaQuery.of(context)
                                                  .copyWith(
                                                    size: const Size(430, 820),
                                                  ),
                                              child: _page(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StageEntrance extends StatelessWidget {
  const _StageEntrance({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => AppMotionTimeline(
    duration: const Duration(milliseconds: 240),
    builder: (context, progress) {
      final ease = progress.drive(CurveTween(curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: ease,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .045),
            end: Offset.zero,
          ).animate(ease),
          child: child,
        ),
      );
    },
  );
}

class _OpeningBackdrop extends CustomPainter {
  const _OpeningBackdrop(this.colors);
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = colors.surfaceContainerHighest.withValues(alpha: .45);
    canvas.drawCircle(Offset(0, size.height * .17), size.width * .3, fill);
    canvas.drawCircle(
      Offset(size.width, size.height * .89),
      size.width * .32,
      fill,
    );
    canvas.drawCircle(
      Offset(size.width * .88, size.height * .12),
      size.width * .17,
      Paint()
        ..color = colors.outline.withValues(alpha: .6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _OpeningBackdrop old) => old.colors != colors;
}

// Only the live map surface is substituted; the tracking UI is production UI.
class _RoutePreview extends CustomPainter {
  _RoutePreview(this.progress, this.colors) : super(repaint: progress);
  final Animation<double> progress;
  final ColorScheme colors;
  Size? _size;
  final Path _route = Path();
  PathMetric? _metric;
  final Paint _paint = Paint();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(colors.surfaceContainerHighest, BlendMode.src);
    _paint
      ..color = colors.surface
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < 5; i++) {
      final x = size.width * i / 5, y = size.height * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x - 35, size.height), _paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 20), _paint);
    }
    final start = Offset(size.width * .16, size.height * .78);
    final end = Offset(size.width * .84, size.height * .2);
    if (_size != size) {
      _size = size;
      _route
        ..reset()
        ..moveTo(start.dx, start.dy)
        ..lineTo(size.width * .38, size.height * .52)
        ..lineTo(size.width * .57, size.height * .45)
        ..lineTo(end.dx, end.dy);
      _metric = _route.computeMetrics().first;
    }
    canvas.drawPath(
      _route,
      _paint
        ..color = colors.outline
        ..strokeWidth = 5,
    );
    canvas.drawPath(
      _metric!.extractPath(0, _metric!.length * progress.value),
      _paint
        ..color = colors.secondary
        ..strokeWidth = 5,
    );
    _paint
      ..style = PaintingStyle.fill
      ..color = colors.primary;
    canvas.drawCircle(end, 7, _paint);
    final rider = _metric!
        .getTangentForOffset(_metric!.length * progress.value)!
        .position;
    canvas.drawCircle(rider, 11, _paint);
    canvas.drawCircle(rider, 4, _paint..color = colors.onPrimary);
  }

  @override
  bool shouldRepaint(covariant _RoutePreview old) =>
      old.progress != progress || old.colors != colors;
}
