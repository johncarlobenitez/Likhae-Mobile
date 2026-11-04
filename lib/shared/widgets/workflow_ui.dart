import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../services/workspace_mobile_service.dart';
import '../../features/rider/scanner/rider_scanner_screen.dart';
import '../../features/rider/scanner/rider_parcel_scan_result.dart';

String workflowError(Object error) =>
    error.toString().replaceFirst('Exception: ', '');

class WorkflowField {
  final String keyName, label;
  final bool required, numeric, multiline, scan;
  final Map<String, String>? choices;
  final String initial;
  const WorkflowField(
    this.keyName,
    this.label, {
    this.required = true,
    this.numeric = false,
    this.multiline = false,
    this.scan = false,
    this.choices,
    this.initial = '',
  });
}

Future<bool> showWorkflowForm(
  BuildContext context, {
  required String title,
  required String description,
  required String endpoint,
  List<WorkflowField> fields = const [],
  Map<String, dynamic> fixed = const {},
  Map<String, String> uploads = const {},
  String method = 'POST',
}) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkflowForm(
          title: title,
          description: description,
          endpoint: endpoint,
          fields: fields,
          fixed: fixed,
          uploads: uploads,
          method: method,
        ),
      ),
    ) ??
    false;

class WorkflowForm extends StatefulWidget {
  final String title, description, endpoint, method;
  final List<WorkflowField> fields;
  final Map<String, dynamic> fixed;
  final Map<String, String> uploads;
  const WorkflowForm({
    super.key,
    required this.title,
    required this.description,
    required this.endpoint,
    this.fields = const [],
    this.fixed = const {},
    this.uploads = const {},
    this.method = 'POST',
  });
  @override
  State<WorkflowForm> createState() => _WorkflowFormState();
}

class _WorkflowFormState extends State<WorkflowForm> {
  final _key = GlobalKey<FormState>();
  late final _controllers = {
    for (final f in widget.fields)
      f.keyName: TextEditingController(text: f.initial),
  };
  final _files = <String, ({String name, Uint8List bytes})>{};
  var _busy = false;
  String? _error;
  String _scanMethod = 'MANUAL';
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{...widget.fixed};
      for (final field in widget.fields) {
        final text = _controllers[field.keyName]!.text.trim();
        if (text.isNotEmpty) data[field.keyName] = text;
        if (field.scan && field.keyName == 'scanned_code')
          data['scan_method'] = _scanMethod;
      }
      dynamic body = data;
      if (_files.isNotEmpty) {
        body = FormData.fromMap({
          ...data,
          for (final entry in _files.entries)
            entry.key: MultipartFile.fromBytes(
              entry.value.bytes,
              filename: entry.value.name,
            ),
        });
      }
      await WorkspaceMobileService.send(
        widget.endpoint,
        body,
        method: widget.method,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = workflowError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan(WorkflowField field) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => const RiderScannerScreen(
          returnScanDetails: true,
          showSignOut: false,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (result is Map) {
        _controllers[field.keyName]!.text =
            '${result['scanned_code'] ?? result['code'] ?? ''}';
        _scanMethod =
            '${result['scan_method'] ?? result['method'] ?? 'MANUAL'}';
      } else {
        _controllers[field.keyName]!.text = result is RiderParcelScanResult
            ? result.code
            : result.toString();
        _scanMethod = result is RiderParcelScanResult
            ? result.method
            : 'MANUAL';
      }
    });
  }

  Future<void> _pick(String key) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );
      if (!mounted || file == null) return;
      const maxBytes = 10 * 1024 * 1024;
      final size = await file.length();
      if (size != null && size > maxBytes)
        throw Exception('Choose a file up to 10 MB.');
      final bytes = await file.readAsBytes();
      if (bytes.length > maxBytes)
        throw Exception('Choose a file up to 10 MB.');
      if (!mounted) return;
      setState(() => _files[key] = (name: file.name, bytes: bytes));
    } catch (e) {
      if (mounted) setState(() => _error = workflowError(e));
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Form(
          key: _key,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(widget.description),
              const SizedBox(height: 20),
              for (final field in widget.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: field.choices != null
                      ? DropdownButtonFormField<String>(
                          key: ValueKey<String>(
                            '${field.keyName}:${_controllers[field.keyName]!.text}',
                          ),
                          initialValue:
                              _controllers[field.keyName]!.text.isEmpty
                              ? null
                              : _controllers[field.keyName]!.text,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: field.label),
                          items: field.choices!.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (value) => setState(
                                  () => _controllers[field.keyName]!.text =
                                      value ?? '',
                                ),
                          validator: (v) =>
                              field.required && (v == null || v.isEmpty)
                              ? 'Choose ${field.label.toLowerCase()}.'
                              : null,
                        )
                      : TextFormField(
                          controller: _controllers[field.keyName],
                          enabled: !_busy,
                          keyboardType: field.numeric
                              ? const TextInputType.numberWithOptions(
                                  decimal: true,
                                )
                              : field.multiline
                              ? TextInputType.multiline
                              : TextInputType.text,
                          minLines: field.multiline ? 3 : 1,
                          maxLines: field.multiline ? 5 : 1,
                          decoration: InputDecoration(
                            labelText: field.label,
                            suffixIcon: field.scan
                                ? IconButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _scan(field),
                                    icon: const Icon(Icons.qr_code_scanner),
                                  )
                                : null,
                          ),
                          onChanged: field.scan
                              ? (_) => _scanMethod = 'MANUAL'
                              : null,
                          validator: (value) {
                            if (field.required &&
                                (value?.trim().isEmpty ?? true))
                              return 'Enter ${field.label.toLowerCase()}.';
                            if (field.numeric &&
                                value!.isNotEmpty &&
                                (num.tryParse(value) == null ||
                                    num.parse(value) < 0))
                              return 'Enter a valid amount.';
                            return null;
                          },
                        ),
                ),
              for (final entry in widget.uploads.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value),
                  subtitle: Text(
                    _files[entry.key]?.name ??
                        'JPEG, PNG, WebP or PDF · up to 10 MB',
                  ),
                  trailing: IconButton(
                    onPressed: _busy ? null : () => _pick(entry.key),
                    icon: const Icon(Icons.attach_file),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class WorkflowList extends StatefulWidget {
  final String title, endpoint, emptyMessage;
  final Widget Function(BuildContext, Map<String, dynamic>, VoidCallback) item;
  final Widget? header;
  const WorkflowList({
    super.key,
    required this.title,
    required this.endpoint,
    required this.item,
    this.header,
    this.emptyMessage = 'Nothing to show yet.',
  });
  @override
  State<WorkflowList> createState() => _WorkflowListState();
}

class _WorkflowListState extends State<WorkflowList> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _future = WorkspaceMobileService.rows(widget.endpoint);
  }

  void _reload() {
    setState(() => _future = WorkspaceMobileService.rows(widget.endpoint));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          onPressed: _reload,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.header != null) widget.header!,
                if (snapshot.hasError) Text(workflowError(snapshot.error!)),
                if (!snapshot.hasError && (snapshot.data?.isEmpty ?? true))
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(widget.emptyMessage),
                  ),
                for (final row in snapshot.data ?? <Map<String, dynamic>>[])
                  widget.item(context, row, _reload),
              ],
            ),
          );
        },
      ),
    ),
  );
}

Future<void> openWorkflowProof(BuildContext context, String endpoint) async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => _ProofPage(endpoint: endpoint)),
  );
}

class _ProofPage extends StatefulWidget {
  final String endpoint;
  const _ProofPage({required this.endpoint});
  @override
  State<_ProofPage> createState() => _ProofPageState();
}

class _ProofPageState extends State<_ProofPage> {
  late final _file = WorkspaceMobileService.file(widget.endpoint);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Private proof')),
    body: FutureBuilder(
      future: _file,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text(workflowError(snapshot.error!)));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final file = snapshot.data!;
        return Column(
          children: [
            Expanded(
              child: file.mime.startsWith('image/')
                  ? InteractiveViewer(child: Image.memory(file.bytes))
                  : const Center(
                      child: Text(
                        'Save this document to view it on your device.',
                      ),
                    ),
            ),
            SafeArea(
              child: TextButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Save proof'),
                onPressed: () async {
                  try {
                    await FilePicker.saveFile(
                      fileName: file.mime.contains('pdf')
                          ? 'proof.pdf'
                          : 'proof.jpg',
                      bytes: file.bytes,
                    );
                  } catch (e) {
                    if (context.mounted)
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(workflowError(e))));
                  }
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}
