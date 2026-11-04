import 'package:flutter/material.dart';

import '../../services/smart_messaging_service.dart';

Future<void> showSmartMessagingHelp(
  BuildContext context, {
  required String workspace,
  required String conversationId,
}) async {
  if (conversationId.trim().isEmpty) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _SmartMessagingHelpDialog(
      workspace: workspace,
      conversationId: conversationId,
    ),
  );
}

class _SmartMessagingHelpDialog extends StatefulWidget {
  final String workspace;
  final String conversationId;

  const _SmartMessagingHelpDialog({
    required this.workspace,
    required this.conversationId,
  });

  @override
  State<_SmartMessagingHelpDialog> createState() =>
      _SmartMessagingHelpDialogState();
}

class _SmartMessagingHelpDialogState extends State<_SmartMessagingHelpDialog> {
  final TextEditingController _question = TextEditingController();
  String? _answer;
  String? _error;
  bool _busy = false;
  bool _answered = false;
  String? _feedback;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    if (_busy || _question.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _answer = null;
      _answered = false;
    });
    try {
      final result = await SmartMessagingService.answer(
        workspace: widget.workspace,
        conversationId: widget.conversationId,
        question: _question.text,
      );
      if (!mounted) return;
      setState(() => _answer = result['answer']?.toString());
    } catch (error) {
      if (mounted) setState(() => _error = _clean(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rate(String rating) async {
    if (_busy || _answered) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SmartMessagingService.feedback(
        workspace: widget.workspace,
        conversationId: widget.conversationId,
        feedback: rating,
      );
      if (mounted) {
        setState(() {
          _answered = true;
          _feedback = rating;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _clean(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestHuman() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SmartMessagingService.requestHuman(
        workspace: widget.workspace,
        conversationId: widget.conversationId,
        concern: _question.text,
      );
      if (mounted) {
        setState(() {
          _answer =
              'Your request for a person to review this conversation has been sent.';
          _answered = true;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _clean(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _clean(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Smart messaging help'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _question,
              maxLength: 300,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ask a question',
                border: OutlineInputBorder(),
              ),
            ),
            if (_answer != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(_answer!),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (_answer != null && _feedback == null) ...<Widget>[
          TextButton(
            onPressed: _busy ? null : () => _rate('UNRESOLVED'),
            child: const Text('Still need help'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _rate('RESOLVED'),
            child: const Text('Resolved'),
          ),
          TextButton(
            onPressed: _busy ? null : _requestHuman,
            child: const Text('Ask a person'),
          ),
        ] else if (_answer != null && _feedback == 'UNRESOLVED')
          TextButton(
            onPressed: _busy ? null : _requestHuman,
            child: const Text('Ask a person'),
          )
        else if (_answer == null)
          FilledButton(
            onPressed: _busy ? null : _ask,
            child: Text(_busy ? 'Please wait…' : 'Ask'),
          ),
      ],
    );
  }
}
