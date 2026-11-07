import 'package:flutter/material.dart';

import '../../../services/buyer_mobile_service.dart';
import '../../../services/product_service.dart';

class PlatformEventsScreen extends StatefulWidget {
  const PlatformEventsScreen({super.key});

  @override
  State<PlatformEventsScreen> createState() => _PlatformEventsScreenState();
}

class _PlatformEventsScreenState extends State<PlatformEventsScreen> {
  late Future<List<Map<String, dynamic>>> _events =
      ProductService.fetchPlatformEvents();
  final Set<int> _claimed = <int>{};
  final Set<int> _claiming = <int>{};

  Future<void> _refresh() async {
    final Future<List<Map<String, dynamic>>> next =
        ProductService.fetchPlatformEvents();
    setState(() => _events = next);
    try {
      await next;
    } catch (_) {
      // FutureBuilder presents the load error in the event list.
    }
  }

  Future<void> _showDetails(Map<String, dynamic> event) async {
    final int? id = int.tryParse((event['id'] ?? '').toString());
    if (id == null) return;

    late final Map<String, dynamic> details;
    try {
      details = await BuyerMobileService.fetchPlatformEvent(id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
      return;
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheetState) {
          final bool isClaimed =
              details['claimed'] == true || _claimed.contains(id);
          final bool canClaim = (event['status'] ?? '').toString() == 'active';
          final String discountType =
              (details['discount_type'] ?? event['discount_type'] ?? '')
                  .toString()
                  .toUpperCase();
          final double discount =
              double.tryParse(
                (details['discount_value'] ?? event['discount_value'] ?? 0)
                    .toString(),
              ) ??
              0;
          final String discountLabel = discountType == 'PERCENT'
              ? '${discount.toStringAsFixed(0)}% off'
              : '₱${discount.toStringAsFixed(2)} off';

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'PLATFORM EVENT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (details['title'] ?? event['title'] ?? 'Platform event')
                        .toString(),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${details['code'] ?? event['code'] ?? ''} · $discountLabel',
                  ),
                  if (event['body'] != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(event['body'].toString()),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Valid ${_date(details['starts_at'] ?? event['starts_at'])} – ${_date(details['ends_at'] ?? event['ends_at'])}',
                  ),
                  if (event['minimum_order_amount'] != null &&
                      double.tryParse(
                            event['minimum_order_amount'].toString(),
                          ) !=
                          0) ...<Widget>[
                    const SizedBox(height: 6),
                    Text('Minimum order ₱${event['minimum_order_amount']}.'),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          !canClaim || isClaimed || _claiming.contains(id)
                          ? null
                          : () async {
                              setSheetState(() => _claiming.add(id));
                              try {
                                await BuyerMobileService.claimVoucher(id);
                                _claimed.add(id);
                                details['claimed'] = true;
                                if (mounted) setState(() {});
                                if (sheetContext.mounted) setSheetState(() {});
                              } catch (error) {
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        error.toString().replaceFirst(
                                          'Exception: ',
                                          '',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              } finally {
                                _claiming.remove(id);
                                if (sheetContext.mounted) setSheetState(() {});
                              }
                            },
                      icon: Icon(
                        isClaimed
                            ? Icons.check_circle_outline
                            : Icons.card_giftcard_outlined,
                      ),
                      label: Text(
                        isClaimed
                            ? 'Added to Rewards'
                            : _claiming.contains(id)
                            ? 'Collecting…'
                            : canClaim
                            ? 'Collect voucher'
                            : 'Not available yet',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _date(dynamic value) {
    final DateTime? date = DateTime.tryParse((value ?? '').toString());
    if (date == null) return 'date unavailable';
    final DateTime local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Platform events'),
      actions: <Widget>[
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _events,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final List<Map<String, dynamic>> events =
                snapshot.data ?? const <Map<String, dynamic>>[];
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  if (snapshot.hasError)
                    Text('Unable to load platform events: ${snapshot.error}'),
                  if (!snapshot.hasError && events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          'No platform events are available right now.',
                        ),
                      ),
                    ),
                  for (final Map<String, dynamic> event in events)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    (event['title'] ?? 'Platform event')
                                        .toString(),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    (event['status'] ?? 'available').toString(),
                                  ),
                                ),
                              ],
                            ),
                            if (event['body'] != null)
                              Text(event['body'].toString()),
                            const SizedBox(height: 8),
                            Text(
                              'Valid ${_date(event['starts_at'])} – ${_date(event['ends_at'])}',
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _showDetails(event),
                                icon: const Icon(Icons.arrow_forward_rounded),
                                label: const Text('View event'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
    ),
  );
}
