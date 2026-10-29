import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../services/buyer_mobile_service.dart';
import '../../../shared/widgets/shop_ui.dart';

class BuyerReturnsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const BuyerReturnsScreen({super.key, this.onBack});

  @override
  State<BuyerReturnsScreen> createState() => _BuyerReturnsScreenState();
}

class _BuyerReturnsScreenState extends State<BuyerReturnsScreen> {
  static const Color _ink = ShopColors.text;
  static const Color _muted = ShopColors.muted;
  static const Color _accent = ShopColors.accent;
  static const Color _border = ShopColors.border;

  List<Map<String, dynamic>> _requests = <Map<String, dynamic>>[];
  Map<String, dynamic>? _detail;
  String? _selectedId;
  String? _error;
  bool _loading = true;
  bool _mutating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? detailId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Map<String, dynamic>> requests =
          await BuyerMobileService.fetchReturnRequests();
      Map<String, dynamic>? detail;
      if (detailId != null) {
        detail = await BuyerMobileService.fetchReturnRequest(detailId);
      }
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _detail = detail;
        _selectedId = detailId;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRequest(Map<String, dynamic> request) async {
    final String id = (request['id'] ?? '').toString();
    if (id.isNotEmpty) await _load(detailId: id);
  }

  Future<void> _confirmRefund(String sellerCaseId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Confirm refund receipt?'),
        content: const Text(
          'Confirm only after the refund has reached your account.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _mutate(() => BuyerMobileService.confirmReturnRefund(sellerCaseId));
  }

  Future<void> _confirmCashRefund(String obligationId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Confirm cash refund received?'),
        content: const Text(
          'Confirm only after you have received the cash refund.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _mutate(
        () => BuyerMobileService.confirmReturnCashRefund(obligationId),
      );
    }
  }

  Future<void> _escalate(String sellerCaseId) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController reason = TextEditingController();
    final TextEditingController explanation = TextEditingController();
    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Escalate to Likhae support'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: reason,
                maxLength: 150,
                decoration: const InputDecoration(labelText: 'Reason'),
                validator: (String? value) =>
                    value == null || value.trim().isEmpty
                    ? 'Enter a reason.'
                    : null,
              ),
              TextFormField(
                controller: explanation,
                minLines: 3,
                maxLines: 5,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Explain the issue',
                ),
                validator: (String? value) => (value?.trim().length ?? 0) < 10
                    ? 'Enter at least 10 characters.'
                    : null,
              ),
              const Text(
                'Support will review the case and contact you through your account.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              formKey.currentState?.validate() == true,
            ),
            child: const Text('Escalate'),
          ),
        ],
      ),
    );
    if (submit == true) {
      await _mutate(
        () => BuyerMobileService.escalateReturnRefund(
          sellerCaseId: sellerCaseId,
          reason: reason.text.trim(),
          explanation: explanation.text.trim(),
        ),
      );
    }
    reason.dispose();
    explanation.dispose();
  }

  Future<void> _mutate(Future<void> Function() action) async {
    setState(() => _mutating = true);
    try {
      await action();
      final String? id = _selectedId;
      await _load(detailId: id);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Return case updated.')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _viewPrivateFile({
    required String title,
    required String mimeType,
    required Future<Uint8List> Function() load,
  }) async {
    try {
      final Uint8List bytes = await load();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (mimeType.toLowerCase().startsWith('image/'))
                  Flexible(
                    child: InteractiveViewer(
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  )
                else
                  Text(
                    'Private file loaded (${mimeType.isEmpty ? 'file' : mimeType}, ${bytes.length} bytes). Preview is not available for this file type.',
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to open file: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showingDetail = _selectedId != null;
    return Scaffold(
      backgroundColor: ShopColors.canvas,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            ShopPageHeader(
              title: showingDetail ? 'Return case' : 'Returns & Refunds',
              subtitle: showingDetail
                  ? 'Request status and seller updates'
                  : 'Follow your requests and refund decisions',
              onBack: showingDetail ? () => _load() : widget.onBack,
            ),
            Expanded(
              child: RefreshIndicator(
                color: _accent,
                onRefresh: () => _load(detailId: _selectedId),
                child: _loading && _requests.isEmpty
                    ? ListView(
                        children: const <Widget>[
                          SizedBox(height: 250),
                          Center(child: CircularProgressIndicator()),
                        ],
                      )
                    : _error != null && _requests.isEmpty
                    ? ListView(
                        children: <Widget>[
                          SizedBox(height: 180),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(_error!, textAlign: TextAlign.center),
                            ),
                          ),
                        ],
                      )
                    : showingDetail
                    ? _buildDetail()
                    : _buildList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_requests.isEmpty) {
      return ListView(
        children: const <Widget>[
          SizedBox(height: 110),
          Icon(Icons.assignment_return_outlined, size: 54, color: _muted),
          SizedBox(height: 12),
          Center(
            child: Text(
              'No return or refund requests yet',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: _requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> row = _requests[index];
        final List<Map<String, dynamic>> cases = _maps(row['seller_cases']);
        final String updatedAt =
            (row['updated_at'] ?? row['submitted_at'] ?? '').toString();
        return Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: _border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openRequest(row),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          (row['request_number'] ?? 'Return request')
                              .toString(),
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _statusChip(row['status']),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Order ${row['order_number'] ?? row['order_id'] ?? '—'} · ${(row['issue_category'] ?? '').toString().replaceAll('_', ' ')}',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  if (updatedAt.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 5),
                    Text(
                      'Last updated $updatedAt',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                  if (cases.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      '${cases.length} seller case${cases.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetail() {
    final Map<String, dynamic>? detail = _detail;
    if (detail == null)
      return ListView(
        children: <Widget>[
          const SizedBox(height: 120),
          Center(child: Text(_error ?? 'Loading request…')),
        ],
      );
    final Map<String, dynamic> order = detail['order'] is Map
        ? Map<String, dynamic>.from(detail['order'] as Map)
        : <String, dynamic>{};
    final List<Map<String, dynamic>> items = _maps(detail['items']);
    final List<Map<String, dynamic>> events = _maps(detail['events']);
    final List<Map<String, dynamic>> cases = _maps(detail['seller_cases']);
    final List<Map<String, dynamic>> evidence = _maps(detail['evidence']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      children: <Widget>[
        _sectionCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      (detail['request_number'] ?? 'Return request').toString(),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _statusChip(detail['status']),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Order ${order['order_number'] ?? order['id'] ?? '—'}',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 8),
              Text(
                '${detail['issue_category'] ?? ''} · ${detail['issue_reason'] ?? ''}',
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if ((detail['description'] ?? '')
                  .toString()
                  .isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  detail['description'].toString(),
                  style: const TextStyle(color: _muted, height: 1.4),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Refund amount requested: ₱${detail['refundable_amount'] ?? 0}',
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if ((detail['refund_method'] ??
                detail['requested_refund_method'] ??
                '')
            .toString()
            .trim()
            .isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _sectionCard(
            Text(
              'Refund method: ${(detail['refund_method'] ?? detail['requested_refund_method']).toString().replaceAll('_', ' ')}',
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (items.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _sectionCard(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Affected items',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
                ),
                for (final Map<String, dynamic> item in items)
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Text(
                      '${item['quantity'] ?? 0} × ${item['product_name'] ?? 'Item'} · ₱${item['amount'] ?? 0}',
                      style: const TextStyle(color: _muted, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (evidence.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _sectionCard(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Submitted evidence',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: evidence.map((Map<String, dynamic> file) {
                    final String id = (file['id'] ?? '').toString();
                    final String name = (file['name'] ?? 'Evidence file')
                        .toString();
                    final String mime = (file['mime_type'] ?? '').toString();
                    return ActionChip(
                      avatar: const Icon(Icons.attach_file_rounded, size: 17),
                      label: Text(name, overflow: TextOverflow.ellipsis),
                      onPressed: id.isEmpty
                          ? null
                          : () => _viewPrivateFile(
                              title: name,
                              mimeType: mime,
                              load: () =>
                                  BuyerMobileService.fetchReturnEvidence(id),
                            ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
        if (cases.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          for (final Map<String, dynamic> sellerCase in cases)
            _buildSellerCase(sellerCase),
        ],
        const SizedBox(height: 12),
        _sectionCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Request timeline',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
              ),
              if (events.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'No updates yet.',
                    style: TextStyle(color: _muted),
                  ),
                ),
              for (final Map<String, dynamic> event in events)
                Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.circle, size: 8, color: _accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              (event['event'] ?? '').toString().replaceAll(
                                '_',
                                ' ',
                              ),
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if ((event['note'] ?? '').toString().isNotEmpty)
                              Text(
                                event['note'].toString(),
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                ),
                              ),
                            Text(
                              (event['created_at'] ?? '').toString(),
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_mutating)
          const Padding(
            padding: EdgeInsets.all(14),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildSellerCase(Map<String, dynamic> sellerCase) {
    final String id = (sellerCase['id'] ?? '').toString();
    final List<Map<String, dynamic>> caseEvents = _maps(sellerCase['events']);
    final List<Map<String, dynamic>> payouts = _maps(sellerCase['payouts']);
    final List<Map<String, dynamic>> caseEvidence = _maps(
      sellerCase['evidence'],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _sectionCard(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    (sellerCase['seller_name'] ?? 'Seller').toString(),
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _statusChip(sellerCase['status']),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'Requested ₱${sellerCase['requested_amount'] ?? 0} · Approved ₱${sellerCase['approved_amount'] ?? '—'}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            if (caseEvidence.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              const Text(
                'Seller evidence',
                style: TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Wrap(
                spacing: 8,
                children: caseEvidence.map((Map<String, dynamic> file) {
                  final String evidenceId = (file['id'] ?? '').toString();
                  final String name = (file['name'] ?? 'Evidence').toString();
                  return ActionChip(
                    avatar: const Icon(Icons.attachment_rounded, size: 16),
                    label: Text(name),
                    onPressed: evidenceId.isEmpty
                        ? null
                        : () => _viewPrivateFile(
                            title: name,
                            mimeType: (file['mime_type'] ?? '').toString(),
                            load: () => BuyerMobileService.fetchReturnEvidence(
                              evidenceId,
                            ),
                          ),
                  );
                }).toList(),
              ),
            ],
            if (caseEvents.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              const Text(
                'Seller case updates',
                style: TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final Map<String, dynamic> event in caseEvents)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    '${(event['event'] ?? '').toString().replaceAll('_', ' ')}${(event['note'] ?? '').toString().isEmpty ? '' : ': ${event['note']}'}',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ),
            ],
            for (final Map<String, dynamic> payout in payouts)
              if (payout['proof_available'] == true && payout['id'] != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _mutating
                        ? null
                        : () => _viewPrivateFile(
                            title: 'Refund payout proof',
                            mimeType: (payout['proof_mime'] ?? 'image/webp')
                                .toString(),
                            load: () =>
                                BuyerMobileService.fetchReturnPayoutProof(
                                  payout['id'].toString(),
                                ),
                          ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(
                      'View payout proof - PHP ${payout['amount_sent'] ?? '—'}',
                    ),
                  ),
                ),
            if (sellerCase['can_confirm_refund'] == true ||
                sellerCase['can_confirm_cash_refund'] == true ||
                sellerCase['can_escalate'] == true) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  if (sellerCase['can_confirm_refund'] == true)
                    OutlinedButton(
                      onPressed: _mutating ? null : () => _confirmRefund(id),
                      child: const Text('Confirm refund received'),
                    ),
                  if (sellerCase['can_confirm_cash_refund'] == true &&
                      sellerCase['cash_refund_obligation_id'] != null)
                    OutlinedButton(
                      onPressed: _mutating
                          ? null
                          : () => _confirmCashRefund(
                              sellerCase['cash_refund_obligation_id']
                                  .toString(),
                            ),
                      child: const Text('Confirm cash received'),
                    ),
                  if (sellerCase['can_escalate'] == true)
                    TextButton(
                      onPressed: _mutating ? null : () => _escalate(id),
                      child: const Text('Escalate to support'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(Widget child) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  Widget _statusChip(dynamic raw) {
    final String status = (raw ?? 'pending')
        .toString()
        .replaceAll('_', ' ')
        .toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF7EDE8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: _accent,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((Map row) => Map<String, dynamic>.from(row))
            .toList(growable: false)
      : <Map<String, dynamic>>[];
}
