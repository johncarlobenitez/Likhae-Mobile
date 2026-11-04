import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../services/workspace_mobile_service.dart';

class SellerOffersScreen extends StatefulWidget {
  const SellerOffersScreen({super.key});
  @override
  State<SellerOffersScreen> createState() => _SellerOffersScreenState();
}

class _SellerOffersScreenState extends State<SellerOffersScreen> {
  late Future<List<Map<String, dynamic>>> _future = WorkspaceMobileService.rows(
    'buyer/offers',
  );
  bool _busy = false;
  String? _message, _error;
  void _reload() =>
      setState(() => _future = WorkspaceMobileService.rows('buyer/offers'));

  Future<void> _claim(Map<String, dynamic> offer) async {
    final rewards = WorkspaceMobileService.maps(offer['rewards']);
    String? rewardVariantId;
    if (offer['type'] != 'BUNDLE') {
      if (rewards.isEmpty) {
        setState(
          () => _error = 'This offer has no available reward variation.',
        );
        return;
      }
      if (rewards.length == 1) {
        rewardVariantId = '${rewards.first['id']}';
      } else {
        rewardVariantId = await showDialog<String>(
          context: context,
          builder: (context) {
            String selected = '${rewards.first['id']}';
            return StatefulBuilder(
              builder: (context, setDialog) => AlertDialog(
                title: const Text('Choose your reward variation'),
                content: DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  items: rewards
                      .map(
                        (reward) => DropdownMenuItem<String>(
                          value: '${reward['id']}',
                          child: Text('${reward['name'] ?? 'Variation'}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialog(() => selected = value ?? selected),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, selected),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            );
          },
        );
        if (!mounted || rewardVariantId == null) return;
      }
    }
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final component in WorkspaceMobileService.maps(offer['components'])) {
      final group = '${component['choice_group'] ?? ''}';
      if (group.isNotEmpty) {
        groups
            .putIfAbsent(group, () => [])
            .add(Map<String, dynamic>.from(component));
      }
    }
    final choices = <String, String>{};
    if (groups.isNotEmpty) {
      final picked = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) {
          final values = <String, String>{
            for (final entry in groups.entries)
              entry.key: '${entry.value.first['variant']?['id'] ?? ''}',
          };
          return StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
              title: const Text('Choose bundle options'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in groups.entries)
                    DropdownButtonFormField<String>(
                      initialValue: values[entry.key],
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Option ${entry.key}',
                      ),
                      items: entry.value
                          .map(
                            (item) => DropdownMenuItem(
                              value: '${item['variant']?['id']}',
                              child: Text(
                                '${item['variant']?['name'] ?? 'Variant'}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialog(
                        () => values[entry.key] = value ?? values[entry.key]!,
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, values),
                  child: const Text('Add to cart'),
                ),
              ],
            ),
          );
        },
      );
      if (picked == null) return;
      choices.addAll(picked);
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final form = FormData()..fields.add(const MapEntry('sets', '1'));
      for (final choice in choices.entries) {
        form.fields.add(MapEntry('choices[${choice.key}]', choice.value));
      }
      final path = offer['type'] == 'BUNDLE'
          ? 'buyer/cart/bundles/${offer['id']}'
          : 'buyer/cart/offers/${offer['id']}/claim';
      if (rewardVariantId != null) {
        form.fields.add(MapEntry('reward_variant_id', rewardVariantId));
      }
      final result = await WorkspaceMobileService.send(path, form);
      setState(
        () => _message =
            result['message']?.toString() ?? 'Offer items added to cart.',
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Seller offers'),
      actions: [
        IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (snapshot.hasError) Text(snapshot.error.toString()),
              if (!snapshot.hasError && (snapshot.data?.isEmpty ?? true))
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No seller offers are available right now.'),
                ),
              if (_message != null)
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_message!),
                  ),
                ),
              if (_error != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!),
                  ),
                ),
              for (final offer
                  in snapshot.data ?? const <Map<String, dynamic>>[])
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${offer['name'] ?? 'Seller offer'} · ${offer['seller'] ?? 'Seller'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          offer['type'] == 'BUNDLE'
                              ? 'Bundle price PHP ${offer['bundle_price'] ?? '—'}'
                              : 'Buy ${offer['buy_quantity'] ?? 1} · Get ${offer['reward_quantity'] ?? 1} · ${offer['reward_discount_percent'] ?? 100}% off',
                        ),
                        for (final item in WorkspaceMobileService.maps(
                          offer['components'],
                        ))
                          Text(
                            '• ${item['quantity'] ?? 1} × ${item['variant']?['name'] ?? 'Bundle item'}',
                          ),
                        if (offer['buy_item'] is Map)
                          Text('Buy item: ${offer['buy_item']['name']}'),
                        for (final reward in WorkspaceMobileService.maps(
                          offer['rewards'],
                        ))
                          Text('Reward: ${reward['name']}'),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed:
                              _busy ||
                                  (offer['type'] != 'BUNDLE' &&
                                      WorkspaceMobileService.maps(
                                        offer['rewards'],
                                      ).isEmpty)
                              ? null
                              : () => _claim(offer),
                          icon: const Icon(Icons.add_shopping_cart),
                          label: Text(_busy ? 'Adding…' : 'Add offer to cart'),
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
