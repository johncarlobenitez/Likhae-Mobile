import 'package:flutter/material.dart';

import '../../../services/recently_viewed_service.dart';
import '../../../shared/formatting/money_formatting.dart';
import '../../../shared/widgets/shop_ui.dart';
import '../../../shared/widgets/sized_network_image.dart';
import 'product_details_screen.dart';

class RecentlyViewedScreen extends StatefulWidget {
  final Future<void> Function(ProductDetailData) onProductSelected;
  final VoidCallback onBack;

  const RecentlyViewedScreen({
    super.key,
    required this.onProductSelected,
    required this.onBack,
  });

  @override
  State<RecentlyViewedScreen> createState() => _RecentlyViewedScreenState();
}

class _RecentlyViewedScreenState extends State<RecentlyViewedScreen> {
  late Future<List<ProductDetailData>> _products = RecentlyViewedService.read();

  Future<void> _refresh() async {
    final next = RecentlyViewedService.read();
    setState(() => _products = next);
    try {
      await next;
    } catch (_) {
      /* Render retry below. */
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear recently viewed?'),
        content: const Text('Remove your viewing history for this account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await RecentlyViewedService.clear();
      if (mounted) await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not clear history. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          ShopPageHeader(
            title: 'Recently Viewed',
            subtitle: 'Products you viewed recently.',
            onBack: widget.onBack,
          ),
          Expanded(
            child: FutureBuilder<List<ProductDetailData>>(
            future: _products,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load viewing history.'),
                      TextButton(onPressed: _refresh, child: const Text('Retry')),
                    ],
                  ),
                );
              }
              final products = snapshot.data ?? [];
              if (products.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_outlined, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'No recently viewed products',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Products you open will appear here.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12, top: 4),
                      child: TextButton.icon(
                        onPressed: _clear,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Clear'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: products.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: SizedBox(
                                width: 64,
                                height: 64,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: product.imageUrl == null
                                      ? const Icon(Icons.image_outlined)
                                      : SizedNetworkImage(
                                          url: product.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const Icon(Icons.image_outlined),
                                        ),
                                ),
                              ),
                              title: Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(formatPesoCurrency(product.price)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                await widget.onProductSelected(product);
                                if (mounted) await _refresh();
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
            ),
          ),
        ],
      ),
    ),
  );
}
