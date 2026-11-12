import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/smart_messaging_service.dart';

Future<void> showSmartMessagingHelp(
  BuildContext context, {
  required String workspace,
  required String conversationId,
  int? productId,
  int? variantId,
  SmartMessagingClient service = const SmartMessagingService(),
}) async {
  if (conversationId.trim().isEmpty) return;
  await showDialog<void>(
    context: context,
    builder: (_) => SmartMessagingHelpDialog(
      workspace: workspace,
      conversationId: conversationId,
      productId: productId,
      variantId: variantId,
      service: service,
    ),
  );
}

class SmartMessagingHelpDialog extends StatefulWidget {
  final String workspace;
  final String conversationId;
  final int? productId;
  final int? variantId;
  final SmartMessagingClient service;

  const SmartMessagingHelpDialog({
    super.key,
    required this.workspace,
    required this.conversationId,
    this.productId,
    this.variantId,
    this.service = const SmartMessagingService(),
  });

  @override
  State<SmartMessagingHelpDialog> createState() =>
      _SmartMessagingHelpDialogState();
}

class _SmartMessagingHelpDialogState extends State<SmartMessagingHelpDialog> {
  final TextEditingController _question = TextEditingController();
  final ScrollController _contentScrollController = ScrollController();
  List<_SmartHelpSuggestion> _suggestions = const <_SmartHelpSuggestion>[];
  bool _loadingSuggestions = true;
  bool _busy = false;
  bool _humanHandoff = false;
  bool _hasAnswer = false;
  String? _recipientName;
  String? _welcomeMessage;
  String? _contextLabel;
  String? _answerQuestion;
  String? _answer;
  String? _answerSource;
  String? _error;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSuggestions());
  }

  @override
  void dispose() {
    _question.dispose();
    _contentScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    try {
      final Map<String, dynamic> result = await widget.service.bootstrap(
        workspace: widget.workspace,
        conversationId: widget.conversationId,
        productId: widget.productId,
        variantId: widget.variantId,
      );
      final dynamic rawSuggestions = result['suggestions'];
      final List<_SmartHelpSuggestion> suggestions = rawSuggestions is List
          ? rawSuggestions
                .whereType<Map>()
                .map(
                  (Map item) => _SmartHelpSuggestion.fromApi(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((suggestion) => suggestion.question.isNotEmpty)
                .toList(growable: false)
          : const <_SmartHelpSuggestion>[];
      final dynamic sessionValue = result['session'];
      final Map<String, dynamic> session = sessionValue is Map
          ? Map<String, dynamic>.from(sessionValue)
          : const <String, dynamic>{};
      final dynamic historyValue = result['history'];
      final List<Map<String, dynamic>> history = historyValue is List
          ? historyValue
                .whereType<Map>()
                .map((Map item) => Map<String, dynamic>.from(item))
                .toList(growable: false)
          : const <Map<String, dynamic>>[];
      final Map<String, dynamic> latest = history.isNotEmpty
          ? history.last
          : session;
      final String status = (session['status'] ?? '').toString();
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
        _recipientName = _optionalString(result['recipient_name']);
        _welcomeMessage = _optionalString(result['welcome_message']);
        _contextLabel = _optionalString(result['context_label']);
        _answerQuestion = _optionalString(
          latest['question'] ?? latest['selected_question'],
        );
        _answer = _optionalString(
          latest['answer'] ?? latest['answer_snapshot'],
        );
        _answerSource = _optionalString(
          latest['source'] ?? latest['answer_source'],
        );
        _feedback = _optionalString(
          latest['feedback'] ??
              latest['last_feedback'] ??
              session['last_feedback'],
        );
        _hasAnswer = _answer?.isNotEmpty == true;
        _humanHandoff = <String>{
          'HUMAN_ASSISTANCE_REQUESTED',
          'HUMAN_CONVERSATION',
        }.contains(status);
        _loadingSuggestions = false;
      });
      if (_hasAnswer) _scrollToLatest();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _clean(error);
        _loadingSuggestions = false;
      });
    }
  }

  Future<void> _askSuggestion(_SmartHelpSuggestion suggestion) {
    return _ask(
      questionKey: suggestion.key,
      displayQuestion: suggestion.question,
    );
  }

  Future<void> _ask({
    String? questionKey,
    String? questionText,
    String? displayQuestion,
  }) async {
    if (_busy || _humanHandoff) return;
    final String? text = questionText?.trim();
    if ((questionKey?.trim().isNotEmpty != true) &&
        (text?.isNotEmpty != true)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _feedback = null;
    });
    try {
      final Map<String, dynamic> result = await widget.service.answer(
        workspace: widget.workspace,
        conversationId: widget.conversationId,
        questionKey: questionKey,
        questionText: text,
        productId: widget.productId,
        variantId: widget.variantId,
      );
      if (!mounted) return;
      setState(() {
        _answerQuestion =
            _optionalString(result['question']) ?? displayQuestion ?? text;
        _answer = _optionalString(result['answer']);
        _answerSource = _optionalString(result['answer_source']);
        _hasAnswer = _answer?.isNotEmpty == true;
        _question.clear();
      });
      if (_hasAnswer) _scrollToLatest();
    } catch (error) {
      if (mounted) setState(() => _error = _clean(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rate(String rating) async {
    if (_busy || !_hasAnswer || _humanHandoff) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.feedback(
        workspace: widget.workspace,
        conversationId: widget.conversationId,
        feedback: rating,
      );
      if (mounted) setState(() => _feedback = rating);
    } catch (error) {
      if (mounted) setState(() => _error = _clean(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestHuman() async {
    if (_busy || _humanHandoff) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.requestHuman(
        workspace: widget.workspace,
        conversationId: widget.conversationId,
        concern: _question.text.trim().isNotEmpty
            ? _question.text
            : _answerQuestion,
        productId: widget.productId,
        variantId: widget.variantId,
      );
      if (mounted) {
        setState(() {
          _humanHandoff = true;
          _feedback = null;
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

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_contentScrollController.hasClients) return;
      _contentScrollController.animateTo(
        _contentScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String? _optionalString(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final MediaQueryData media = MediaQuery.of(context);
    final double availableHeight =
        (media.size.height - media.padding.vertical - media.viewInsets.vertical)
            .clamp(280.0, double.infinity)
            .toDouble();
    final double maxContentHeight = (availableHeight - 170)
        .clamp(120.0, 640.0)
        .toDouble();
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      buttonPadding: EdgeInsets.zero,
      title: Text(
        _recipientName == null
            ? 'Smart messaging help'
            : 'Help with $_recipientName',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
      content: SizedBox(
        width: 460,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxContentHeight),
          child: Scrollbar(
            controller: _contentScrollController,
            child: SingleChildScrollView(
              controller: _contentScrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (_contextLabel != null) ...<Widget>[
                    Text(
                      'Context: $_contextLabel',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_welcomeMessage != null)
                    _HelpCard(
                      color: colors.surfaceContainerHighest,
                      child: Text(_welcomeMessage!),
                    ),
                  if (_loadingSuggestions)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Column(
                          children: <Widget>[
                            CircularProgressIndicator(),
                            SizedBox(height: 10),
                            Text('Loading suggested questions...'),
                          ],
                        ),
                      ),
                    )
                  else if (!_humanHandoff) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      'Suggested questions',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_suggestions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'You can ask a question below.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Wrap(
                          spacing: 7,
                          runSpacing: 2,
                          children: _suggestions
                              .map(
                                (suggestion) => ActionChip(
                                  label: Text(
                                    suggestion.question,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => _askSuggestion(suggestion),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _question,
                      maxLength: 300,
                      maxLines: 2,
                      enabled: !_busy,
                      textInputAction: TextInputAction.send,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (String text) => _ask(questionText: text),
                      decoration: const InputDecoration(
                        labelText: 'Ask in your own words',
                        hintText: 'Type a question for the seller or support',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _busy || _question.text.trim().isEmpty
                            ? null
                            : () => _ask(questionText: _question.text),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: Text(_busy ? 'Please wait...' : 'Ask question'),
                      ),
                    ),
                  ],
                  if (_answer != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _HelpCard(
                      color: colors.surface,
                      outlined: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (_answerQuestion != null) ...<Widget>[
                            Text(
                              _answerQuestion!,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 7),
                          ],
                          if (_answerSource != null) ...<Widget>[
                            Text(
                              _answerSource!,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: colors.primary),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(_answer!),
                        ],
                      ),
                    ),
                  ],
                  if (_hasAnswer &&
                      !_humanHandoff &&
                      _feedback == null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text('Did this answer help?'),
                    Wrap(
                      spacing: 6,
                      children: <Widget>[
                        TextButton(
                          onPressed: _busy ? null : () => _rate('RESOLVED'),
                          child: const Text('Yes, thanks'),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => _rate('UNRESOLVED'),
                          child: const Text('I still need help'),
                        ),
                      ],
                    ),
                  ],
                  if (_feedback != null && !_humanHandoff)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _feedback == 'RESOLVED'
                            ? 'Marked helpful. You can ask another question or continue chatting.'
                            : 'Thanks for letting us know. You can request live help here.',
                      ),
                    ),
                  if (_humanHandoff)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _HelpCard(
                        color: colors.secondaryContainer,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.support_agent_rounded,
                              size: 20,
                              color: colors.onSecondaryContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Live help was requested. Continue in this conversation.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: colors.onSecondaryContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!_humanHandoff) ...<Widget>[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _requestHuman,
                      icon: const Icon(Icons.support_agent_rounded),
                      label: const Text('Request live help'),
                    ),
                  ],
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: colors.error)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SmartHelpSuggestion {
  final String key;
  final String question;

  const _SmartHelpSuggestion({required this.key, required this.question});

  factory _SmartHelpSuggestion.fromApi(Map<String, dynamic> json) {
    return _SmartHelpSuggestion(
      key: (json['key'] ?? '').toString(),
      question: (json['question'] ?? '').toString().trim(),
    );
  }
}

class _HelpCard extends StatelessWidget {
  final Color color;
  final Widget child;
  final bool outlined;

  const _HelpCard({
    required this.color,
    required this.child,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: outlined
            ? Border.all(color: Theme.of(context).colorScheme.outlineVariant)
            : null,
      ),
      child: child,
    );
  }
}
