import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../services/rider_mobile_service.dart';
import '../deliveries/rider_delivery_models.dart';
import 'rider_remittance_models.dart';

class RiderRemittancesScreen extends StatefulWidget {
  final Future<RiderRemittanceSnapshot> Function() load;
  final Future<RiderRemittance> Function({
    required int collectionId,
    required String amount,
    String notes,
  })
  submit;

  const RiderRemittancesScreen({
    super.key,
    this.load = RiderMobileService.fetchRemittances,
    this.submit = RiderMobileService.submitRemittance,
  });

  @override
  State<RiderRemittancesScreen> createState() => _RiderRemittancesScreenState();
}

class _RiderRemittancesScreenState extends State<RiderRemittancesScreen>
    with WidgetsBindingObserver {
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  RiderRemittanceSnapshot? _data;
  int? _selectedId;
  String? _error;
  bool _loading = false;
  bool _submitting = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          ModalRoute.of(context)?.isCurrent == true &&
          !_submitting) {
        unawaited(_refresh());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_submitting) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        if (!data.collections.any((item) => item.id == _selectedId)) {
          _selectedId = null;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = ApiClient.formatError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final id = _selectedId;
    if (_submitting || _loading || id == null) return;
    if (!RiderDeliveryTransitionRequest.isValidCollectedAmount(_amount.text)) {
      _message(
        'Enter the amount handed over, using at most two decimal places.',
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final receipt = await widget.submit(
        collectionId: id,
        amount: _amount.text,
        notes: _notes.text,
      );
      if (!mounted) return;
      // Preserve a confirmed receipt even if the following refresh fails.
      setState(() {
        _data = RiderRemittanceSnapshot(
          available: true,
          collections: _data!.collections
              .where((item) => item.id != id)
              .toList(),
          history: [
            receipt,
            ..._data!.history.where((item) => item.id != receipt.id),
          ],
        );
        _selectedId = null;
        _amount.clear();
        _notes.clear();
      });
      _message(
        'Remittance ${receipt.reference} recorded. Logistics will confirm receipt.',
      );
      await _refresh();
    } catch (error) {
      if (mounted) _message(ApiClient.formatError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final canEdit =
        data?.available == true && !_submitting && !_loading && _error == null;
    return Scaffold(
      backgroundColor: const Color(0xFFFBF7F2),
      appBar: AppBar(title: const Text('Cash remittances')),
      body: RefreshIndicator(
        onRefresh: _submitting ? () async {} : _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const Text(
              'Record the cash you handed to logistics, one parcel at a time. Logistics confirms the amount received.',
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: _submitting || _loading ? null : _refresh,
                child: const Text('Retry'),
              ),
            ],
            if (data != null && !data.available)
              const Text(
                'Cash remittances are currently unavailable. Contact your logistics center.',
              ),
            if (data?.available == true) ...[
              const Text(
                'Available COD collections',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (data!.collections.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No collections are awaiting remittance.'),
                ),
              for (final collection in data.collections)
                Card(
                  child: CheckboxListTile(
                    value: _selectedId == collection.id,
                    onChanged: canEdit
                        ? (selected) => setState(() {
                            _selectedId = selected == true
                                ? collection.id
                                : null;
                            _amount.clear();
                          })
                        : null,
                    title: Text(
                      collection.tracking.isEmpty
                          ? collection.reference
                          : collection.tracking,
                    ),
                    subtitle: Text(
                      'Recorded cash: ${formatRiderMoney(collection.collectedAmount)}',
                    ),
                  ),
                ),
              if (_selectedId != null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _amount,
                  enabled: canEdit,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount handed over (PHP)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  enabled: canEdit,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                FilledButton.icon(
                  onPressed: canEdit ? _submit : null,
                  icon: const Icon(Icons.receipt_long),
                  label: Text(
                    _submitting ? 'Submitting...' : 'Record cash handoff',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Remittance history',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (data.history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No remittances yet.'),
                ),
              for (final receipt in data.history)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receipt.reference,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(receipt.status.replaceAll('_', ' ')),
                        Text(
                          'Expected: ${formatRiderMoney(receipt.expectedAmount)}',
                        ),
                        Text(
                          'Handed over: ${formatRiderMoney(receipt.submittedAmount)}',
                        ),
                        Text(
                          receipt.verifiedAmount == null
                              ? 'Awaiting logistics confirmation'
                              : 'Confirmed: ${formatRiderMoney(receipt.verifiedAmount!)}',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
