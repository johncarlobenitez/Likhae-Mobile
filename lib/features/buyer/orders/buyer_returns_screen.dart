import 'package:likhae/core/theme/app_theme.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
              Text(
                'Support will review the case and contact you through your account.',
                style: TextStyle(
                  color: AppTheme.resolve(context, _muted),
                  fontSize: 12,
                ),
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

  Future<void> _createReturnWaybill(String sellerCaseId) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      final Map<String, dynamic> waybill =
          await BuyerMobileService.createReturnWaybill(sellerCaseId);
      final String? requestId = _selectedId;
      if (requestId != null) await _load(detailId: requestId);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => BuyerReturnWaybillPreviewScreen(waybill: waybill),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Could not create return waybill: $error')),
          );
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _viewReturnWaybill(String sellerCaseId) async {
    try {
      final Map<String, dynamic> waybill =
          await BuyerMobileService.fetchReturnWaybill(sellerCaseId);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => BuyerReturnWaybillPreviewScreen(waybill: waybill),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Could not open return waybill: $error')),
          );
      }
    }
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
      backgroundColor: AppTheme.resolve(context, ShopColors.canvas, fill: true),
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
                color: AppTheme.resolve(context, _accent),
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
        children: <Widget>[
          SizedBox(height: 110),
          Icon(
            Icons.assignment_return_outlined,
            size: 54,
            color: AppTheme.resolve(context, _muted),
          ),
          SizedBox(height: 12),
          Center(
            child: Text(
              'No return or refund requests yet',
              style: TextStyle(
                color: AppTheme.resolve(context, _ink),
                fontWeight: FontWeight.w700,
              ),
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
          color: AppTheme.resolve(context, Colors.white, fill: true),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: AppTheme.resolve(context, _border)),
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
                          style: TextStyle(
                            color: AppTheme.resolve(context, _ink),
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
                    style: TextStyle(
                      color: AppTheme.resolve(context, _muted),
                      fontSize: 12,
                    ),
                  ),
                  if (updatedAt.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 5),
                    Text(
                      'Last updated $updatedAt',
                      style: TextStyle(
                        color: AppTheme.resolve(context, _muted),
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (cases.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      '${cases.length} seller case${cases.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: AppTheme.resolve(context, _accent),
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
                      style: TextStyle(
                        color: AppTheme.resolve(context, _ink),
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
                style: TextStyle(color: AppTheme.resolve(context, _muted)),
              ),
              const SizedBox(height: 8),
              Text(
                '${detail['issue_category'] ?? ''} · ${detail['issue_reason'] ?? ''}',
                style: TextStyle(
                  color: AppTheme.resolve(context, _ink),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if ((detail['description'] ?? '')
                  .toString()
                  .isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  detail['description'].toString(),
                  style: TextStyle(
                    color: AppTheme.resolve(context, _muted),
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Refund amount requested: ${formatPesoValue(detail['refundable_amount'])}',
                style: TextStyle(
                  color: AppTheme.resolve(context, _ink),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if ((detail['refund_method'] ?? detail['requested_refund_method'] ?? '')
            .toString()
            .trim()
            .isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _sectionCard(
            Text(
              'Refund method: ${(detail['refund_method'] ?? detail['requested_refund_method']).toString().replaceAll('_', ' ')}',
              style: TextStyle(
                color: AppTheme.resolve(context, _ink),
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
                Text(
                  'Affected items',
                  style: TextStyle(
                    color: AppTheme.resolve(context, _ink),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                for (final Map<String, dynamic> item in items)
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Text(
                      '${item['quantity'] ?? 0} × ${item['product_name'] ?? 'Item'} · ${formatPesoValue(item['amount'])}',
                      style: TextStyle(
                        color: AppTheme.resolve(context, _muted),
                        fontSize: 13,
                      ),
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
                Text(
                  'Submitted evidence',
                  style: TextStyle(
                    color: AppTheme.resolve(context, _ink),
                    fontWeight: FontWeight.w800,
                  ),
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
              Text(
                'Request timeline',
                style: TextStyle(
                  color: AppTheme.resolve(context, _ink),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (events.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'No updates yet.',
                    style: TextStyle(color: AppTheme.resolve(context, _muted)),
                  ),
                ),
              for (final Map<String, dynamic> event in events)
                Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: AppTheme.resolve(context, _accent),
                      ),
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
                              style: TextStyle(
                                color: AppTheme.resolve(context, _ink),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if ((event['note'] ?? '').toString().isNotEmpty)
                              Text(
                                event['note'].toString(),
                                style: TextStyle(
                                  color: AppTheme.resolve(context, _muted),
                                  fontSize: 12,
                                ),
                              ),
                            Text(
                              (event['created_at'] ?? '').toString(),
                              style: TextStyle(
                                color: AppTheme.resolve(context, _muted),
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
    final Map<String, dynamic>? waybill = sellerCase['return_waybill'] is Map
        ? Map<String, dynamic>.from(sellerCase['return_waybill'] as Map)
        : null;
    final String waybillTracking = (waybill?['tracking_number'] ?? '')
        .toString();
    final bool canCreateWaybill =
        sellerCase['can_create_return_waybill'] == true;
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
                    style: TextStyle(
                      color: AppTheme.resolve(context, _ink),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _statusChip(sellerCase['status']),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'Requested ${formatPesoValue(sellerCase['requested_amount'])} · Approved ${formatPesoValue(sellerCase['approved_amount'])}',
              style: TextStyle(
                color: AppTheme.resolve(context, _muted),
                fontSize: 12,
              ),
            ),
            if (canCreateWaybill || waybillTracking.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.resolve(
                    context,
                    const Color(0xFFFFF8F0),
                    fill: true,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Return waybill',
                      style: TextStyle(
                        color: AppTheme.resolve(context, _ink),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (waybillTracking.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 5),
                      Text(
                        waybillTracking,
                        style: TextStyle(
                          color: AppTheme.resolve(context, _accent),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                      if ((waybill?['dropoff_center_name'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty)
                        Text(
                          'Drop off at ${waybill!['dropoff_center_name']}',
                          style: TextStyle(
                            color: AppTheme.resolve(context, _muted),
                            fontSize: 12,
                          ),
                        ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        if (canCreateWaybill)
                          OutlinedButton.icon(
                            onPressed: _mutating || id.isEmpty
                                ? null
                                : () => _createReturnWaybill(id),
                            icon: const Icon(Icons.add_box_outlined),
                            label: const Text('Create waybill'),
                          ),
                        if (waybillTracking.isNotEmpty)
                          FilledButton.icon(
                            onPressed: _mutating || id.isEmpty
                                ? null
                                : () => _viewReturnWaybill(id),
                            icon: const Icon(Icons.local_print_shop_outlined),
                            label: const Text('View / print'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (caseEvidence.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Seller evidence',
                style: TextStyle(
                  color: AppTheme.resolve(context, _ink),
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
              Text(
                'Seller case updates',
                style: TextStyle(
                  color: AppTheme.resolve(context, _ink),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final Map<String, dynamic> event in caseEvents)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    '${(event['event'] ?? '').toString().replaceAll('_', ' ')}${(event['note'] ?? '').toString().isEmpty ? '' : ': ${event['note']}'}',
                    style: TextStyle(
                      color: AppTheme.resolve(context, _muted),
                      fontSize: 11,
                    ),
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
                      'View payout proof - ${formatPesoValue(payout['amount_sent'])}',
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
      color: AppTheme.resolve(context, Colors.white, fill: true),
      border: Border.all(color: AppTheme.resolve(context, _border)),
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
        color: AppTheme.resolve(context, const Color(0xFFF7EDE8), fill: true),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: AppTheme.resolve(context, _accent),
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

class BuyerReturnWaybillPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> waybill;

  const BuyerReturnWaybillPreviewScreen({super.key, required this.waybill});

  @override
  Widget build(BuildContext context) {
    final String trackingNumber =
        (waybill['tracking_number'] ?? 'return-waybill').toString();
    return Scaffold(
      appBar: AppBar(title: const Text('Return waybill')),
      body: PdfPreview(
        build: (PdfPageFormat format) =>
            _buildBuyerReturnWaybillPdf(waybill, format),
        pdfFileName: '$trackingNumber.pdf',
        canChangeOrientation: false,
        canChangePageFormat: false,
        pageFormats: const <String, PdfPageFormat>{'A4': PdfPageFormat.a4},
        onError: (BuildContext context, Object error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Unable to prepare this waybill: $error'),
          ),
        ),
      ),
    );
  }
}

Future<Uint8List> _buildBuyerReturnWaybillPdf(
  Map<String, dynamic> waybill,
  PdfPageFormat format,
) async {
  final pw.Document document = pw.Document();
  final String tracking = (waybill['tracking_number'] ?? '').toString();
  final String sellerOrder = (waybill['seller_order_number'] ?? '').toString();
  final Map<String, dynamic> returnFrom = waybill['return_from'] is Map
      ? Map<String, dynamic>.from(waybill['return_from'] as Map)
      : <String, dynamic>{};
  final Map<String, dynamic> returnTo = waybill['return_to'] is Map
      ? Map<String, dynamic>.from(waybill['return_to'] as Map)
      : <String, dynamic>{};
  final Map<String, dynamic> dropoff = waybill['dropoff_center'] is Map
      ? Map<String, dynamic>.from(waybill['dropoff_center'] as Map)
      : <String, dynamic>{};
  final List<Map<String, dynamic>> items = waybill['items'] is List
      ? (waybill['items'] as List)
            .whereType<Map>()
            .map((Map row) => Map<String, dynamic>.from(row))
            .toList(growable: false)
      : <Map<String, dynamic>>[];

  String value(Map<String, dynamic> data, String key) {
    final String text = (data[key] ?? '').toString().trim();
    return text.isEmpty ? 'Not provided' : text;
  }

  pw.Widget addressPanel(String title, String name, String address) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey500),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text(name),
            pw.SizedBox(height: 3),
            pw.Text(address, style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      );

  document.addPage(
    pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(28),
      build: (pw.Context context) => pw.Container(
        padding: const pw.EdgeInsets.all(18),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey800, width: 1.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: <pw.Widget>[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(
                      'LIKHAE',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text('Buyer Return Waybill'),
                  ],
                ),
                if (sellerOrder.isNotEmpty)
                  pw.Text('Order $sellerOrder', textAlign: pw.TextAlign.right),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: tracking,
                width: format.availableWidth * 0.72,
                height: 54,
                drawText: false,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Center(
              child: pw.Text(
                tracking,
                style: pw.TextStyle(
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: <pw.Widget>[
                pw.Expanded(
                  child: addressPanel(
                    'RETURN FROM',
                    value(returnFrom, 'name'),
                    value(returnFrom, 'address'),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: addressPanel(
                    'RETURN TO SELLER',
                    '${value(returnTo, 'seller_name')}\n${value(returnTo, 'center_name')}',
                    value(returnTo, 'address'),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            addressPanel(
              'DROP-OFF CENTER',
              value(dropoff, 'name'),
              value(dropoff, 'address'),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'RETURN ITEMS',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey500),
              columnWidths: const <int, pw.TableColumnWidth>{
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1),
              },
              children: <pw.TableRow>[
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: <pw.Widget>[
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(7),
                      child: pw.Text(
                        'Item',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(7),
                      child: pw.Text(
                        'Variant / SKU',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(7),
                      child: pw.Text(
                        'Qty',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                ...items.map(
                  (Map<String, dynamic> item) => pw.TableRow(
                    children: <pw.Widget>[
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(7),
                        child: pw.Text(value(item, 'product_name')),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(7),
                        child: pw.Text(
                          '${value(item, 'variant')}\nSKU: ${value(item, 'sku')}',
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(7),
                        child: pw.Text((item['quantity'] ?? 0).toString()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.Spacer(),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.orange50,
                border: pw.Border.all(color: PdfColors.orange200),
              ),
              child: pw.Text(
                (waybill['instructions'] ?? '').toString(),
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  return document.save();
}
