import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/buyer_ai_service.dart';

class BuyerAiAssistant extends StatefulWidget {
  final String page;
  final String pageTitle;

  const BuyerAiAssistant({
    super.key,
    this.page = 'buyer',
    this.pageTitle = 'Buyer portal',
  });

  @override
  State<BuyerAiAssistant> createState() => _BuyerAiAssistantState();
}

class _BuyerAiMessage {
  final String text;
  final bool fromBuyer;
  final List<String> options;

  const _BuyerAiMessage({
    required this.text,
    required this.fromBuyer,
    this.options = const <String>[],
  });
}

class _BuyerAiAssistantState extends State<BuyerAiAssistant> {
  static const double _launcherSize = 57;
  static const double _edgeMargin = 12;

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _messagesController = ScrollController();
  final List<_BuyerAiMessage> _messages = <_BuyerAiMessage>[];
  bool _open = false;
  bool _sending = false;
  Offset? _launcherPosition;
  bool _draggingLauncher = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      const _BuyerAiMessage(
        text:
            'Hi! I’m your LIKHAE Buyer AI Assistant. I can help with products, cart, orders, delivery updates, vouchers, and account features.',
        fromBuyer: false,
        options: <String>[
          'How do I track my order?',
          'How do I check out?',
          'Where are my vouchers?',
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _messagesController.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestedMessage]) async {
    final String text = (suggestedMessage ?? _inputController.text).trim();
    if (text.isEmpty || _sending) return;

    _inputController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _sending = true;
      _messages.add(_BuyerAiMessage(text: text, fromBuyer: true));
    });
    _scrollToBottom();

    try {
      final BuyerAiResponse response = await BuyerAiService.chat(
        message: text,
        page: widget.page,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          _BuyerAiMessage(
            text: response.reply,
            fromBuyer: false,
            options: response.options,
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _BuyerAiMessage(text: _friendlyError(error), fromBuyer: false),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is Exception) {
      final String message = error.toString().replaceFirst('Exception: ', '');
      if (message.isNotEmpty) return message;
    }

    return ApiClient.formatError(error);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesController.hasClients) return;
      _messagesController.animateTo(
        _messagesController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final Offset launcherPosition = _launcherPositionFor(media);
    final double panelHeight = (media.size.height * 0.68)
        .clamp(390.0, 560.0)
        .toDouble();

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        if (_open)
          Positioned(
            left: 16,
            right: 16,
            bottom: 102,
            child: SizedBox(height: panelHeight, child: _buildPanel(context)),
          ),
        Positioned(
          left: launcherPosition.dx,
          top: launcherPosition.dy,
          child: _buildLauncher(context, media),
        ),
      ],
    );
  }

  Offset _launcherPositionFor(MediaQueryData media) {
    final double minLeft = _edgeMargin;
    final double minTop = media.padding.top + _edgeMargin;
    final double maxLeft = media.size.width - _launcherSize - _edgeMargin;
    final double maxTop =
        media.size.height - media.padding.bottom - _launcherSize - _edgeMargin;

    final Offset fallback = Offset(
      maxLeft.clamp(minLeft, double.infinity).toDouble(),
      (media.size.height - media.padding.bottom - 102 - _launcherSize)
          .clamp(minTop, double.infinity)
          .toDouble(),
    );
    final Offset position = _launcherPosition ?? fallback;

    return Offset(
      position.dx.clamp(minLeft, maxLeft).toDouble(),
      position.dy.clamp(minTop, maxTop).toDouble(),
    );
  }

  void _startDraggingLauncher() {
    setState(() => _draggingLauncher = true);
  }

  void _dragLauncher(DragUpdateDetails details, MediaQueryData media) {
    final Offset current = _launcherPositionFor(media);
    final Offset next = current + details.delta;
    final double maxLeft = media.size.width - _launcherSize - _edgeMargin;
    final double maxTop =
        media.size.height - media.padding.bottom - _launcherSize - _edgeMargin;

    setState(() {
      _launcherPosition = Offset(
        next.dx.clamp(_edgeMargin, maxLeft).toDouble(),
        next.dy.clamp(media.padding.top + _edgeMargin, maxTop).toDouble(),
      );
    });
  }

  void _finishDraggingLauncher(MediaQueryData media) {
    final Offset current = _launcherPositionFor(media);
    final double maxLeft = media.size.width - _launcherSize - _edgeMargin;
    final double snappedLeft = current.dx + (_launcherSize / 2) < media.size.width / 2
        ? _edgeMargin
        : maxLeft;

    setState(() {
      _launcherPosition = Offset(snappedLeft, current.dy);
      _draggingLauncher = false;
    });
  }

  Widget _buildLauncher(BuildContext context, MediaQueryData media) {
    final Color primary = AppTheme.maroon(context);

    return Semantics(
      button: true,
      label: _open ? 'Close Buyer AI Assistant' : 'Open Buyer AI Assistant',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _startDraggingLauncher(),
        onPanUpdate: (DragUpdateDetails details) =>
            _dragLauncher(details, media),
        onPanEnd: (_) => _finishDraggingLauncher(media),
        child: Material(
          color: primary,
          shape: const CircleBorder(),
          elevation: _draggingLauncher ? 12 : 7,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => setState(() => _open = !_open),
            child: SizedBox(
              width: _launcherSize,
              height: _launcherSize,
              child: Center(
                child: Icon(
                  _open ? Icons.close_rounded : Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final Color primary = AppTheme.maroon(context);
    final Color surface = Theme.of(context).colorScheme.surface;
    final Color border = Theme.of(context).colorScheme.outlineVariant;

    return Material(
      color: surface,
      elevation: 12,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            color: primary,
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'LIKHAE AI Assistant',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        widget.pageTitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close assistant',
                  onPressed: () => setState(() => _open = false),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _messagesController,
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (BuildContext context, int index) {
                if (_sending && index == _messages.length) {
                  return const _TypingBubble();
                }
                return _buildMessage(context, _messages[index], border);
              },
            ),
          ),
          if (_sending) const LinearProgressIndicator(minHeight: 2),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Ask LIKHAE AI…',
                      counterText: '',
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.42),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(
    BuildContext context,
    _BuyerAiMessage message,
    Color border,
  ) {
    final Color primary = AppTheme.maroon(context);
    final Color bubbleColor = message.fromBuyer
        ? primary
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final Color textColor = message.fromBuyer
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment: message.fromBuyer
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: message.fromBuyer
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                border: message.fromBuyer ? null : Border.all(color: border),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(15),
                  topRight: const Radius.circular(15),
                  bottomLeft: Radius.circular(message.fromBuyer ? 15 : 4),
                  bottomRight: Radius.circular(message.fromBuyer ? 4 : 15),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(color: textColor, fontSize: 12, height: 1.45),
              ),
            ),
            if (!message.fromBuyer && message.options.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: message.options.map((String option) {
                    return ActionChip(
                      label: Text(option),
                      onPressed: _sending ? null : () => _send(option),
                      labelStyle: TextStyle(
                        color: primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const SizedBox(
          width: 28,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _TypingDot(),
              _TypingDot(),
              _TypingDot(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  const _TypingDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: AppTheme.maroon(context).withValues(alpha: 0.7),
        shape: BoxShape.circle,
      ),
    );
  }
}
