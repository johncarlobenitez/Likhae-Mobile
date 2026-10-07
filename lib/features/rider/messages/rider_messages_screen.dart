import 'dart:async';

import 'package:flutter/material.dart';

class RiderConversationData {
  final String id;
  final String buyerId;
  final String buyerName;
  final String? orderId;
  final String? trackingCode;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const RiderConversationData({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    this.orderId,
    this.trackingCode,
    this.lastMessage = '',
    this.lastMessageAt,
    this.unreadCount = 0,
  });
}

class RiderMessageData {
  final String id;
  final String conversationId;
  final String body;
  final DateTime sentAt;
  final bool fromRider;

  const RiderMessageData({
    required this.id,
    required this.conversationId,
    required this.body,
    required this.sentAt,
    required this.fromRider,
  });
}

typedef RiderConversationsRefresh =
    Future<List<RiderConversationData>> Function();
typedef RiderConversationLoad =
    Future<List<RiderMessageData>> Function(RiderConversationData conversation);
typedef RiderMessageSend =
    Future<RiderMessageData> Function(
      RiderConversationData conversation,
      String body,
    );
typedef RiderConversationMessageStream =
    Stream<RiderMessageData> Function(RiderConversationData conversation);

class RiderMessagesScreen extends StatefulWidget {
  final List<RiderConversationData> conversations;
  final RiderConversationsRefresh? onRefresh;
  final RiderConversationLoad? onLoadMessages;
  final RiderMessageSend? onSendMessage;
  final RiderConversationMessageStream? messageStreamBuilder;
  final VoidCallback? onBack;
  final String? statusMessage;

  const RiderMessagesScreen({
    super.key,
    this.conversations = const <RiderConversationData>[],
    this.onRefresh,
    this.onLoadMessages,
    this.onSendMessage,
    this.messageStreamBuilder,
    this.onBack,
    this.statusMessage,
  });

  @override
  State<RiderMessagesScreen> createState() => _RiderMessagesScreenState();
}

class _RiderMessagesScreenState extends State<RiderMessagesScreen> {
  static const Color _background = Color(0xFFFBF7F2);
  static const Color _surface = Color(0xFFFFFDF9);
  static const Color _soft = Color(0xFFF6EFE7);
  static const Color _border = Color(0xFFEADCCC);
  static const Color _maroon = Color(0xFF561C17);
  static const Color _text = Color(0xFF3B211B);
  static const Color _muted = Color(0xFF987865);

  late List<RiderConversationData> _conversations;
  final List<RiderMessageData> _messages = <RiderMessageData>[];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  RiderConversationData? _activeConversation;
  StreamSubscription<RiderMessageData>? _messageSubscription;
  bool _loadingMessages = false;
  bool _sendingMessage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _conversations = List<RiderConversationData>.from(widget.conversations);
    _error = widget.statusMessage;
  }

  @override
  void didUpdateWidget(covariant RiderMessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversations != widget.conversations) {
      _conversations = List<RiderConversationData>.from(widget.conversations);
    }
    if (oldWidget.statusMessage != widget.statusMessage) {
      _error = widget.statusMessage;
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final RiderConversationsRefresh? callback = widget.onRefresh;
    if (callback == null) {
      return;
    }
    try {
      final List<RiderConversationData> conversations = await callback();
      if (!mounted) {
        return;
      }
      setState(() {
        _conversations = conversations;
        final String? activeId = _activeConversation?.id;
        _activeConversation = conversations
            .where((RiderConversationData item) => item.id == activeId)
            .firstOrNull;
      });
    } catch (error) {
      _showError('Unable to load conversations: $error');
    }
  }

  Future<void> _openConversation(RiderConversationData conversation) async {
    await _messageSubscription?.cancel();
    setState(() {
      _activeConversation = conversation;
      _messages.clear();
      _error = null;
      _loadingMessages = widget.onLoadMessages != null;
    });

    final RiderConversationLoad? loader = widget.onLoadMessages;
    if (loader != null) {
      try {
        final List<RiderMessageData> messages = await loader(conversation);
        if (!mounted || _activeConversation?.id != conversation.id) {
          return;
        }
        setState(() {
          _messages
            ..clear()
            ..addAll(messages);
        });
      } catch (error) {
        if (mounted && _activeConversation?.id == conversation.id) {
          setState(() {
            _error = 'Unable to load messages: $error';
          });
        }
      } finally {
        if (mounted && _activeConversation?.id == conversation.id) {
          setState(() {
            _loadingMessages = false;
          });
        }
      }
    }

    final RiderConversationMessageStream? streamBuilder =
        widget.messageStreamBuilder;
    if (streamBuilder != null) {
      _messageSubscription = streamBuilder(conversation).listen(
        (RiderMessageData message) {
          if (!mounted ||
              message.conversationId != _activeConversation?.id ||
              _messages.any((RiderMessageData item) => item.id == message.id)) {
            return;
          }
          setState(() {
            _messages.add(message);
          });
          _scrollToLatest();
        },
        onError: (Object error) {
          if (mounted && _activeConversation?.id == conversation.id) {
            setState(() {
              _error = 'Live messages disconnected: $error';
            });
          }
        },
      );
    }
  }

  Future<void> _sendMessage() async {
    final RiderConversationData? conversation = _activeConversation;
    final RiderMessageSend? sender = widget.onSendMessage;
    final String body = _messageController.text.trim();
    if (conversation == null || body.isEmpty || _sendingMessage) {
      return;
    }
    if (sender == null) {
      _showError('Messaging is not connected to Laravel yet.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _sendingMessage = true;
    });
    try {
      final RiderMessageData saved = await sender(conversation, body);
      if (!mounted || _activeConversation?.id != conversation.id) {
        return;
      }
      setState(() {
        if (!_messages.any((RiderMessageData item) => item.id == saved.id)) {
          _messages.add(saved);
        }
        _messageController.clear();
      });
      _scrollToLatest();
    } catch (error) {
      _showError('Message was not sent: $error');
    } finally {
      if (mounted) {
        setState(() {
          _sendingMessage = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _maroon,
          content: Text(message),
        ),
      );
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final RiderConversationData? conversation = _activeConversation;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _text,
        elevation: 0,
        leading: IconButton(
          tooltip: conversation == null ? 'Back' : 'Back to conversations',
          onPressed: conversation == null
              ? (widget.onBack ?? () => Navigator.of(context).maybePop())
              : () {
                  _messageSubscription?.cancel();
                  setState(() {
                    _activeConversation = null;
                    _messages.clear();
                    _error = null;
                  });
                },
          icon: Icon(
            conversation == null ? Icons.arrow_back_rounded : Icons.chevron_left,
          ),
        ),
        title: Text(
          conversation?.buyerName ?? 'Messages',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (conversation == null)
            IconButton(
              tooltip: 'Refresh conversations',
              onPressed: widget.onRefresh == null ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: conversation == null
          ? _buildConversationList()
          : _buildConversation(conversation),
    );
  }

  Widget _buildConversationList() {
    return RefreshIndicator(
      color: _maroon,
      onRefresh: _refresh,
      child: _conversations.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 90, 24, 120),
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: 54,
                  color: _maroon.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 18),
                const Text(
                  'No conversations yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _text,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.onRefresh == null
                      ? 'Buyer and rider messaging will appear here when Laravel messaging is connected.'
                      : 'Messages from buyers about your deliveries will appear here.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
              itemCount: _conversations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) {
                final RiderConversationData conversation =
                    _conversations[index];
                return Material(
                  color: _surface,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: () => _openConversation(conversation),
                    borderRadius: BorderRadius.circular(15),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _soft,
                            foregroundColor: _maroon,
                            child: Text(
                              _initials(conversation.buyerName),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  conversation.buyerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _text,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  conversation.orderId == null
                                      ? conversation.lastMessage
                                      : 'Order ${conversation.orderId} · ${conversation.lastMessage}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (conversation.unreadCount > 0)
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: _maroon,
                              child: Text(
                                conversation.unreadCount > 99
                                    ? '99+'
                                    : '${conversation.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildConversation(RiderConversationData conversation) {
    return Column(
      children: [
        if (conversation.orderId != null || conversation.trackingCode != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              <String>[
                if (conversation.orderId != null)
                  'Order ${conversation.orderId}',
                if (conversation.trackingCode != null)
                  conversation.trackingCode!,
              ].join(' · '),
              style: const TextStyle(
                color: _maroon,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Expanded(
          child: _loadingMessages
              ? const Center(
                  child: CircularProgressIndicator(color: _maroon),
                )
              : _messages.isEmpty
              ? Center(
                  child: Text(
                    _error ?? 'No messages in this conversation yet.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                  itemCount: _messages.length,
                  itemBuilder: (BuildContext context, int index) {
                    final RiderMessageData message = _messages[index];
                    return Align(
                      alignment: message.fromRider
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                        ),
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: message.fromRider ? _maroon : _surface,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              message.body,
                              style: TextStyle(
                                color: message.fromRider
                                    ? Colors.white
                                    : _text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(message.sentAt),
                              style: TextStyle(
                                color: message.fromRider
                                    ? Colors.white70
                                    : _muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_error != null && _messages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Message ${conversation.buyerName}...',
                      filled: true,
                      fillColor: _surface,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: _border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: _border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: _sendingMessage ? null : _sendMessage,
                  style: IconButton.styleFrom(backgroundColor: _maroon),
                  icon: _sendingMessage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .take(2)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '?';
    }
    return parts.map((String part) => part[0].toUpperCase()).join();
  }

  static String _formatTime(DateTime value) {
    final DateTime local = value.toLocal();
    final String hour = (local.hour % 12 == 0 ? 12 : local.hour % 12)
        .toString();
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
}
