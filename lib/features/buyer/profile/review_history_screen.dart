import 'package:flutter/material.dart';

class BuyerReviewHistoryScreen extends StatelessWidget {
  const BuyerReviewHistoryScreen({
    super.key,
    required this.reviews,
    required this.onBack,
    required this.onOpenProduct,
  });

  final List<Map<String, dynamic>> reviews;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenProduct;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My reviews'), leading: IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded))),
      body: reviews.isEmpty
          ? const Center(child: Text('You have not written any product reviews yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> review = reviews[index];
                final String slug = (review['product_slug'] ?? '').toString();
                final int rating = int.tryParse((review['rating'] ?? 0).toString()) ?? 0;
                final String date = (review['created_at'] ?? '').toString();
                return Card(
                  child: ListTile(
                    onTap: slug.isEmpty ? null : () => onOpenProduct(slug),
                    title: Text((review['product_name'] ?? 'Product').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('${'★' * rating}${'☆' * (5 - rating)}  ${date.isEmpty ? '' : date.substring(0, date.length >= 10 ? 10 : date.length)}', style: const TextStyle(color: Color(0xFF9B6B2F))),
                          if ((review['comment'] ?? '').toString().trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 5),
                            Text(review['comment'].toString()),
                          ],
                        ],
                      ),
                    ),
                    trailing: slug.isEmpty ? null : const Icon(Icons.chevron_right_rounded),
                  ),
                );
              },
            ),
    );
  }
}
