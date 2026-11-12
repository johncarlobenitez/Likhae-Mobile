import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../shared/widgets/sized_network_image.dart';
import '../../../shared/widgets/shop_ui.dart';
import '../../../shared/widgets/smart_messaging_help.dart';
import 'message_models.dart';
import 'package:image_picker/image_picker.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/core/storage/token_storage.dart';
import 'package:likhae/core/theme/app_theme.dart';

export 'message_models.dart'
    show
        BuyerConversationPresenceData,
        BuyerMessageData,
        MessageOrderContext,
        MessageOrderProduct;

extension _MessagesPalette on BuildContext {
  bool get _messagesDark => Theme.of(this).brightness == Brightness.dark;

  Color get messagesBackground =>
      _messagesDark ? AppTheme.darkBackground : ShopColors.canvas;
  Color get messagesBackgroundSoft =>
      _messagesDark ? AppTheme.darkSurfaceStrong : ShopColors.soft;
  Color get messagesSurface =>
      _messagesDark ? AppTheme.darkSurface : ShopColors.surface;
  Color get messagesBorder =>
      _messagesDark ? AppTheme.darkBorder : ShopColors.border;
  Color get messagesAccent =>
      _messagesDark ? AppTheme.darkMaroonDark : ShopColors.accent;
  Color get messagesAccentText =>
      _messagesDark ? AppTheme.darkMaroonSoft : ShopColors.accentDark;
  Color get messagesText => _messagesDark ? AppTheme.darkText : ShopColors.text;
  Color get messagesMuted =>
      _messagesDark ? AppTheme.darkMuted : ShopColors.muted;
  Color get messagesFaint =>
      _messagesDark ? AppTheme.darkMutedSoft : ShopColors.faint;
  Color get messagesTan => _messagesDark ? AppTheme.darkTan : ShopColors.tan;
  Color get messagesDanger =>
      _messagesDark ? AppTheme.darkDanger : const Color(0xFFB42318);
  Color get messagesChatBackground => _messagesDark
      ? AppTheme.darkBackground
      : const Color(0xFFFBF7F2);
  Color get messagesChatBackgroundSoft => _messagesDark
      ? AppTheme.darkSurfaceStrong
      : const Color(0xFFF6EFE7);
  Color get messagesChatSurface => _messagesDark
      ? AppTheme.darkSurface
      : const Color(0xFFFFFDF9);
  Color get messagesChatBorder => _messagesDark
      ? AppTheme.darkBorder
      : const Color(0xFFEADCCC);
  Color get messagesChatAccent => _messagesDark
      ? AppTheme.darkMaroonDark
      : const Color(0xFF561C17);
  Color get messagesChatAccentLight => _messagesDark
      ? const Color(0xFF73423A)
      : const Color(0xFF642920);
  Color get messagesChatText =>
      _messagesDark ? AppTheme.darkText : const Color(0xFF3B211B);
  Color get messagesChatMuted =>
      _messagesDark ? AppTheme.darkMuted : const Color(0xFF987865);
  Color get messagesChatMutedSoft =>
      _messagesDark ? const Color(0xFFC8B7AD) : const Color(0xFFA99386);
}

typedef LoadConversationMessagesCallback =
    Future<List<BuyerMessageData>> Function(BuyerConversationData seller);

typedef SendBuyerMessageCallback =
    Future<BuyerMessageData> Function(
      BuyerConversationData seller,
      String body,
    );

typedef SendBuyerAttachmentCallback =
    Future<BuyerMessageData> Function(
      BuyerConversationData seller,
      String body,
      String attachmentPath,
    );

typedef ConversationMessageStreamBuilder =
    Stream<BuyerMessageData> Function(BuyerConversationData seller);

typedef BuyerConversationPresenceRefreshCallback =
    Future<BuyerConversationPresenceData> Function(
      BuyerConversationData seller,
    );

typedef BuyerPresenceHeartbeatCallback = Future<void> Function();

typedef RefreshConversationsCallback =
    Future<List<BuyerConversationData>> Function();

typedef BuyerConversationCallback = void Function(BuyerConversationData seller);

typedef MessageProductReferenceCallback =
    void Function(MessageProductReference product);

class BuyerConversationData {
  final String sellerId;

  final String conversationId;

  final String name;
  final String slug;

  final String? avatarUrl;

  final String lastMessage;
  final String time;

  final int unread;
  final MessageOrderContext? orderContext;

  /// Display-only seller status supplied by Laravel.
  ///
  /// Examples:
  /// "Online"
  /// "Offline"
  /// "Verified Seller"
  /// "Usually replies within an hour"
  ///
  /// Do not manufacture this value in Flutter.
  final String? statusLabel;

  /// Optional actual online-presence state.
  ///
  /// true  = backend explicitly says online
  /// false = backend explicitly says offline
  /// null  = presence is unknown / not tracked
  ///
  /// This prevents the UI from showing a fake green
  /// online dot simply because a status label exists.
  final bool? isOnline;

  const BuyerConversationData({
    required this.sellerId,
    required this.name,
    required this.slug,
    this.conversationId = '',
    this.avatarUrl,
    this.lastMessage = '',
    this.time = '',
    this.unread = 0,
    this.orderContext,
    this.statusLabel,
    this.isOnline,
  });

  BuyerConversationData copyWith({
    String? conversationId,
    String? lastMessage,
    String? time,
    int? unread,
    MessageOrderContext? orderContext,
    String? statusLabel,
    bool? isOnline,
  }) {
    return BuyerConversationData(
      sellerId: sellerId,
      name: name,
      slug: slug,
      conversationId: conversationId ?? this.conversationId,
      avatarUrl: avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      unread: unread ?? this.unread,
      orderContext: orderContext ?? this.orderContext,
      statusLabel: statusLabel ?? this.statusLabel,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  String get initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .take(2)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    return parts.map((String part) => part[0].toUpperCase()).join();
  }
}

class MessageProductReference {
  final String name;

  final String? slug;

  final int? productId;

  final String? imageUrl;

  final double? price;

  const MessageProductReference({
    required this.name,
    this.slug,
    this.productId,
    this.imageUrl,
    this.price,
  });
}

class MessagesScreen extends StatefulWidget {
  final List<BuyerConversationData> conversations;

  final bool showPreviewWhenEmpty;

  /// Messages already loaded for the initially selected
  /// seller.
  final List<BuyerMessageData> initialMessages;

  /// Seller slug requested by another Buyer page.
  ///
  /// Example:
  ///
  /// Product Details
  ///      ↓
  /// Message Seller
  ///      ↓
  /// Messages
  final String? initialSellerSlug;

  /// Important for starting a conversation with a seller
  /// who does NOT already exist in the buyer's conversation
  /// list.
  ///
  /// Without this, Flutter must never silently open a
  /// different seller.
  final BuyerConversationData? initialSeller;

  final MessageProductReference? productReference;

  final VoidCallback? onBack;

  final BuyerConversationCallback? onConversationSelected;

  final BuyerConversationCallback? onViewStore;

  final MessageProductReferenceCallback? onProductReferenceSelected;

  final LoadConversationMessagesCallback? onLoadMessages;

  final SendBuyerMessageCallback? onSendMessage;

  /// Sends a message with one photo attachment.
  /// The callback must upload attachmentPath to Laravel
  /// and return the real saved message.
  final SendBuyerAttachmentCallback? onSendAttachment;

  /// Connect the Laravel message stream here later.
  ///
  /// The screen automatically reconnects if the stream
  /// closes while this seller remains active.
  final ConversationMessageStreamBuilder? messageStreamBuilder;

  final RefreshConversationsCallback? onRefreshConversations;

  final BuyerConversationPresenceRefreshCallback? onRefreshConversationPresence;

  final BuyerPresenceHeartbeatCallback? onPresenceHeartbeat;

  /// Keep this configurable in case Laravel validation
  /// changes later.
  final int maxMessageLength;

  const MessagesScreen({
    super.key,
    this.conversations = const <BuyerConversationData>[],
    this.showPreviewWhenEmpty = true,
    this.initialMessages = const <BuyerMessageData>[],
    this.initialSellerSlug,
    this.initialSeller,
    this.productReference,
    this.onBack,
    this.onConversationSelected,
    this.onViewStore,
    this.onProductReferenceSelected,
    this.onLoadMessages,
    this.onSendMessage,
    this.onSendAttachment,
    this.messageStreamBuilder,
    this.onRefreshConversations,
    this.onRefreshConversationPresence,
    this.onPresenceHeartbeat,
    this.maxMessageLength = 1000,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with WidgetsBindingObserver {
  Color get _background => context.messagesBackground;
  Color get _backgroundSoft => context.messagesBackgroundSoft;
  Color get _surface => context.messagesSurface;
  Color get _border => context.messagesBorder;
  Color get _maroon => context.messagesAccent;
  Color get _maroonDark => context.messagesAccentText;
  Color get _text => context.messagesText;
  Color get _muted => context.messagesMuted;
  Color get _muted2 => context.messagesFaint;
  Color get _tan => context.messagesTan;
  Color get _danger => context.messagesDanger;

  static const double _desktopBreakpoint = 820;

  late List<BuyerConversationData> _conversations;

  List<BuyerMessageData> _messages = <BuyerMessageData>[];

  BuyerConversationData? _activeSeller;

  final Set<String> _seenMessageIds = <String>{};

  final TextEditingController _messageController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  XFile? _pendingAttachment;

  bool _pickingAttachment = false;

  /// Extra messages typed while viewing the clearly
  /// labeled sample conversation. Preview messages stay
  /// local and are never presented as Laravel records.
  final Map<String, List<_DemoMessage>> _demoSentMessages =
      <String, List<_DemoMessage>>{};

  final ScrollController _messageScrollController = ScrollController();

  StreamSubscription<BuyerMessageData>? _messageSubscription;

  Timer? _reconnectTimer;

  Timer? _presenceTimer;

  bool _mobileShowingChat = false;

  bool _loadingMessages = false;

  bool _sendingMessage = false;

  bool _refreshingConversations = false;

  bool _refreshingPresence = false;

  bool _appInForeground = true;

  bool _realtimeConnected = false;

  String? _messageError;

  int? _demoConversationIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _conversations = List<BuyerConversationData>.from(widget.conversations);

    _activeSeller = _resolveInitialSeller();

    _replaceMessages(widget.initialMessages, notify: false);

    /*
     * On mobile, open directly into the chat only when a
     * specific seller was intentionally supplied.
     */
    _mobileShowingChat =
        _activeSeller != null &&
        (widget.initialSellerSlug != null || widget.initialSeller != null);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _initializeActiveConversation();
      _startPresencePolling();
    });
  }

  @override
  void didUpdateWidget(covariant MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool reconnectNeeded = false;

    if (oldWidget.conversations != widget.conversations) {
      final BuyerConversationData? previousActive = _activeSeller;

      _conversations = List<BuyerConversationData>.from(widget.conversations);

      final BuyerConversationData? resolved = _resolveUpdatedActiveSeller(
        previousActive,
      );

      if (resolved?.sellerId != previousActive?.sellerId) {
        _activeSeller = resolved;

        _messages = <BuyerMessageData>[];

        _seenMessageIds.clear();

        _messageError = null;

        reconnectNeeded = true;
      } else if (resolved != null) {
        _activeSeller = resolved;
      }
    }

    final bool sellerRequestChanged =
        oldWidget.initialSellerSlug != widget.initialSellerSlug ||
        oldWidget.initialSeller != widget.initialSeller;

    if (sellerRequestChanged) {
      final BuyerConversationData? requestedSeller = _resolveInitialSeller();

      if (requestedSeller?.sellerId != _activeSeller?.sellerId) {
        _activeSeller = requestedSeller;

        _messages = <BuyerMessageData>[];

        _seenMessageIds.clear();

        _messageError = null;

        reconnectNeeded = true;
      }

      _mobileShowingChat =
          requestedSeller != null &&
          (widget.initialSellerSlug != null || widget.initialSeller != null);
    }

    if (oldWidget.initialMessages != widget.initialMessages &&
        widget.initialMessages.isNotEmpty) {
      _replaceMessages(widget.initialMessages, notify: false);
    }

    if (oldWidget.messageStreamBuilder != widget.messageStreamBuilder) {
      reconnectNeeded = true;
    }

    if (reconnectNeeded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        final BuyerConversationData? seller = _activeSeller;

        if (seller == null) {
          _disconnectRealtime();
          return;
        }

        _initializeActiveConversation(forceLoad: _messages.isEmpty);
      });
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();

    _presenceTimer?.cancel();

    _messageSubscription?.cancel();

    _messageController.dispose();

    _messageScrollController.dispose();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    if (_appInForeground) {
      unawaited(_refreshPresenceAndReceipt());
    }
  }

  void _startPresencePolling() {
    if (widget.onPresenceHeartbeat == null &&
        widget.onRefreshConversationPresence == null) {
      return;
    }
    unawaited(_refreshPresenceAndReceipt());
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted ||
          !_appInForeground ||
          !TickerMode.valuesOf(context).enabled) {
        return;
      }
      unawaited(_refreshPresenceAndReceipt());
    });
  }

  Future<void> _refreshPresenceAndReceipt() async {
    if (_refreshingPresence || !mounted) return;
    _refreshingPresence = true;
    try {
      try {
        await widget.onPresenceHeartbeat?.call();
      } catch (_) {
        // Receipt polling can still work when a presence heartbeat fails.
      }

      final BuyerConversationData? seller = _activeSeller;
      final BuyerConversationPresenceRefreshCallback? refresh =
          widget.onRefreshConversationPresence;
      if (seller == null || seller.conversationId.isEmpty || refresh == null) {
        return;
      }

      final BuyerConversationPresenceData presence = await refresh(seller);
      if (!mounted || !_isActiveSeller(seller)) return;
      final DateTime? recipientReadAt = presence.recipientReadAt;
      setState(() {
        _activeSeller = seller.copyWith(
          isOnline: presence.isOnline,
          statusLabel: presence.isOnline ? 'Online' : 'Offline',
        );
        final int conversationIndex = _conversations.indexWhere(
          (BuyerConversationData current) => _sameSeller(current, seller),
        );
        if (conversationIndex >= 0) {
          _conversations[conversationIndex] = _conversations[conversationIndex]
              .copyWith(
                isOnline: presence.isOnline,
                statusLabel: presence.isOnline ? 'Online' : 'Offline',
              );
        }
        if (recipientReadAt != null) {
          _messages = _messages
              .map((BuyerMessageData message) {
                final DateTime? sentAt = message.sentAt;
                if (message.fromBuyer &&
                    sentAt != null &&
                    !sentAt.isAfter(recipientReadAt)) {
                  return message.copyWith(seenByRecipient: true);
                }
                return message;
              })
              .toList(growable: false);
        }
      });
    } catch (_) {
      // Keep the last known presence and receipt while the API reconnects.
    } finally {
      _refreshingPresence = false;
    }
  }

  BuyerConversationData? _resolveInitialSeller() {
    final BuyerConversationData? suppliedSeller = widget.initialSeller;

    if (suppliedSeller != null) {
      for (final BuyerConversationData seller in _conversations) {
        if (_sameSeller(seller, suppliedSeller)) {
          return seller.copyWith(
            orderContext: suppliedSeller.orderContext ?? seller.orderContext,
          );
        }
      }

      return suppliedSeller;
    }

    final String? requestedSlug = widget.initialSellerSlug?.trim();

    if (requestedSlug != null && requestedSlug.isNotEmpty) {
      for (final BuyerConversationData seller in _conversations) {
        if (seller.slug == requestedSlug) {
          return seller;
        }
      }

      /*
       * Important:
       *
       * Do NOT silently open the first conversation when
       * Product Details requested a seller that is not in
       * the list.
       *
       * The caller should provide initialSeller when
       * starting a brand-new conversation.
       */
      return null;
    }

    if (_conversations.isEmpty) {
      return null;
    }

    return _conversations.first;
  }

  BuyerConversationData? _resolveUpdatedActiveSeller(
    BuyerConversationData? previousActive,
  ) {
    if (previousActive != null) {
      for (final BuyerConversationData seller in _conversations) {
        if (_sameSeller(seller, previousActive)) {
          return seller.copyWith(
            orderContext: previousActive.orderContext ?? seller.orderContext,
          );
        }
      }

      final BuyerConversationData? supplied = widget.initialSeller;

      if (supplied != null && _sameSeller(supplied, previousActive)) {
        return supplied;
      }
    }

    return _resolveInitialSeller();
  }

  bool _sameSeller(BuyerConversationData a, BuyerConversationData b) {
    if (a.sellerId.isNotEmpty && b.sellerId.isNotEmpty) {
      return a.sellerId == b.sellerId;
    }

    final String aSlug = a.slug.trim().toLowerCase();
    final String bSlug = b.slug.trim().toLowerCase();
    if (aSlug.isNotEmpty && aSlug == bSlug) {
      return true;
    }

    final String aName = a.name.trim().toLowerCase();
    final String bName = b.name.trim().toLowerCase();
    return aName.isNotEmpty && aName == bName;
  }

  MessageProductReference? get _activeProductReference {
    final MessageProductReference? reference = widget.productReference;

    if (reference == null) {
      return null;
    }

    final BuyerConversationData? seller = _activeSeller;

    if (seller == null) {
      return null;
    }

    final BuyerConversationData? suppliedSeller = widget.initialSeller;

    if (suppliedSeller != null && !_sameSeller(seller, suppliedSeller)) {
      return null;
    }

    final String? requestedSlug = widget.initialSellerSlug;

    if (requestedSlug != null &&
        requestedSlug.isNotEmpty &&
        seller.slug != requestedSlug) {
      return null;
    }

    return reference;
  }

  void _replaceMessages(
    List<BuyerMessageData> messages, {
    required bool notify,
  }) {
    void apply() {
      _messages = List<BuyerMessageData>.from(messages);

      _seenMessageIds
        ..clear()
        ..addAll(
          messages
              .where((BuyerMessageData message) => message.id.trim().isNotEmpty)
              .map((BuyerMessageData message) => message.id),
        );
    }

    if (notify && mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  Future<void> _initializeActiveConversation({bool forceLoad = false}) async {
    final BuyerConversationData? seller = _activeSeller;

    if (seller == null) {
      await _disconnectRealtime();
      return;
    }

    if (seller.conversationId.isEmpty) {
      await _disconnectRealtime();
      _replaceMessages(const <BuyerMessageData>[], notify: true);
      return;
    }

    if ((forceLoad || _messages.isEmpty) && widget.onLoadMessages != null) {
      await _loadMessages(seller);
    }

    if (!mounted || !_isActiveSeller(seller)) {
      return;
    }

    await _connectRealtime(seller);

    _scheduleScrollToBottom();
  }

  Future<void> _selectConversation(BuyerConversationData seller) async {
    final bool alreadySelected = _isActiveSeller(seller);

    setState(() {
      _mobileShowingChat = true;

      _activeSeller = seller.copyWith(
        unread: 0,
        orderContext: alreadySelected
            ? _activeSeller?.orderContext ?? seller.orderContext
            : seller.orderContext,
      );

      _markConversationReadLocally(seller);

      if (!alreadySelected) {
        _messages = <BuyerMessageData>[];

        _seenMessageIds.clear();

        _messageError = null;

        _messageController.clear();
        _pendingAttachment = null;
      }
    });

    widget.onConversationSelected?.call(seller);

    if (alreadySelected) {
      _scheduleScrollToBottom();
      return;
    }

    await _disconnectRealtime();

    await _loadMessages(seller);

    if (!mounted || !_isActiveSeller(seller)) {
      return;
    }

    await _connectRealtime(seller);

    _scheduleScrollToBottom();
  }

  bool _isActiveSeller(BuyerConversationData seller) {
    final BuyerConversationData? active = _activeSeller;

    if (active == null) {
      return false;
    }

    return _sameSeller(active, seller);
  }

  void _markConversationReadLocally(BuyerConversationData seller) {
    final int index = _conversations.indexWhere(
      (BuyerConversationData current) => _sameSeller(current, seller),
    );

    if (index < 0) {
      return;
    }

    _conversations[index] = _conversations[index].copyWith(unread: 0);
  }

  Future<void> _loadMessages(BuyerConversationData seller) async {
    final LoadConversationMessagesCallback? loader = widget.onLoadMessages;

    if (loader == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _loadingMessages = true;

        _messageError = null;
      });
    }

    try {
      final List<BuyerMessageData> loaded = await loader(seller);

      if (!mounted || !_isActiveSeller(seller)) {
        return;
      }

      _replaceMessages(loaded, notify: true);

      setState(() {
        _markConversationReadLocally(seller);
      });

      _scheduleScrollToBottom();
    } catch (error) {
      if (!mounted || !_isActiveSeller(seller)) {
        return;
      }

      setState(() {
        _messageError = _errorText(error);
      });
    } finally {
      if (mounted && _isActiveSeller(seller)) {
        setState(() {
          _loadingMessages = false;
        });
      }
    }
  }

  Future<void> _connectRealtime(BuyerConversationData seller) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _messageSubscription?.cancel();

    _messageSubscription = null;

    if (mounted) {
      setState(() {
        _realtimeConnected = false;
      });
    }

    final ConversationMessageStreamBuilder? builder =
        widget.messageStreamBuilder;

    if (builder == null ||
        seller.conversationId.isEmpty ||
        !mounted ||
        !_isActiveSeller(seller)) {
      return;
    }

    try {
      final Stream<BuyerMessageData> stream = builder(seller);

      if (!mounted || !_isActiveSeller(seller)) {
        return;
      }

      setState(() {
        _realtimeConnected = true;
      });

      _messageSubscription = stream.listen(
        (BuyerMessageData message) {
          if (!mounted || !_isActiveSeller(seller)) {
            return;
          }

          _appendMessage(message);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!mounted || !_isActiveSeller(seller)) {
            return;
          }

          setState(() {
            _realtimeConnected = false;
          });

          _scheduleRealtimeReconnect(seller);
        },
        onDone: () {
          if (!mounted || !_isActiveSeller(seller)) {
            return;
          }

          setState(() {
            _realtimeConnected = false;
          });

          /*
           * Laravel SSE connections may intentionally
           * terminate after a period of time.
           *
           * Reconnect while this seller remains active.
           */
          _scheduleRealtimeReconnect(seller);
        },
        cancelOnError: true,
      );
    } catch (_) {
      if (!mounted || !_isActiveSeller(seller)) {
        return;
      }

      setState(() {
        _realtimeConnected = false;
      });

      _scheduleRealtimeReconnect(seller);
    }
  }

  void _scheduleRealtimeReconnect(BuyerConversationData seller) {
    if (widget.messageStreamBuilder == null ||
        !mounted ||
        !_isActiveSeller(seller)) {
      return;
    }

    _reconnectTimer?.cancel();

    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_isActiveSeller(seller)) {
        return;
      }

      _connectRealtime(seller);
    });
  }

  Future<void> _disconnectRealtime() async {
    _reconnectTimer?.cancel();

    _reconnectTimer = null;

    await _messageSubscription?.cancel();

    _messageSubscription = null;

    if (mounted && _realtimeConnected) {
      setState(() {
        _realtimeConnected = false;
      });
    }
  }

  void _appendMessage(BuyerMessageData message) {
    if (message.body.trim().isEmpty && !message.hasAttachment) {
      return;
    }

    final String id = message.id.trim();

    if (id.isNotEmpty && _seenMessageIds.contains(id)) {
      return;
    }

    setState(() {
      if (id.isNotEmpty) {
        _seenMessageIds.add(id);
      }

      _messages.add(message);

      _updateActiveConversationPreview(message);
    });

    _scheduleScrollToBottom();
  }

  void _updateActiveConversationPreview(BuyerMessageData message) {
    final BuyerConversationData? seller = _activeSeller;

    if (seller == null) {
      return;
    }

    final String preview =
        message.hasAttachment &&
            (message.body.trim().isEmpty || message.isAttachmentPlaceholder)
        ? 'Photo'
        : message.body;

    final int index = _conversations.indexWhere(
      (BuyerConversationData current) => _sameSeller(current, seller),
    );

    if (index >= 0) {
      _conversations[index] = _conversations[index].copyWith(
        lastMessage: preview,
        time: message.time,
        unread: 0,
      );

      return;
    }

    /*
     * A new seller conversation may not yet have been
     * included in the original conversations list.
     *
     * Once Laravel successfully returns a message for that
     * seller, it is safe to display the local conversation
     * preview.
     */
    _conversations.insert(
      0,
      seller.copyWith(lastMessage: preview, time: message.time, unread: 0),
    );
  }

  Future<void> _pickAttachment() async {
    if (_pickingAttachment || _sendingMessage) {
      return;
    }

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.photo_camera_outlined, color: _maroon),
                  title: Text(
                    'Take Photo',
                    style: TextStyle(color: _text, fontWeight: FontWeight.w800),
                  ),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: Icon(Icons.photo_library_outlined, color: _maroon),
                  title: Text(
                    'Choose Photo',
                    style: TextStyle(color: _text, fontWeight: FontWeight.w800),
                  ),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    setState(() {
      _pickingAttachment = true;
    });

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (!mounted || image == null) {
        return;
      }

      setState(() {
        _pendingAttachment = image;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to select attachment: ${_errorText(error)}',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _pickingAttachment = false;
        });
      }
    }
  }

  void _removeAttachment() {
    if (_sendingMessage) {
      return;
    }

    setState(() {
      _pendingAttachment = null;
    });
  }

  Future<void> _sendDemoMessage(_DemoConversation conversation) async {
    if (_sendingMessage) {
      return;
    }

    final String body = _messageController.text.trim();
    final XFile? attachment = _pendingAttachment;

    if (body.isEmpty && attachment == null) {
      return;
    }

    if (body.length > widget.maxMessageLength) {
      _showMessage(
        'Messages cannot exceed ${widget.maxMessageLength} characters.',
        error: true,
      );
      return;
    }

    final TimeOfDay now = TimeOfDay.now();
    final String time = now.format(context);

    setState(() {
      final List<_DemoMessage> sent = _demoSentMessages.putIfAbsent(
        conversation.name,
        () => <_DemoMessage>[],
      );

      sent.add(
        _DemoMessage(
          body: body,
          time: time,
          fromBuyer: true,
          attachmentPath: attachment?.path,
        ),
      );

      _messageController.clear();
      _pendingAttachment = null;
    });

    _showMessage('Preview only — this message is not saved to Laravel.');
  }

  Future<void> _sendMessage() async {
    final BuyerConversationData? seller = _activeSeller;

    if (seller == null || _sendingMessage) {
      return;
    }

    final String body = _messageController.text.trim();

    final XFile? attachment = _pendingAttachment;

    if (body.isEmpty && attachment == null) {
      return;
    }

    if (body.length > widget.maxMessageLength) {
      _showMessage(
        'Messages cannot exceed ${widget.maxMessageLength} characters.',
        error: true,
      );

      return;
    }

    final SendBuyerMessageCallback? sender = widget.onSendMessage;

    final SendBuyerAttachmentCallback? attachmentSender =
        widget.onSendAttachment;

    if (attachment == null && sender == null) {
      _showMessage('Messaging is not connected to Laravel.', error: true);

      return;
    }

    if (attachment != null && attachmentSender == null) {
      _showMessage(
        'Attachment sending is not connected to Laravel.',
        error: true,
      );

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _sendingMessage = true;
    });

    try {
      /*
       * Important:
       *
       * Do NOT append an optimistic/fake message here.
       *
       * Wait for Laravel to successfully create the
       * message and return the real message object.
       */
      final BuyerMessageData sent;

      if (attachment != null) {
        sent = await attachmentSender!(seller, body, attachment.path);
      } else {
        sent = await sender!(seller, body);
      }

      if (!mounted || !_isActiveSeller(seller)) {
        return;
      }

      final bool createdConversation =
          seller.conversationId.isEmpty && sent.conversationId.isNotEmpty;

      if (sent.conversationId.isNotEmpty &&
          sent.conversationId != seller.conversationId) {
        setState(() {
          _activeSeller = seller.copyWith(conversationId: sent.conversationId);
        });
      }

      _appendMessage(sent);

      _messageController.clear();
      await _refreshConversations();

      // A Contact seller entry can start without an existing conversation.
      // The first successful send creates it, so attach the live reply stream
      // now that Laravel has returned its conversation ID.
      final BuyerConversationData? activeSeller = _activeSeller;
      if (createdConversation &&
          mounted &&
          activeSeller != null &&
          activeSeller.conversationId.isNotEmpty) {
        await _connectRealtime(activeSeller);
      }
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _sendingMessage = false;
        });
      }
    }
  }

  Future<void> _refreshConversations() async {
    final RefreshConversationsCallback? refresher =
        widget.onRefreshConversations;

    if (refresher == null || _refreshingConversations) {
      return;
    }

    setState(() {
      _refreshingConversations = true;
    });

    try {
      final List<BuyerConversationData> refreshed = await refresher();

      if (!mounted) {
        return;
      }

      final BuyerConversationData? previousActive = _activeSeller;

      BuyerConversationData? updatedActive;

      if (previousActive != null) {
        for (final BuyerConversationData seller in refreshed) {
          if (_sameSeller(seller, previousActive)) {
            updatedActive = seller.copyWith(
              orderContext: previousActive.orderContext,
            );
            break;
          }
        }
      }

      /*
       * Preserve a direct Product Details conversation
       * even when it has not appeared in the server's
       * normal conversation list yet.
       */
      if (updatedActive == null &&
          previousActive != null &&
          widget.initialSeller != null &&
          _sameSeller(previousActive, widget.initialSeller!)) {
        updatedActive = previousActive;
      }

      updatedActive ??= refreshed.isEmpty ? null : refreshed.first;

      final bool changedSeller =
          updatedActive?.sellerId != previousActive?.sellerId ||
          updatedActive?.conversationId != previousActive?.conversationId;

      setState(() {
        _conversations = List<BuyerConversationData>.from(refreshed);

        _activeSeller = updatedActive;

        if (changedSeller) {
          _messages = <BuyerMessageData>[];

          _seenMessageIds.clear();

          _messageError = null;
        }
      });

      if (changedSeller) {
        await _disconnectRealtime();

        if (updatedActive != null) {
          await _loadMessages(updatedActive);

          if (mounted && _isActiveSeller(updatedActive)) {
            await _connectRealtime(updatedActive);
          }
        }
      }
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _refreshingConversations = false;
        });
      }
    }
  }

  Future<void> _refreshChat() async {
    final BuyerConversationData? seller = _activeSeller;

    if (seller == null) {
      return;
    }

    if (widget.onLoadMessages != null) {
      await _loadMessages(seller);

      if (!mounted || !_isActiveSeller(seller)) {
        return;
      }

      await _connectRealtime(seller);

      return;
    }

    await _refreshConversations();
  }

  bool _bottomScrollScheduled = false;

  void _scheduleScrollToBottom() {
    if (_bottomScrollScheduled) return;
    _bottomScrollScheduled = true;
    void settle(Duration _) {
      if (!mounted || !_messageScrollController.hasClients) {
        _bottomScrollScheduled = false;
        return;
      }
      final position = _messageScrollController.position;
      if (position.isScrollingNotifier.value ||
          (position.maxScrollExtent - position.pixels).abs() < 1) {
        _bottomScrollScheduled = false;
        return;
      }
      _messageScrollController.jumpTo(position.maxScrollExtent);
      // A lazy list refines its estimated extent after laying out the last rows.
      WidgetsBinding.instance.addPostFrameCallback(settle);
    }

    WidgetsBinding.instance.addPostFrameCallback(settle);
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? _danger : _maroonDark,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
  }

  String _errorText(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= _desktopBreakpoint;

            if (wide) {
              return _buildWideLayout();
            }

            return _buildMobileLayout();
          },
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Column(
      children: [
        _buildPageHeader(),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _border),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _maroon.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(width: 320, child: _buildConversationPanel()),

                  VerticalDivider(width: 1, thickness: 1, color: _border),

                  Expanded(
                    child:
                        _conversations.isEmpty &&
                            widget.showPreviewWhenEmpty &&
                            _demoConversationIndex != null
                        ? _buildDemoChatPanel(
                            _demoConversations[_demoConversationIndex!],
                            mobile: false,
                          )
                        : _buildChatPanel(mobile: false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    if (_conversations.isEmpty &&
        widget.showPreviewWhenEmpty &&
        _demoConversationIndex != null) {
      return _buildDemoChatPanel(
        _demoConversations[_demoConversationIndex!],
        mobile: true,
      );
    }

    if (_mobileShowingChat && _activeSeller != null) {
      return _buildChatPanel(mobile: true);
    }

    return Column(
      children: [
        _buildPageHeader(),

        Expanded(child: _buildConversationPanel(mobile: true)),
      ],
    );
  }

  Widget _buildPageHeader() => Container(
    width: double.infinity,
    color: _background,
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: _backgroundSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, color: _maroon, size: 6),
              const SizedBox(width: 6),
              Text(
                'COMMUNICATION',
                style: TextStyle(
                  color: _maroonDark,
                  fontSize: 9,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Messages',
          style: TextStyle(
            color: _text,
            fontFamily: 'serif',
            fontSize: 38,
            height: 1.05,
            letterSpacing: -1.1,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Keep conversations with sellers in one polished LIKHAE inbox',
          style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
        ),
      ],
    ),
  );

  Widget _buildConversationPanel({bool mobile = false}) {
    return Container(
      color: _surface,
      child: Column(
        children: [
          if (!mobile)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
              decoration: BoxDecoration(
                color: _surface,
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Text(
                'Conversations',
                style: TextStyle(
                  color: _text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

          Expanded(
            child: RefreshIndicator(
              color: _maroon,
              onRefresh: _refreshConversations,
              child: _conversations.isEmpty && widget.showPreviewWhenEmpty
                  ? _buildDemoConversationList()
                  : _conversations.isEmpty
                  ? _buildEmptyConversationList()
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: mobile
                          ? const EdgeInsets.fromLTRB(14, 12, 14, 110)
                          : EdgeInsets.zero,
                      itemCount: _conversations.length,
                      separatorBuilder: (BuildContext context, int index) {
                        return mobile
                            ? const SizedBox(height: 8)
                            : Divider(height: 1, thickness: 1, color: _border);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        final BuyerConversationData conversation =
                            _conversations[index];

                        final bool selected =
                            _activeSeller != null &&
                            _sameSeller(_activeSeller!, conversation);

                        return _ConversationTile(
                          conversation: conversation,
                          selected: selected,
                          onTap: () {
                            _selectConversation(conversation);
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<_DemoConversation> _demoConversations = <_DemoConversation>[
    _DemoConversation(
      name: 'Aurelia Jewelry',
      lastMessage: 'Yes, the pearl necklace is still available.',
      time: '2m',
      unread: 2,
      status: 'Seller • Preview conversation',
      messages: <_DemoMessage>[
        _DemoMessage(
          body:
              'Hi! Is the Gold-Plated Pearl Pendant Necklace still available?',
          time: '7:02 PM',
          fromBuyer: true,
        ),
        _DemoMessage(
          body:
              'Hello! Yes, it is still available. The Gold finish is currently in stock.',
          time: '7:03 PM',
          fromBuyer: false,
        ),
        _DemoMessage(
          body: 'Nice. How many pieces are available right now?',
          time: '7:04 PM',
          fromBuyer: true,
        ),
        _DemoMessage(
          body:
              'We currently have 8 pieces available. You can choose the quantity on the product page before adding it to your cart.',
          time: '7:05 PM',
          fromBuyer: false,
        ),
        _DemoMessage(
          body: 'Okay, thank you! I will check out the product.',
          time: '7:06 PM',
          fromBuyer: true,
        ),
      ],
    ),
    _DemoConversation(
      name: 'Mira Studio',
      lastMessage: 'We can prepare the item today.',
      time: '18m',
      unread: 1,
      status: 'Seller • Preview conversation',
      messages: <_DemoMessage>[
        _DemoMessage(
          body: 'Hello, is this item available in the selected variation?',
          time: '6:41 PM',
          fromBuyer: true,
        ),
        _DemoMessage(
          body: 'Yes, that variation is available.',
          time: '6:43 PM',
          fromBuyer: false,
        ),
        _DemoMessage(
          body: 'If I order today, when can it be prepared?',
          time: '6:45 PM',
          fromBuyer: true,
        ),
        _DemoMessage(
          body:
              'We can prepare the item today. Once the order is confirmed, it will follow the normal pickup and delivery process.',
          time: '6:46 PM',
          fromBuyer: false,
        ),
      ],
    ),
    _DemoConversation(
      name: 'Page & Pixel Books',
      lastMessage: 'Softcover is available.',
      time: '1h',
      unread: 0,
      status: 'Seller • Preview conversation',
      messages: <_DemoMessage>[
        _DemoMessage(
          body:
              'Hi, do you still have the Creative Journaling Workbook in softcover?',
          time: '6:03 PM',
          fromBuyer: true,
        ),
        _DemoMessage(
          body: 'Hi! Yes, softcover is available.',
          time: '6:05 PM',
          fromBuyer: false,
        ),
        _DemoMessage(
          body: 'Thank you. I will add it to my cart.',
          time: '6:06 PM',
          fromBuyer: true,
        ),
      ],
    ),
    _DemoConversation(
      name: 'Craft & Clay Studio',
      lastMessage: 'Thank you for your message.',
      time: 'Yesterday',
      unread: 0,
      status: 'Seller • Preview conversation',
      messages: <_DemoMessage>[
        _DemoMessage(
          body: 'Hello! Can I ask about the material used for this product?',
          time: 'Yesterday • 4:21 PM',
          fromBuyer: true,
        ),
        _DemoMessage(
          body:
              'Of course. Please send the product you are asking about and we will confirm the listed specifications.',
          time: 'Yesterday • 4:24 PM',
          fromBuyer: false,
        ),
        _DemoMessage(
          body: 'Got it. Thank you for your message.',
          time: 'Yesterday • 4:25 PM',
          fromBuyer: true,
        ),
      ],
    ),
  ];

  Widget _buildEmptyConversationList() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 90, 24, 120),
      children: <Widget>[
        Icon(Icons.forum_outlined, size: 54, color: _maroon),
        SizedBox(height: 18),
        Text(
          'No conversations yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _text,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Messages from sellers will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildDemoConversationList() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
      itemCount: _demoConversations.length + 1,
      separatorBuilder: (BuildContext context, int index) {
        return const SizedBox(height: 8);
      },
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _backgroundSoft,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.visibility_outlined, color: _maroon, size: 19),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Preview mode — sample messages are not saved to Laravel.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final int conversationIndex = index - 1;

        final _DemoConversation conversation =
            _demoConversations[conversationIndex];

        return _DemoConversationTile(
          conversation: conversation,
          onTap: () {
            setState(() {
              _demoConversationIndex = conversationIndex;
              _messageController.clear();
              _pendingAttachment = null;
            });
          },
        );
      },
    );
  }

  Widget _buildDemoChatPanel(
    _DemoConversation conversation, {
    required bool mobile,
  }) {
    return Container(
      color: context.messagesChatBackgroundSoft,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              mobile ? 8 : 18,
              10,
              mobile ? 8 : 18,
              10,
            ),
            constraints: const BoxConstraints(minHeight: 64),
            decoration: BoxDecoration(
              color: context.messagesChatSurface,
              border: Border(
                bottom: BorderSide(color: context.messagesChatBorder),
              ),
            ),
            child: Row(
              children: [
                if (mobile)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Tooltip(
                      message: 'Back to chats',
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _demoConversationIndex = null;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          fixedSize: const Size(34, 34),
                          padding: EdgeInsets.zero,
                          foregroundColor: context.messagesChatAccent,
                          backgroundColor: context.messagesChatSurface,
                          side: BorderSide(color: context.messagesChatBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 17),
                      ),
                    ),
                  ),

                _DemoAvatar(size: mobile ? 36 : 42),

                SizedBox(width: mobile ? 8 : 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.messagesChatText,
                          fontSize: mobile ? 12 : 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        conversation.status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.messagesChatMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: context.messagesChatBackgroundSoft,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: context.messagesChatBorder),
                  ),
                  child: Text(
                    'PREVIEW',
                    style: TextStyle(
                      color: context.messagesChatAccent,
                      fontSize: 10,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Builder(
              builder: (BuildContext context) {
                final List<_DemoMessage> messages = <_DemoMessage>[
                  ...conversation.messages,
                  ...(_demoSentMessages[conversation.name] ??
                      const <_DemoMessage>[]),
                ];

                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: Theme.of(context).brightness == Brightness.dark
                          ? const <Color>[
                              Color(0xFF161210),
                              Color(0xFF1E1A17),
                            ]
                          : const <Color>[
                              Color(0xFFFBF7F2),
                              Color(0xFFF6EFE7),
                            ],
                    ),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    itemCount: messages.length + 1,
                    itemBuilder: (BuildContext context, int index) {
                      if (index == 0) {
                        return Center(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 18),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: context.messagesChatSurface.withValues(
                                alpha: 0.88,
                              ),
                              border: Border.all(
                                color: context.messagesChatBorder,
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'Conversation',
                              style: TextStyle(
                                color: context.messagesChatMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      }

                      return _DemoMessageBubble(
                        message: messages[index - 1],
                        sellerName: conversation.name,
                      );
                    },
                  ),
                );
              },
            ),
          ),

          _buildDemoComposer(conversation),
        ],
      ),
    );
  }

  Widget _buildDemoComposer(_DemoConversation conversation) {
    return _buildMessageBox(
      hintText: 'Type your message to ${conversation.name}...',
      onSend: () => _sendDemoMessage(conversation),
    );
  }

  Widget _buildChatPanel({required bool mobile}) {
    final BuyerConversationData? seller = _activeSeller;

    if (seller == null) {
      return _buildNoSelectedConversation();
    }

    return Container(
      color: context.messagesChatBackground,
      child: Column(
        children: [
          _buildChatHeader(seller, mobile: mobile),

          if (seller.orderContext != null)
            _OrderContextStrip(orderContext: seller.orderContext!),

          Expanded(child: _buildMessageStream(seller, mobile: mobile)),

          if (widget.messageStreamBuilder != null)
            _LiveChatStatus(
              sellerName: seller.name,
              connected: _realtimeConnected,
            ),

          _buildComposer(seller),
        ],
      ),
    );
  }

  Widget _buildChatHeader(
    BuyerConversationData seller, {
    required bool mobile,
  }) {
    final String? statusLabel = seller.statusLabel?.trim().isNotEmpty == true
        ? seller.statusLabel!.trim()
        : seller.isOnline == null
        ? null
        : seller.isOnline == true
        ? 'Online'
        : 'Offline';

    return Container(
      padding: EdgeInsets.fromLTRB(mobile ? 8 : 18, 10, mobile ? 8 : 18, 10),
      constraints: const BoxConstraints(minHeight: 64),
      decoration: BoxDecoration(
        color: context.messagesChatSurface,
        border: Border(bottom: BorderSide(color: context.messagesChatBorder)),
      ),
      child: Row(
        children: [
          if (mobile)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'Back to chats',
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _mobileShowingChat = false;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    fixedSize: const Size(34, 34),
                    padding: EdgeInsets.zero,
                    foregroundColor: context.messagesChatAccent,
                    backgroundColor: context.messagesChatSurface,
                    side: BorderSide(color: context.messagesChatBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 17),
                ),
              ),
            ),

          _SellerAvatar(
            seller: seller,
            size: mobile ? 36 : 42,
            showPresence: false,
          ),

          SizedBox(width: mobile ? 8 : 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seller.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.messagesChatText,
                    fontSize: mobile ? 12 : 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                if (statusLabel != null) ...[
                  const SizedBox(height: 3),

                  _SellerStatus(
                    label: statusLabel,
                    isOnline: seller.isOnline,
                  ),
                ],
              ],
            ),
          ),

          if (widget.onViewStore != null) ...[
            SizedBox(width: mobile ? 5 : 10),
            SizedBox(
              height: 36,
              child: OutlinedButton(
                onPressed: () => widget.onViewStore!(seller),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.messagesChatAccent,
                  backgroundColor: context.messagesChatSurface,
                  side: const BorderSide(color: Color(0xFFC19771)),
                  padding: EdgeInsets.symmetric(horizontal: mobile ? 9 : 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: Text(
                  mobile ? 'Store' : 'View Store',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
          if (seller.conversationId.trim().isNotEmpty) ...[
            SizedBox(width: mobile ? 2 : 6),
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                tooltip: 'Smart messaging help',
                onPressed: () => showSmartMessagingHelp(
                  context,
                  workspace: 'buyer',
                  conversationId: seller.conversationId,
                  productId: _activeProductReference?.productId,
                ),
                style: IconButton.styleFrom(
                  foregroundColor: context.messagesChatAccent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                    side: BorderSide(color: context.messagesChatBorder),
                  ),
                ),
                icon: const Icon(Icons.support_agent_outlined, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageStream(
    BuyerConversationData seller, {
    required bool mobile,
  }) {
    if (_loadingMessages && _messages.isEmpty) {
      return Center(
        child: SizedBox(
          width: 25,
          height: 25,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.messagesChatAccent,
          ),
        ),
      );
    }

    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const <Color>[Color(0xFF161210), Color(0xFF1E1A17)]
              : const <Color>[Color(0xFFFBF7F2), Color(0xFFF6EFE7)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!dark)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.82, -0.88),
                    radius: 1.25,
                    colors: <Color>[
                      const Color(0xFFC19771).withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          RefreshIndicator(
            color: context.messagesChatAccent,
            onRefresh: _refreshChat,
            child: ListView.builder(
        controller: _messageScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          mobile ? 12 : 20,
          mobile ? 12 : 20,
          mobile ? 12 : 20,
          16,
        ),
        itemCount: _messages.length + 1,
        itemBuilder: (context, index) {
          if (index > 0) {
            final int messageIndex = index - 1;
            final int latestBuyerMessageIndex = _messages.lastIndexWhere(
              (BuyerMessageData message) => message.fromBuyer,
            );
            final bool sellerRepliedAfterLatestBuyerMessage =
                messageIndex == latestBuyerMessageIndex &&
                _messages
                    .skip(messageIndex + 1)
                    .any((BuyerMessageData message) => !message.fromBuyer);
            return _MessageBubble(
              message: _messages[messageIndex],
              seller: seller,
              showReceipt: messageIndex == latestBuyerMessageIndex,
              hasBeenSeen:
                  _messages[messageIndex].seenByRecipient == true ||
                  sellerRepliedAfterLatestBuyerMessage,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.messagesChatSurface.withValues(alpha: 0.88),
                    border: Border.all(color: context.messagesChatBorder),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Conversation',
                    style: TextStyle(
                      color: context.messagesChatMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              if (_activeProductReference != null) ...[
                const SizedBox(height: 4),

                _ProductInquiryCard(
                  product: _activeProductReference!,
                  onTap: widget.onProductReferenceSelected == null
                      ? null
                      : () {
                          widget.onProductReferenceSelected!(
                            _activeProductReference!,
                          );
                        },
                ),
              ],

              if (_messageError != null) ...[
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkSurfaceSoft
                        : AppTheme.resolve(
                            context,
                            const Color(0xFFFCECE7),
                            fill: true,
                          ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.darkBorderStrong
                          : AppTheme.resolve(context, const Color(0xFFEBC9C0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: _danger,
                        size: 18,
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          _messageError!,
                          style: TextStyle(color: _danger, fontSize: 12),
                        ),
                      ),

                      TextButton(
                        onPressed: _refreshChat,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ],

              if (_messages.isEmpty) ...[
                const SizedBox(height: 35),

                Icon(
                  Icons.forum_outlined,
                  size: 42,
                  color: context.messagesTan,
                ),

                const SizedBox(height: 11),

                Text(
                  'No messages yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.messagesChatText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Send the first message to ${seller.name}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.messagesChatMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          );
            },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuyerConversationData seller) {
    return _buildMessageBox(
      hintText: 'Type your message to ${seller.name}...',
      onSend: _sendMessage,
    );
  }

  Widget _buildMessageBox({
    required String hintText,
    required Future<void> Function() onSend,
  }) {
    final XFile? attachment = _pendingAttachment;

    return Container(
      // BuyerNavigationFrame already reserves space for the floating bottom
      // navigation. Adding another clearance here creates the large empty
      // gap visible between the composer and the navigation bar.
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: context.messagesChatSurface,
        border: Border(top: BorderSide(color: context.messagesChatBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (attachment != null) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.messagesChatBackgroundSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.messagesChatBorder),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.file(
                        File(attachment.path),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (
                              BuildContext context,
                              Object error,
                              StackTrace? stackTrace,
                            ) {
                              return Container(
                                width: 48,
                                height: 48,
                                color: context.messagesChatSurface,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.image_outlined,
                                  color: context.messagesChatMutedSoft,
                                ),
                              );
                            },
                      ),
                    ),

                    const SizedBox(width: 9),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Photo attachment',
                            style: TextStyle(
                              color: _text,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            attachment.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.messagesChatMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      tooltip: 'Remove attachment',
                      onPressed: _sendingMessage ? null : _removeAttachment,
                      icon: Icon(Icons.close_rounded, color: _muted),
                    ),
                  ],
                ),
              ),
            ],

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    tooltip: 'Attach photo',
                    onPressed: _sendingMessage || _pickingAttachment
                        ? null
                        : _pickAttachment,
                    style: IconButton.styleFrom(
                      backgroundColor: context.messagesChatSurface,
                      foregroundColor: context.messagesChatAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                        side: BorderSide(color: context.messagesChatBorder),
                      ),
                    ),
                    icon: _pickingAttachment
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            color: context.messagesChatAccent,
                            ),
                          )
                        : const Icon(Icons.attach_file_rounded, size: 20),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_sendingMessage,
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: widget.maxMessageLength,
                    onSubmitted: (_) {
                      if (!_sendingMessage) {
                        onSend();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: TextStyle(
                        color: context.messagesChatMutedSoft,
                        fontSize: 12,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: context.messagesChatSurface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: context.messagesChatBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: context.messagesChatBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFC19771),
                          width: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                SizedBox(
                  height: 42,
                  child: FilledButton.icon(
                    onPressed: _sendingMessage ? null : onSend,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(88, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: context.messagesChatAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _sendingMessage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: const Text(
                      'Send',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSelectedConversation() {
    final bool requestedSellerMissing =
        widget.initialSellerSlug != null &&
        widget.initialSeller == null &&
        !_conversations.any(
          (BuyerConversationData seller) =>
              seller.slug == widget.initialSellerSlug,
        );

    return Container(
      color: _backgroundSoft,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 55, color: _tan),

              const SizedBox(height: 14),

              Text(
                requestedSellerMissing
                    ? 'Seller conversation unavailable'
                    : 'No conversation selected',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _text,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                requestedSellerMissing
                    ? 'Provide the seller information when starting a new conversation from Product Details.'
                    : 'Select a conversation to start chatting.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 12.5, height: 1.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoConversation {
  final String name;
  final String lastMessage;
  final String time;
  final int unread;
  final String status;
  final List<_DemoMessage> messages;

  const _DemoConversation({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.status,
    required this.messages,
  });
}

class _DemoMessage {
  final String body;
  final String time;
  final bool fromBuyer;
  final String? attachmentPath;

  const _DemoMessage({
    required this.body,
    required this.time,
    required this.fromBuyer,
    this.attachmentPath,
  });
}

class _DemoConversationTile extends StatelessWidget {
  final _DemoConversation conversation;
  final VoidCallback onTap;

  const _DemoConversationTile({
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.messagesSurface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _DemoAvatar(size: 44),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.messagesText,
                              fontSize: 14,
                              fontWeight: conversation.unread > 0
                                  ? FontWeight.w800
                                  : FontWeight.w800,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Text(
                          conversation.time,
                          style: TextStyle(
                            color: context.messagesFaint,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.messagesMuted,
                              fontSize: 12.5,
                              fontWeight: conversation.unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),

                        if (conversation.unread > 0) ...[
                          const SizedBox(width: 8),

                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 21,
                              minHeight: 21,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: context.messagesAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${conversation.unread}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoMessageBubble extends StatelessWidget {
  final _DemoMessage message;
  final String sellerName;

  const _DemoMessageBubble({required this.message, required this.sellerName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Align(
        alignment: message.fromBuyer
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.94,
          ),
          child: message.fromBuyer
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [_buildBubble(context), _buildMeta(context)],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DemoAvatar(size: 28),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 1, bottom: 6),
                            child: Text(
                              sellerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.messagesChatText,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _buildBubble(context),
                          _buildMeta(context),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.only(
      topLeft: Radius.circular(message.fromBuyer ? 18 : 6),
      topRight: Radius.circular(message.fromBuyer ? 6 : 18),
      bottomLeft: const Radius.circular(18),
      bottomRight: const Radius.circular(18),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: message.fromBuyer ? null : context.messagesChatSurface,
        gradient: message.fromBuyer
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  context.messagesChatAccent,
                  context.messagesChatAccentLight,
                ],
              )
            : null,
        border: Border.all(
          color: message.fromBuyer
              ? context.messagesChatAccent
              : context.messagesChatBorder,
        ),
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: context.messagesChatAccent.withValues(
              alpha: message.fromBuyer ? 0.16 : 0.055,
            ),
            blurRadius: message.fromBuyer ? 24 : 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.attachmentPath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(message.attachmentPath!),
                width: 220,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? stackTrace) {
                      return const SizedBox.shrink();
                    },
              ),
            ),
            if (message.body.trim().isNotEmpty) const SizedBox(height: 8),
          ],
          if (message.body.trim().isNotEmpty)
            Text(
              message.body,
              style: TextStyle(
                color: message.fromBuyer
                    ? Colors.white
                    : context.messagesChatText,
                fontSize: 12,
                height: 1.65,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMeta(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message.time,
        style: TextStyle(
          color: message.fromBuyer
              ? const Color(0xFFD6A58D)
              : context.messagesChatMutedSoft,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DemoAvatar extends StatelessWidget {
  final double size;

  const _DemoAvatar({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.messagesSurface,
        border: Border.all(color: context.messagesBorder, width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.messagesAccent.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _MessagesAvatarMark(
        isPerson: false,
        size: size * 0.62,
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final BuyerConversationData conversation;

  final bool selected;

  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkSurfaceStrong
                : AppTheme.resolve(context, const Color(0xFFF3E4DE), fill: true)
          : context.messagesSurface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SellerAvatar(seller: conversation, size: 44),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.messagesText,
                              fontSize: 13.5,
                              fontWeight: conversation.unread > 0
                                  ? FontWeight.w800
                                  : FontWeight.w800,
                            ),
                          ),
                        ),

                        if (conversation.time.trim().isNotEmpty) ...[
                          const SizedBox(width: 6),

                          Text(
                            conversation.time,
                            style: TextStyle(
                              color: context.messagesFaint,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.lastMessage.trim().isEmpty
                                ? 'Start a conversation with this seller.'
                                : conversation.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.messagesMuted,
                              fontSize: 12,
                              fontWeight: conversation.unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),

                        if (conversation.unread > 0) ...[
                          const SizedBox(width: 7),

                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: context.messagesAccent,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              conversation.unread > 99
                                  ? '99+'
                                  : '${conversation.unread}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final BuyerMessageData message;
  final BuyerConversationData seller;
  final bool showReceipt;
  final bool hasBeenSeen;

  const _MessageBubble({
    required this.message,
    required this.seller,
    required this.showReceipt,
    required this.hasBeenSeen,
  });

  @override
  Widget build(BuildContext context) {
    if (message.body.trim().isEmpty && !message.hasAttachment) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double rowMaxWidth =
            constraints.maxWidth * (constraints.maxWidth < 600 ? 0.94 : 0.82);

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Align(
            alignment: message.fromBuyer
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: rowMaxWidth),
              child: message.fromBuyer
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [_buildBubble(context), _buildMeta(context)],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SellerAvatar(
                          seller: seller,
                          size: 28,
                          showPresence: false,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 1,
                                  bottom: 6,
                                ),
                                child: Text(
                                  seller.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.messagesChatText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              _buildBubble(context),
                              _buildMeta(context),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBubble(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.only(
      topLeft: Radius.circular(message.fromBuyer ? 18 : 6),
      topRight: Radius.circular(message.fromBuyer ? 6 : 18),
      bottomLeft: const Radius.circular(18),
      bottomRight: const Radius.circular(18),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: message.fromBuyer ? null : context.messagesChatSurface,
        gradient: message.fromBuyer
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  context.messagesChatAccent,
                  context.messagesChatAccentLight,
                ],
              )
            : null,
        border: Border.all(
          color: message.fromBuyer
              ? context.messagesChatAccent
              : context.messagesChatBorder,
        ),
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.messagesChatAccent.withValues(
              alpha: message.fromBuyer ? 0.16 : 0.055,
            ),
            blurRadius: message.fromBuyer ? 24 : 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: message.fromBuyer
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (message.hasAttachment) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _MessageAttachmentImage(
                AppConfig.resolveMediaUrl(message.attachmentUrl!),
              ),
            ),
            if (message.body.trim().isNotEmpty &&
                !message.isAttachmentPlaceholder)
              const SizedBox(height: 8),
          ],
          if (message.body.trim().isNotEmpty &&
              !message.isAttachmentPlaceholder)
            Text(
              message.body,
              style: TextStyle(
                color: message.fromBuyer
                    ? Colors.white
                    : context.messagesChatText,
                fontSize: 12,
                height: 1.65,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMeta(BuildContext context) {
    final bool showStatus = message.fromBuyer && showReceipt;
    final String receiptLabel = hasBeenSeen
        ? 'Seen'
        : seller.isOnline == true
        ? 'Delivered'
        : 'Sent';

    if (message.time.trim().isEmpty && !showStatus) {
      return const SizedBox.shrink();
    }

    final Color metaColor = message.fromBuyer
        ? const Color(0xFFD6A58D)
        : context.messagesChatMutedSoft;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.time.trim().isNotEmpty)
            Text(
              message.time,
              style: TextStyle(
                color: metaColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (showStatus) ...[
            if (message.time.trim().isNotEmpty) const SizedBox(width: 7),
            Text(
              receiptLabel,
              style: TextStyle(
                color: metaColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (hasBeenSeen) ...[
              const SizedBox(width: 4),
              _ReceiptAvatar(seller: seller),
            ],
          ],
        ],
      ),
    );
  }
}

class _ReceiptAvatar extends StatelessWidget {
  final BuyerConversationData seller;

  const _ReceiptAvatar({required this.seller});

  @override
  Widget build(BuildContext context) {
    final String? url = seller.avatarUrl?.trim();
    final String identity = '${seller.name} ${seller.slug} ${seller.sellerId}'
        .toLowerCase();
    final bool isPerson =
        identity.contains('support') || identity.contains('assistant');

    Widget fallback() => Center(
      child: _MessagesAvatarMark(isPerson: isPerson, size: 11),
    );

    return Container(
      width: 16,
      height: 16,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.messagesBackgroundSoft,
      ),
      child: url == null || url.isEmpty
          ? fallback()
          : SizedNetworkImage(
              url: AppConfig.resolveMediaUrl(url),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback(),
            ),
    );
  }
}

class _MessageAttachmentImage extends StatefulWidget {
  final String url;

  const _MessageAttachmentImage(this.url);

  @override
  State<_MessageAttachmentImage> createState() =>
      _MessageAttachmentImageState();
}

class _MessageAttachmentImageState extends State<_MessageAttachmentImage> {
  late final Future<Map<String, String>> _headersFuture = _loadHeaders();

  Future<Map<String, String>> _loadHeaders() async {
    final String? token = await TokenStorage.readToken();
    if (token == null || token.trim().isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{'Authorization': 'Bearer ${token.trim()}'};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _headersFuture,
      builder:
          (BuildContext context, AsyncSnapshot<Map<String, String>> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(width: 220, height: 150);
            }

            return SizedBox(
              width: 220,
              height: 150,
              child: SizedNetworkImage(
                url: widget.url,
                headers: snapshot.data,
                fit: BoxFit.cover,
                placeholder: const SizedBox(width: 220, height: 150),
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return const SizedBox(width: 220, height: 150);
                    },
              ),
            );
          },
    );
  }
}

class _ProductInquiryCard extends StatelessWidget {
  final MessageProductReference product;

  final VoidCallback? onTap;

  const _ProductInquiryCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  context.messagesAccent,
                  Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.resolve(
                          context,
                          const Color(0xFF4E2523),
                          fill: true,
                        )
                      : AppTheme.resolve(
                          context,
                          const Color(0xFF642920),
                          fill: true,
                        ),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: context.messagesAccent.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: product.imageUrl?.trim().isNotEmpty == true
                      ? SizedNetworkImage(
                          url: product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (
                                BuildContext context,
                                Object error,
                                StackTrace? stackTrace,
                              ) {
                                return const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: Colors.white,
                                  size: 20,
                                );
                              },
                        )
                      : const Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRODUCT INQUIRY',
                        style: TextStyle(
                          color: AppTheme.resolve(context, Color(0xFFE8C8B2)),
                          fontSize: 10.5,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      if (product.price != null) ...[
                        const SizedBox(height: 4),

                        Text(
                          formatPesoAmount(product.price!),
                          style: TextStyle(
                            color: AppTheme.resolve(context, Color(0xFFFFE7D9)),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (onTap != null) ...[
                  const SizedBox(width: 6),

                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderContextStrip extends StatelessWidget {
  final MessageOrderContext orderContext;

  const _OrderContextStrip({required this.orderContext});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
      decoration: BoxDecoration(
        color: context.messagesSurface,
        border: Border(bottom: BorderSide(color: context.messagesBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 15,
                color: context.messagesAccent,
              ),
              const SizedBox(width: 6),
              Text(
                'ORDER CONTEXT',
                style: TextStyle(
                  color: context.messagesAccent,
                  fontSize: 9.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Order ${orderContext.orderReference}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.messagesText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (orderContext.status.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    orderContext.status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: context.messagesMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (orderContext.products.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 62,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: orderContext.products.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(width: 8),
                itemBuilder: (BuildContext context, int index) {
                  final MessageOrderProduct product =
                      orderContext.products[index];
                  final String imageUrl = product.imageUrl?.trim() ?? '';
                  final List<String> details = <String>[
                    'Qty ${product.quantity}',
                    if (product.variant?.trim().isNotEmpty == true)
                      product.variant!.trim(),
                  ];

                  return Container(
                    width: 250,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.messagesBackgroundSoft,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: context.messagesBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: context.messagesSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: imageUrl.isEmpty
                              ? Icon(
                                  Icons.shopping_bag_outlined,
                                  color: context.messagesMuted,
                                  size: 20,
                                )
                              : SizedNetworkImage(
                                  url: AppConfig.resolveMediaUrl(imageUrl),
                                  iconSize: 20,
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.messagesText,
                                  fontSize: 10.5,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                details.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.messagesMuted,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SellerStatus extends StatelessWidget {
  final String label;

  final bool? isOnline;

  const _SellerStatus({required this.label, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final Color textColor = isOnline == true
        ? const Color(0xFF256F4A)
        : const Color(0xFF7B716B);

    return Row(
      children: [
        if (isOnline != null) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: isOnline == true
                  ? const Color(0xFF256F4A)
                  : const Color(0xFFA99E98),
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 5),
        ],

        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
            fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveChatStatus extends StatelessWidget {
  final String sellerName;
  final bool connected;

  const _LiveChatStatus({required this.sellerName, required this.connected});

  @override
  Widget build(BuildContext context) {
    final Color dotColor = connected
        ? const Color(0xFF2EAA60)
        : context.messagesChatMutedSoft;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
      decoration: BoxDecoration(
        color: context.messagesChatBackgroundSoft,
        border: Border(top: BorderSide(color: context.messagesChatBorder)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 3,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          Text(
            connected ? 'Live chat with $sellerName' : 'Reconnecting to $sellerName',
            style: TextStyle(
              color: context.messagesChatText,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Replies appear in this conversation.',
            style: TextStyle(
              color: context.messagesChatMuted,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerAvatar extends StatelessWidget {
  final BuyerConversationData seller;

  final double size;
  final bool showPresence;

  const _SellerAvatar({
    required this.seller,
    required this.size,
    this.showPresence = true,
  });

  @override
  Widget build(BuildContext context) {
    final String? url = seller.avatarUrl?.trim();
    final String identity = '${seller.name} ${seller.slug} ${seller.sellerId}'
        .toLowerCase();
    final bool isPerson =
        identity.contains('support') || identity.contains('assistant');

    Widget avatar = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.messagesSurface,
        border: Border.all(color: context.messagesBorder, width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.messagesAccent.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: url == null || url.isEmpty
          ? Center(
              child: _MessagesAvatarMark(
                isPerson: isPerson,
                size: size * 0.62,
              ),
            )
          : SizedNetworkImage(
              url: url,
              fit: BoxFit.cover,
              placeholder: const Center(
                child: SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white,
                  ),
                ),
              ),
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return Center(
                      child: _MessagesAvatarMark(
                        isPerson: isPerson,
                        size: size * 0.62,
                      ),
                    );
                  },
            ),
    );

    if (!showPresence || seller.isOnline == null) {
      return avatar;
    }

    final Color presenceColor = seller.isOnline == true
        ? const Color(0xFF3D9A68)
        : context.messagesFaint;

    return SizedBox(
      width: size + 2,
      height: size + 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.26,
              height: size * 0.26,
              decoration: BoxDecoration(
                color: presenceColor,
                shape: BoxShape.circle,
                border: Border.all(color: context.messagesSurface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagesAvatarMark extends StatelessWidget {
  final bool isPerson;
  final double size;

  const _MessagesAvatarMark({required this.isPerson, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MessagesAvatarPainter(
        isPerson: isPerson,
        outline: context.messagesAccentText,
        awning: context.messagesAccent,
        warmLight: const Color(0xFFF0D8C8),
        facade: const Color(0xFFFFF9F3),
      ),
    );
  }
}

class _MessagesAvatarPainter extends CustomPainter {
  final bool isPerson;
  final Color outline;
  final Color awning;
  final Color warmLight;
  final Color facade;

  const _MessagesAvatarPainter({
    required this.isPerson,
    required this.outline,
    required this.awning,
    required this.warmLight,
    required this.facade,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 24;
    canvas.save();
    canvas.scale(scale);

    final Paint fill = Paint()..style = PaintingStyle.fill;
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = outline;

    if (isPerson) {
      fill.color = warmLight;
      canvas.drawCircle(const Offset(12, 7.3), 4.1, fill);
      fill.color = awning;
      final Path shoulders = Path()
        ..moveTo(3.3, 21)
        ..lineTo(4.1, 17.2)
        ..cubicTo(4.7, 14.5, 7.3, 12.7, 10, 12.7)
        ..lineTo(14, 12.7)
        ..cubicTo(16.7, 12.7, 19.3, 14.5, 19.9, 17.2)
        ..lineTo(20.7, 21)
        ..close();
      canvas.drawPath(shoulders, fill);
      canvas.drawPath(shoulders, stroke);
    } else {
      // Store awning with alternating warm stripes.
      final Path awningShape = Path()
        ..moveTo(3.4, 8)
        ..lineTo(5.5, 3.5)
        ..lineTo(18.5, 3.5)
        ..lineTo(20.6, 8)
        ..lineTo(19.6, 10.6)
        ..cubicTo(18.5, 11.5, 17.2, 11.1, 16.5, 10.1)
        ..cubicTo(15.6, 11.3, 14.1, 11.3, 13.2, 10.1)
        ..cubicTo(12.3, 11.3, 10.8, 11.3, 9.9, 10.1)
        ..cubicTo(9, 11.3, 7.5, 11.3, 6.6, 10.1)
        ..cubicTo(5.8, 11.1, 4.4, 11.5, 3.4, 10.6)
        ..close();
      fill.color = awning;
      canvas.drawPath(awningShape, fill);
      canvas.drawPath(awningShape, stroke);

      fill.color = warmLight;
      canvas.drawRect(const Rect.fromLTRB(6.5, 4.1, 9.1, 9.7), fill);
      canvas.drawRect(const Rect.fromLTRB(12.1, 4.1, 14.7, 9.7), fill);
      canvas.drawRect(const Rect.fromLTRB(17.7, 4.1, 19, 8.8), fill);

      final RRect facadeShape = RRect.fromRectAndRadius(
        const Rect.fromLTRB(5, 10.5, 19, 21),
        const Radius.circular(0.8),
      );
      fill.color = facade;
      canvas.drawRRect(facadeShape, fill);
      canvas.drawRRect(facadeShape, stroke);

      final RRect window = RRect.fromRectAndRadius(
        const Rect.fromLTRB(7, 13, 11.3, 17.8),
        const Radius.circular(0.5),
      );
      fill.color = warmLight;
      canvas.drawRRect(window, fill);
      canvas.drawRRect(window, stroke);
      canvas.drawLine(const Offset(9.15, 13), const Offset(9.15, 17.8), stroke);

      final RRect door = RRect.fromRectAndRadius(
        const Rect.fromLTRB(13.3, 13, 17.2, 21),
        const Radius.circular(1.4),
      );
      fill.color = warmLight;
      canvas.drawRRect(door, fill);
      canvas.drawRRect(door, stroke);
      fill.color = outline;
      canvas.drawCircle(const Offset(16, 17.2), 0.45, fill);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MessagesAvatarPainter oldDelegate) {
    return isPerson != oldDelegate.isPerson ||
        outline != oldDelegate.outline ||
        awning != oldDelegate.awning ||
        warmLight != oldDelegate.warmLight ||
        facade != oldDelegate.facade;
  }
}
