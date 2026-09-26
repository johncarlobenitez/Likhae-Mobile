import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

typedef LoadConversationMessagesCallback =
    Future<List<BuyerMessageData>> Function(
  BuyerConversationData seller,
);

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
    Stream<BuyerMessageData> Function(
  BuyerConversationData seller,
);

typedef RefreshConversationsCallback =
    Future<List<BuyerConversationData>> Function();

typedef BuyerConversationCallback = void Function(
  BuyerConversationData seller,
);

typedef MessageProductReferenceCallback = void Function(
  MessageProductReference product,
);

class BuyerConversationData {
  final String sellerId;

  final String name;
  final String slug;

  final String? avatarUrl;

  final String lastMessage;
  final String time;

  final int unread;

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
    this.avatarUrl,
    this.lastMessage = '',
    this.time = '',
    this.unread = 0,
    this.statusLabel,
    this.isOnline,
  });

  BuyerConversationData copyWith({
    String? lastMessage,
    String? time,
    int? unread,
    String? statusLabel,
    bool? isOnline,
  }) {
    return BuyerConversationData(
      sellerId: sellerId,
      name: name,
      slug: slug,
      avatarUrl: avatarUrl,
      lastMessage:
          lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      unread: unread ?? this.unread,
      statusLabel:
          statusLabel ?? this.statusLabel,
      isOnline:
          isOnline ?? this.isOnline,
    );
  }

  String get initials {
    final List<String> parts = name
        .trim()
        .split(
          RegExp(r'\s+'),
        )
        .where(
          (String part) =>
              part.isNotEmpty,
        )
        .take(2)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    return parts
        .map(
          (String part) =>
              part[0].toUpperCase(),
        )
        .join();
  }
}

class BuyerMessageData {
  final String id;

  final String body;
  final String time;

  final bool fromBuyer;

  /// Optional attachment returned by Laravel.
  /// Existing text-only messages can leave these null.
  final String? attachmentUrl;
  final String? attachmentName;

  const BuyerMessageData({
    required this.id,
    required this.body,
    required this.time,
    required this.fromBuyer,
    this.attachmentUrl,
    this.attachmentName,
  });

  bool get hasAttachment =>
      attachmentUrl?.trim().isNotEmpty == true;
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
  final List<BuyerConversationData>
      conversations;

  /// Messages already loaded for the initially selected
  /// seller.
  final List<BuyerMessageData>
      initialMessages;

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
  final BuyerConversationData?
      initialSeller;

  final MessageProductReference?
      productReference;

  final VoidCallback? onBack;

  final BuyerConversationCallback?
      onConversationSelected;

  final BuyerConversationCallback?
      onViewStore;

  final MessageProductReferenceCallback?
      onProductReferenceSelected;

  final LoadConversationMessagesCallback?
      onLoadMessages;

  final SendBuyerMessageCallback?
      onSendMessage;

  /// Sends a message with one photo attachment.
  /// The callback must upload attachmentPath to Laravel
  /// and return the real saved message.
  final SendBuyerAttachmentCallback?
      onSendAttachment;

  /// Connect the Laravel message stream here later.
  ///
  /// The screen automatically reconnects if the stream
  /// closes while this seller remains active.
  final ConversationMessageStreamBuilder?
      messageStreamBuilder;

  final RefreshConversationsCallback?
      onRefreshConversations;

  /// Keep this configurable in case Laravel validation
  /// changes later.
  final int maxMessageLength;

  const MessagesScreen({
    super.key,
    this.conversations =
        const <BuyerConversationData>[],
    this.initialMessages =
        const <BuyerMessageData>[],
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
    this.maxMessageLength = 2000,
  });

  @override
  State<MessagesScreen> createState() =>
      _MessagesScreenState();
}

class _MessagesScreenState
    extends State<MessagesScreen> {
  static const Color _background =
      Color(0xFFFBF7F2);

  static const Color _backgroundSoft =
      Color(0xFFF6EFE7);

  static const Color _surface =
      Color(0xFFFFFDF9);

  static const Color _border =
      Color(0xFFEADCCC);

  static const Color _maroon =
      Color(0xFF561C17);

  static const Color _maroonDark =
      Color(0xFF3E130F);

  static const Color _text =
      Color(0xFF3B211B);

  static const Color _muted =
      Color(0xFF987865);

  static const Color _muted2 =
      Color(0xFFA99386);

  static const Color _tan =
      Color(0xFFC19771);

  static const Color _danger =
      Color(0xFFB42318);

  static const double _desktopBreakpoint =
      820;

  late List<BuyerConversationData>
      _conversations;

  List<BuyerMessageData> _messages =
      <BuyerMessageData>[];

  BuyerConversationData? _activeSeller;

  final Set<String> _seenMessageIds =
      <String>{};

  final TextEditingController
      _messageController =
      TextEditingController();

  final ImagePicker _imagePicker =
      ImagePicker();

  XFile? _pendingAttachment;

  bool _pickingAttachment = false;

  /// Extra messages typed while viewing the clearly
  /// labeled sample conversation. Preview messages stay
  /// local and are never presented as Laravel records.
  final Map<String, List<_DemoMessage>>
      _demoSentMessages =
      <String, List<_DemoMessage>>{};

  final ScrollController
      _messageScrollController =
      ScrollController();

  StreamSubscription<BuyerMessageData>?
      _messageSubscription;

  Timer? _reconnectTimer;

  bool _mobileShowingChat = false;

  bool _loadingMessages = false;

  bool _sendingMessage = false;

  bool _refreshingConversations = false;

  bool _realtimeConnected = false;

  String? _messageError;

  int? _demoConversationIndex;

  @override
  void initState() {
    super.initState();

    _conversations =
        List<BuyerConversationData>.from(
      widget.conversations,
    );

    _activeSeller =
        _resolveInitialSeller();

    _replaceMessages(
      widget.initialMessages,
      notify: false,
    );

    /*
     * On mobile, open directly into the chat only when a
     * specific seller was intentionally supplied.
     */
    _mobileShowingChat =
        _activeSeller != null &&
        (widget.initialSellerSlug != null ||
            widget.initialSeller != null);

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        _initializeActiveConversation();
      },
    );
  }

  @override
  void didUpdateWidget(
    covariant MessagesScreen oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    bool reconnectNeeded = false;

    if (oldWidget.conversations !=
        widget.conversations) {
      final BuyerConversationData?
          previousActive =
          _activeSeller;

      _conversations =
          List<BuyerConversationData>.from(
        widget.conversations,
      );

      final BuyerConversationData?
          resolved =
          _resolveUpdatedActiveSeller(
        previousActive,
      );

      if (resolved?.sellerId !=
          previousActive?.sellerId) {
        _activeSeller =
            resolved;

        _messages =
            <BuyerMessageData>[];

        _seenMessageIds.clear();

        _messageError =
            null;

        reconnectNeeded =
            true;
      } else if (resolved != null) {
        _activeSeller =
            resolved;
      }
    }

    final bool sellerRequestChanged =
        oldWidget.initialSellerSlug !=
            widget.initialSellerSlug ||
        oldWidget.initialSeller !=
            widget.initialSeller;

    if (sellerRequestChanged) {
      final BuyerConversationData?
          requestedSeller =
          _resolveInitialSeller();

      if (requestedSeller?.sellerId !=
          _activeSeller?.sellerId) {
        _activeSeller =
            requestedSeller;

        _messages =
            <BuyerMessageData>[];

        _seenMessageIds.clear();

        _messageError =
            null;

        reconnectNeeded =
            true;
      }

      _mobileShowingChat =
          requestedSeller != null &&
          (widget.initialSellerSlug !=
                  null ||
              widget.initialSeller !=
                  null);
    }

    if (oldWidget.initialMessages !=
            widget.initialMessages &&
        widget.initialMessages
            .isNotEmpty) {
      _replaceMessages(
        widget.initialMessages,
        notify: false,
      );
    }

    if (oldWidget.messageStreamBuilder !=
        widget.messageStreamBuilder) {
      reconnectNeeded =
          true;
    }

    if (reconnectNeeded) {
      WidgetsBinding.instance
          .addPostFrameCallback(
        (_) {
          if (!mounted) {
            return;
          }

          final BuyerConversationData?
              seller =
              _activeSeller;

          if (seller == null) {
            _disconnectRealtime();
            return;
          }

          _initializeActiveConversation(
            forceLoad:
                _messages.isEmpty,
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();

    _messageSubscription?.cancel();

    _messageController.dispose();

    _messageScrollController.dispose();

    super.dispose();
  }

  BuyerConversationData?
      _resolveInitialSeller() {
    final BuyerConversationData?
        suppliedSeller =
        widget.initialSeller;

    if (suppliedSeller != null) {
      for (final BuyerConversationData seller
          in _conversations) {
        if (_sameSeller(
          seller,
          suppliedSeller,
        )) {
          return seller;
        }
      }

      return suppliedSeller;
    }

    final String? requestedSlug =
        widget.initialSellerSlug
            ?.trim();

    if (requestedSlug != null &&
        requestedSlug.isNotEmpty) {
      for (final BuyerConversationData seller
          in _conversations) {
        if (seller.slug ==
            requestedSlug) {
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

  BuyerConversationData?
      _resolveUpdatedActiveSeller(
    BuyerConversationData?
        previousActive,
  ) {
    if (previousActive != null) {
      for (final BuyerConversationData seller
          in _conversations) {
        if (_sameSeller(
          seller,
          previousActive,
        )) {
          return seller;
        }
      }

      final BuyerConversationData?
          supplied =
          widget.initialSeller;

      if (supplied != null &&
          _sameSeller(
            supplied,
            previousActive,
          )) {
        return supplied;
      }
    }

    return _resolveInitialSeller();
  }

  bool _sameSeller(
    BuyerConversationData a,
    BuyerConversationData b,
  ) {
    if (a.sellerId.isNotEmpty &&
        b.sellerId.isNotEmpty) {
      return a.sellerId ==
          b.sellerId;
    }

    return a.slug == b.slug;
  }

  MessageProductReference?
      get _activeProductReference {
    final MessageProductReference?
        reference =
        widget.productReference;

    if (reference == null) {
      return null;
    }

    final BuyerConversationData?
        seller =
        _activeSeller;

    if (seller == null) {
      return null;
    }

    final BuyerConversationData?
        suppliedSeller =
        widget.initialSeller;

    if (suppliedSeller != null &&
        !_sameSeller(
          seller,
          suppliedSeller,
        )) {
      return null;
    }

    final String? requestedSlug =
        widget.initialSellerSlug;

    if (requestedSlug != null &&
        requestedSlug.isNotEmpty &&
        seller.slug !=
            requestedSlug) {
      return null;
    }

    return reference;
  }

  void _replaceMessages(
    List<BuyerMessageData> messages, {
    required bool notify,
  }) {
    void apply() {
      _messages =
          List<BuyerMessageData>.from(
        messages,
      );

      _seenMessageIds
        ..clear()
        ..addAll(
          messages
              .where(
                (
                  BuyerMessageData message,
                ) =>
                    message.id
                        .trim()
                        .isNotEmpty,
              )
              .map(
                (
                  BuyerMessageData message,
                ) =>
                    message.id,
              ),
        );
    }

    if (notify && mounted) {
      setState(
        apply,
      );
    } else {
      apply();
    }
  }

  Future<void>
      _initializeActiveConversation({
    bool forceLoad = false,
  }) async {
    final BuyerConversationData?
        seller =
        _activeSeller;

    if (seller == null) {
      await _disconnectRealtime();
      return;
    }

    if ((forceLoad ||
            _messages.isEmpty) &&
        widget.onLoadMessages !=
            null) {
      await _loadMessages(
        seller,
      );
    }

    if (!mounted ||
        !_isActiveSeller(
          seller,
        )) {
      return;
    }

    await _connectRealtime(
      seller,
    );

    _scheduleScrollToBottom();
  }

  Future<void> _selectConversation(
    BuyerConversationData seller,
  ) async {
    final bool alreadySelected =
        _isActiveSeller(
      seller,
    );

    setState(() {
      _mobileShowingChat =
          true;

      _activeSeller =
          seller.copyWith(
        unread: 0,
      );

      _markConversationReadLocally(
        seller,
      );

      if (!alreadySelected) {
        _messages =
            <BuyerMessageData>[];

        _seenMessageIds.clear();

        _messageError =
            null;

        _messageController.clear();
        _pendingAttachment = null;
      }
    });

    widget.onConversationSelected
        ?.call(
      seller,
    );

    if (alreadySelected) {
      _scheduleScrollToBottom();
      return;
    }

    await _disconnectRealtime();

    await _loadMessages(
      seller,
    );

    if (!mounted ||
        !_isActiveSeller(
          seller,
        )) {
      return;
    }

    await _connectRealtime(
      seller,
    );

    _scheduleScrollToBottom();
  }

  bool _isActiveSeller(
    BuyerConversationData seller,
  ) {
    final BuyerConversationData?
        active =
        _activeSeller;

    if (active == null) {
      return false;
    }

    return _sameSeller(
      active,
      seller,
    );
  }

  void _markConversationReadLocally(
    BuyerConversationData seller,
  ) {
    final int index =
        _conversations.indexWhere(
      (
        BuyerConversationData current,
      ) =>
          _sameSeller(
        current,
        seller,
      ),
    );

    if (index < 0) {
      return;
    }

    _conversations[index] =
        _conversations[index]
            .copyWith(
      unread: 0,
    );
  }

  Future<void> _loadMessages(
    BuyerConversationData seller,
  ) async {
    final LoadConversationMessagesCallback?
        loader =
        widget.onLoadMessages;

    if (loader == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _loadingMessages =
            true;

        _messageError =
            null;
      });
    }

    try {
      final List<BuyerMessageData>
          loaded =
          await loader(
        seller,
      );

      if (!mounted ||
          !_isActiveSeller(
            seller,
          )) {
        return;
      }

      _replaceMessages(
        loaded,
        notify: true,
      );

      setState(() {
        _markConversationReadLocally(
          seller,
        );
      });

      _scheduleScrollToBottom();
    } catch (error) {
      if (!mounted ||
          !_isActiveSeller(
            seller,
          )) {
        return;
      }

      setState(() {
        _messageError =
            _errorText(
          error,
        );
      });
    } finally {
      if (mounted &&
          _isActiveSeller(
            seller,
          )) {
        setState(() {
          _loadingMessages =
              false;
        });
      }
    }
  }

  Future<void> _connectRealtime(
    BuyerConversationData seller,
  ) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _messageSubscription
        ?.cancel();

    _messageSubscription =
        null;

    if (mounted) {
      setState(() {
        _realtimeConnected =
            false;
      });
    }

    final ConversationMessageStreamBuilder?
        builder =
        widget.messageStreamBuilder;

    if (builder == null ||
        !mounted ||
        !_isActiveSeller(
          seller,
        )) {
      return;
    }

    try {
      final Stream<BuyerMessageData>
          stream =
          builder(
        seller,
      );

      if (!mounted ||
          !_isActiveSeller(
            seller,
          )) {
        return;
      }

      setState(() {
        _realtimeConnected =
            true;
      });

      _messageSubscription =
          stream.listen(
        (
          BuyerMessageData message,
        ) {
          if (!mounted ||
              !_isActiveSeller(
                seller,
              )) {
            return;
          }

          _appendMessage(
            message,
          );
        },
        onError: (
          Object error,
          StackTrace stackTrace,
        ) {
          if (!mounted ||
              !_isActiveSeller(
                seller,
              )) {
            return;
          }

          setState(() {
            _realtimeConnected =
                false;
          });

          _scheduleRealtimeReconnect(
            seller,
          );
        },
        onDone: () {
          if (!mounted ||
              !_isActiveSeller(
                seller,
              )) {
            return;
          }

          setState(() {
            _realtimeConnected =
                false;
          });

          /*
           * Laravel SSE connections may intentionally
           * terminate after a period of time.
           *
           * Reconnect while this seller remains active.
           */
          _scheduleRealtimeReconnect(
            seller,
          );
        },
        cancelOnError: true,
      );
    } catch (_) {
      if (!mounted ||
          !_isActiveSeller(
            seller,
          )) {
        return;
      }

      setState(() {
        _realtimeConnected =
            false;
      });

      _scheduleRealtimeReconnect(
        seller,
      );
    }
  }

  void _scheduleRealtimeReconnect(
    BuyerConversationData seller,
  ) {
    if (widget.messageStreamBuilder ==
            null ||
        !mounted ||
        !_isActiveSeller(
          seller,
        )) {
      return;
    }

    _reconnectTimer?.cancel();

    _reconnectTimer =
        Timer(
      const Duration(
        seconds: 2,
      ),
      () {
        if (!mounted ||
            !_isActiveSeller(
              seller,
            )) {
          return;
        }

        _connectRealtime(
          seller,
        );
      },
    );
  }

  Future<void> _disconnectRealtime() async {
    _reconnectTimer?.cancel();

    _reconnectTimer =
        null;

    await _messageSubscription
        ?.cancel();

    _messageSubscription =
        null;

    if (mounted &&
        _realtimeConnected) {
      setState(() {
        _realtimeConnected =
            false;
      });
    }
  }

  void _appendMessage(
    BuyerMessageData message,
  ) {
    final String id =
        message.id.trim();

    if (id.isNotEmpty &&
        _seenMessageIds.contains(
          id,
        )) {
      return;
    }

    setState(() {
      if (id.isNotEmpty) {
        _seenMessageIds.add(
          id,
        );
      }

      _messages.add(
        message,
      );

      _updateActiveConversationPreview(
        message,
      );
    });

    _scheduleScrollToBottom();
  }

  void _updateActiveConversationPreview(
    BuyerMessageData message,
  ) {
    final BuyerConversationData?
        seller =
        _activeSeller;

    if (seller == null) {
      return;
    }

    final int index =
        _conversations.indexWhere(
      (
        BuyerConversationData current,
      ) =>
          _sameSeller(
        current,
        seller,
      ),
    );

    if (index >= 0) {
      _conversations[index] =
          _conversations[index]
              .copyWith(
        lastMessage:
            message.body,
        time:
            message.time,
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
      seller.copyWith(
        lastMessage:
            message.body,
        time:
            message.time,
        unread: 0,
      ),
    );
  }

  Future<void> _pickAttachment() async {
    if (_pickingAttachment ||
        _sendingMessage) {
      return;
    }

    final ImageSource? source =
        await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              12,
              14,
              14,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera_outlined,
                    color: _maroon,
                  ),
                  title: const Text(
                    'Take Photo',
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(
                    ImageSource.camera,
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: _maroon,
                  ),
                  title: const Text(
                    'Choose Photo',
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(
                    ImageSource.gallery,
                  ),
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
      final XFile? image =
          await _imagePicker.pickImage(
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

  Future<void> _sendDemoMessage(
    _DemoConversation conversation,
  ) async {
    if (_sendingMessage) {
      return;
    }

    final String body =
        _messageController.text.trim();
    final XFile? attachment =
        _pendingAttachment;

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
      final List<_DemoMessage> sent =
          _demoSentMessages.putIfAbsent(
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

    _showMessage(
      'Preview only — this message is not saved to Laravel.',
    );
  }

  Future<void> _sendMessage() async {
    final BuyerConversationData?
        seller =
        _activeSeller;

    if (seller == null ||
        _sendingMessage) {
      return;
    }

    final String body =
        _messageController.text
            .trim();

    final XFile? attachment =
        _pendingAttachment;

    if (body.isEmpty &&
        attachment == null) {
      return;
    }

    if (body.length >
        widget.maxMessageLength) {
      _showMessage(
        'Messages cannot exceed ${widget.maxMessageLength} characters.',
        error: true,
      );

      return;
    }

    final SendBuyerMessageCallback?
        sender =
        widget.onSendMessage;

    final SendBuyerAttachmentCallback?
        attachmentSender =
        widget.onSendAttachment;

    if (attachment == null &&
        sender == null) {
      _showMessage(
        'Messaging is not connected to Laravel.',
        error: true,
      );

      return;
    }

    if (attachment != null &&
        attachmentSender == null) {
      _showMessage(
        'Attachment sending is not connected to Laravel.',
        error: true,
      );

      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    setState(() {
      _sendingMessage =
          true;
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
        sent =
            await attachmentSender!(
          seller,
          body,
          attachment.path,
        );
      } else {
        sent =
            await sender!(
          seller,
          body,
        );
      }

      if (!mounted ||
          !_isActiveSeller(
            seller,
          )) {
        return;
      }

      _appendMessage(
        sent,
      );

      _messageController.clear();
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingMessage =
              false;
        });
      }
    }
  }

  Future<void>
      _refreshConversations() async {
    final RefreshConversationsCallback?
        refresher =
        widget.onRefreshConversations;

    if (refresher == null ||
        _refreshingConversations) {
      return;
    }

    setState(() {
      _refreshingConversations =
          true;
    });

    try {
      final List<BuyerConversationData>
          refreshed =
          await refresher();

      if (!mounted) {
        return;
      }

      final BuyerConversationData?
          previousActive =
          _activeSeller;

      BuyerConversationData?
          updatedActive;

      if (previousActive != null) {
        for (final BuyerConversationData seller
            in refreshed) {
          if (_sameSeller(
            seller,
            previousActive,
          )) {
            updatedActive =
                seller;
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
          widget.initialSeller !=
              null &&
          _sameSeller(
            previousActive,
            widget.initialSeller!,
          )) {
        updatedActive =
            previousActive;
      }

      updatedActive ??=
          refreshed.isEmpty
              ? null
              : refreshed.first;

      final bool changedSeller =
          updatedActive?.sellerId !=
              previousActive?.sellerId;

      setState(() {
        _conversations =
            List<BuyerConversationData>.from(
          refreshed,
        );

        _activeSeller =
            updatedActive;

        if (changedSeller) {
          _messages =
              <BuyerMessageData>[];

          _seenMessageIds.clear();

          _messageError =
              null;
        }
      });

      if (changedSeller) {
        await _disconnectRealtime();

        if (updatedActive != null) {
          await _loadMessages(
            updatedActive,
          );

          if (mounted &&
              _isActiveSeller(
                updatedActive,
              )) {
            await _connectRealtime(
              updatedActive,
            );
          }
        }
      }
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _refreshingConversations =
              false;
        });
      }
    }
  }

  Future<void> _refreshChat() async {
    final BuyerConversationData?
        seller =
        _activeSeller;

    if (seller == null) {
      return;
    }

    if (widget.onLoadMessages !=
        null) {
      await _loadMessages(
        seller,
      );

      if (!mounted ||
          !_isActiveSeller(
            seller,
          )) {
        return;
      }

      await _connectRealtime(
        seller,
      );

      return;
    }

    await _refreshConversations();
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!mounted ||
            !_messageScrollController
                .hasClients) {
          return;
        }

        final ScrollPosition position =
            _messageScrollController
                .position;

        _messageScrollController
            .animateTo(
          position.maxScrollExtent,
          duration:
              const Duration(
            milliseconds: 220,
          ),
          curve:
              Curves.easeOut,
        );
      },
    );
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              error
                  ? _danger
                  : _maroonDark,
          margin:
              const EdgeInsets.all(
            16,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          content:
              Text(
            message,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ),
      );
  }

  String _errorText(
    Object error,
  ) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          _background,
      body: SafeArea(
        child:
            LayoutBuilder(
          builder: (
            BuildContext context,
            BoxConstraints constraints,
          ) {
            final bool wide =
                constraints.maxWidth >=
                    _desktopBreakpoint;

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
            padding:
                const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16,
            ),
            child:
                Container(
              clipBehavior:
                  Clip.antiAlias,
              decoration:
                  BoxDecoration(
                color:
                    _surface,
                borderRadius:
                    BorderRadius.circular(
                  22,
                ),
                border:
                    Border.all(
                  color:
                      _border,
                ),
                boxShadow:
                    <BoxShadow>[
                  BoxShadow(
                    color:
                        _maroon.withValues(
                      alpha: 0.05,
                    ),
                    blurRadius:
                        24,
                    offset:
                        const Offset(
                      0,
                      9,
                    ),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width:
                        320,
                    child:
                        _buildConversationPanel(),
                  ),

                  const VerticalDivider(
                    width:
                        1,
                    thickness:
                        1,
                    color:
                        _border,
                  ),

                  Expanded(
                    child:
                        _conversations.isEmpty &&
                                _demoConversationIndex != null
                            ? _buildDemoChatPanel(
                                _demoConversations[
                                    _demoConversationIndex!],
                                mobile:
                                    false,
                              )
                            : _buildChatPanel(
                                mobile:
                                    false,
                              ),
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
        _demoConversationIndex != null) {
      return _buildDemoChatPanel(
        _demoConversations[
            _demoConversationIndex!],
        mobile:
            true,
      );
    }

    if (_mobileShowingChat &&
        _activeSeller != null) {
      return _buildChatPanel(
        mobile: true,
      );
    }

    return Column(
      children: [
        _buildPageHeader(),

        Expanded(
          child:
              _buildConversationPanel(),
        ),
      ],
    );
  }

  Widget _buildPageHeader() {
    final bool showingPreview =
        _conversations.isEmpty;

    final int displayConversationCount =
        showingPreview
            ? _demoConversations.length
            : _conversations.length;

    final int unreadCount =
        showingPreview
            ? _demoConversations.fold<int>(
                0,
                (
                  int total,
                  _DemoConversation conversation,
                ) =>
                    total +
                    conversation.unread,
              )
            : _conversations.fold<int>(
                0,
                (
                  int total,
                  BuyerConversationData conversation,
                ) =>
                    total +
                    conversation.unread,
              );

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        7,
        5,
        12,
        7,
      ),
      decoration:
          const BoxDecoration(
        color:
            _background,
        border:
            Border(
          bottom:
              BorderSide(
            color:
                Color(
              0xFFF0E8DF,
            ),
          ),
        ),
      ),
      child:
          Row(
        children: [
          IconButton(
            tooltip:
                'Back',
            onPressed:
                widget.onBack ??
                () {
                  Navigator.of(
                    context,
                  ).maybePop();
                },
            icon:
                const Icon(
              Icons
                  .arrow_back_rounded,
              color:
                  _text,
            ),
          ),

          const SizedBox(
            width: 2,
          ),

          const Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Messages',
                  style:
                      TextStyle(
                    color:
                        _text,
                    fontSize:
                        21,
                    height:
                        1.1,
                    letterSpacing:
                        -0.4,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                SizedBox(
                  height:
                      2,
                ),

                Text(
                  'Conversations with LIKHAE sellers',
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      TextStyle(
                    color:
                        _muted,
                    fontSize:
                        12,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal:
                  9,
              vertical:
                  6,
            ),
            decoration:
                BoxDecoration(
              color:
                  _surface,
              borderRadius:
                  BorderRadius.circular(
                100,
              ),
              border:
                  Border.all(
                color:
                    _border,
              ),
            ),
            child:
                Row(
              children: [
                const Icon(
                  Icons
                      .chat_bubble_outline_rounded,
                  color:
                      _maroon,
                  size:
                      13,
                ),

                const SizedBox(
                  width:
                      4,
                ),

                Text(
                  '$displayConversationCount',
                  style:
                      const TextStyle(
                    color:
                        _maroon,
                    fontSize:
                        11.5,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                if (unreadCount >
                    0) ...[
                  const SizedBox(
                    width:
                        6,
                  ),

                  Container(
                    constraints:
                        const BoxConstraints(
                      minWidth:
                          18,
                      minHeight:
                          18,
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal:
                          4,
                    ),
                    alignment:
                        Alignment.center,
                    decoration:
                        const BoxDecoration(
                      color:
                          _maroon,
                      shape:
                          BoxShape.circle,
                    ),
                    child:
                        Text(
                      unreadCount >
                              99
                          ? '99+'
                          : '$unreadCount',
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            10,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationPanel() {
    return Container(
      color:
          _surface,
      child:
          Column(
        children: [
          Container(
            width:
                double.infinity,
            padding:
                const EdgeInsets.fromLTRB(
              16,
              15,
              16,
              14,
            ),
            decoration:
                const BoxDecoration(
              color:
                  _surface,
              border:
                  Border(
                bottom:
                    BorderSide(
                  color:
                      _border,
                ),
              ),
            ),
            child:
                Row(
              children: [
                const Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COMMUNICATION',
                        style:
                            TextStyle(
                          color:
                              _maroon,
                          fontSize:
                              10.5,
                          letterSpacing:
                              1.4,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),

                      SizedBox(
                        height:
                            4,
                      ),

                      Text(
                        'Conversations',
                        style:
                            TextStyle(
                          color:
                              _text,
                          fontSize:
                              17,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_refreshingConversations)
                  const SizedBox(
                    width:
                        16,
                    height:
                        16,
                    child:
                        CircularProgressIndicator(
                      strokeWidth:
                          2,
                      color:
                          _maroon,
                    ),
                  )
                else
                  Text(
                    '${_conversations.isEmpty ? _demoConversations.length : _conversations.length}',
                    style:
                        const TextStyle(
                      color:
                          _muted,
                      fontSize:
                          12,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child:
                RefreshIndicator(
              color:
                  _maroon,
              onRefresh:
                  _refreshConversations,
              child:
                  _conversations.isEmpty
                      ? _buildDemoConversationList()
                      : ListView.separated(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          itemCount:
                              _conversations.length,
                          separatorBuilder:
                              (
                            BuildContext context,
                            int index,
                          ) {
                            return const Divider(
                              height:
                                  1,
                              thickness:
                                  1,
                              color:
                                  Color(
                                0xFFEFE1D5,
                              ),
                            );
                          },
                          itemBuilder:
                              (
                            BuildContext context,
                            int index,
                          ) {
                            final BuyerConversationData
                                conversation =
                                _conversations[index];

                            final bool selected =
                                _activeSeller != null &&
                                _sameSeller(
                                  _activeSeller!,
                                  conversation,
                                );

                            return _ConversationTile(
                              conversation:
                                  conversation,
                              selected:
                                  selected,
                              onTap:
                                  () {
                                _selectConversation(
                                  conversation,
                                );
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

  static const List<_DemoConversation> _demoConversations =
      <_DemoConversation>[
    _DemoConversation(
      name: 'Aurelia Jewelry',
      initials: 'AJ',
      lastMessage:
          'Yes, the pearl necklace is still available.',
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
          body:
              'Nice. How many pieces are available right now?',
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
          body:
              'Okay, thank you! I will check out the product.',
          time: '7:06 PM',
          fromBuyer: true,
        ),
      ],
    ),
    _DemoConversation(
      name: 'Mira Studio',
      initials: 'MS',
      lastMessage:
          'We can prepare the item today.',
      time: '18m',
      unread: 1,
      status: 'Seller • Preview conversation',
      messages: <_DemoMessage>[
        _DemoMessage(
          body:
              'Hello, is this item available in the selected variation?',
          time: '6:41 PM',
          fromBuyer: true,
        ),
        _DemoMessage(
          body:
              'Yes, that variation is available.',
          time: '6:43 PM',
          fromBuyer: false,
        ),
        _DemoMessage(
          body:
              'If I order today, when can it be prepared?',
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
      initials: 'PP',
      lastMessage:
          'Softcover is available.',
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
          body:
              'Hi! Yes, softcover is available.',
          time: '6:05 PM',
          fromBuyer: false,
        ),
        _DemoMessage(
          body:
              'Thank you. I will add it to my cart.',
          time: '6:06 PM',
          fromBuyer: true,
        ),
      ],
    ),
    _DemoConversation(
      name: 'Craft & Clay Studio',
      initials: 'CC',
      lastMessage:
          'Thank you for your message.',
      time: 'Yesterday',
      unread: 0,
      status: 'Seller • Preview conversation',
      messages: <_DemoMessage>[
        _DemoMessage(
          body:
              'Hello! Can I ask about the material used for this product?',
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
          body:
              'Got it. Thank you for your message.',
          time: 'Yesterday • 4:25 PM',
          fromBuyer: true,
        ),
      ],
    ),
  ];

  Widget _buildDemoConversationList() {
    return ListView.separated(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.only(
        bottom:
            24,
      ),
      itemCount:
          _demoConversations.length + 1,
      separatorBuilder:
          (
        BuildContext context,
        int index,
      ) {
        if (index == 0) {
          return const SizedBox.shrink();
        }

        return const Divider(
          height:
              1,
          thickness:
              1,
          color:
              Color(
            0xFFEFE1D5,
          ),
        );
      },
      itemBuilder:
          (
        BuildContext context,
        int index,
      ) {
        if (index == 0) {
          return Container(
            width:
                double.infinity,
            margin:
                const EdgeInsets.fromLTRB(
              14,
              14,
              14,
              10,
            ),
            padding:
                const EdgeInsets.all(
              12,
            ),
            decoration:
                BoxDecoration(
              color:
                  _backgroundSoft,
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
              border:
                  Border.all(
                color:
                    _border,
              ),
            ),
            child:
                const Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons
                      .visibility_outlined,
                  color:
                      _maroon,
                  size:
                      19,
                ),
                SizedBox(
                  width:
                      9,
                ),
                Expanded(
                  child:
                      Text(
                    'Preview mode — tap any sample conversation to see the full Messenger-style chat layout. These messages are not saved to Laravel.',
                    style:
                        TextStyle(
                      color:
                          _muted,
                      fontSize:
                          12,
                      height:
                          1.45,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final int conversationIndex =
            index - 1;

        final _DemoConversation conversation =
            _demoConversations[
                conversationIndex];

        return _DemoConversationTile(
          conversation:
              conversation,
          onTap:
              () {
            setState(() {
              _demoConversationIndex =
                  conversationIndex;
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
      color:
          _backgroundSoft,
      child:
          Column(
        children: [
          Container(
            padding:
                const EdgeInsets.fromLTRB(
              7,
              8,
              11,
              8,
            ),
            decoration:
                const BoxDecoration(
              color:
                  _surface,
              border:
                  Border(
                bottom:
                    BorderSide(
                  color:
                      _border,
                ),
              ),
            ),
            child:
                Row(
              children: [
                if (mobile)
                  IconButton(
                    tooltip:
                        'Back to conversations',
                    onPressed:
                        () {
                      setState(() {
                        _demoConversationIndex =
                            null;
                      });
                    },
                    icon:
                        const Icon(
                      Icons
                          .arrow_back_rounded,
                      color:
                          _text,
                    ),
                  ),

                _DemoAvatar(
                  initials:
                      conversation.initials,
                  size:
                      44,
                ),

                const SizedBox(
                  width:
                      10,
                ),

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.name,
                        maxLines:
                            1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color:
                              _text,
                          fontSize:
                              16,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      const SizedBox(
                        height:
                            3,
                      ),
                      Text(
                        conversation.status,
                        maxLines:
                            1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color:
                              _muted,
                          fontSize:
                              11.5,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal:
                        9,
                    vertical:
                        5,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        _backgroundSoft,
                    borderRadius:
                        BorderRadius.circular(
                      100,
                    ),
                    border:
                        Border.all(
                      color:
                          _border,
                    ),
                  ),
                  child:
                      const Text(
                    'PREVIEW',
                    style:
                        TextStyle(
                      color:
                          _maroon,
                      fontSize:
                          10.5,
                      letterSpacing:
                          0.4,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child:
                Builder(
              builder: (BuildContext context) {
                final List<_DemoMessage> messages =
                    <_DemoMessage>[
                  ...conversation.messages,
                  ...(_demoSentMessages[conversation.name] ??
                      const <_DemoMessage>[]),
                ];

                return ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(
                    13,
                    18,
                    13,
                    22,
                  ),
                  itemCount:
                      messages.length + 1,
                  itemBuilder:
                      (
                    BuildContext context,
                    int index,
                  ) {
                    if (index == 0) {
                  return Center(
                    child:
                        Container(
                      margin:
                          const EdgeInsets.only(
                        bottom:
                            4,
                      ),
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal:
                            11,
                        vertical:
                            6,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            _surface,
                        border:
                            Border.all(
                          color:
                              _border,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          100,
                        ),
                      ),
                      child:
                          const Text(
                        'Sample conversation',
                        style:
                            TextStyle(
                          color:
                              _muted,
                          fontSize:
                              11,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                }

                    final _DemoMessage message =
                        messages[index - 1];

                    return _DemoMessageBubble(
                      message:
                          message,
                      sellerInitials:
                          conversation.initials,
                    );
                  },
                );
              },
            ),
          ),

          _buildDemoComposer(
            conversation,
            mobile: mobile,
          ),

        ],
      ),
    );
  }

  Widget _buildDemoComposer(
    _DemoConversation conversation, {
    required bool mobile,
  }) {
    return _buildMessageBox(
      hintText: 'Message ${conversation.name}...',
      onSend: () =>
          _sendDemoMessage(conversation),
      mobile: mobile,
    );
  }

  Widget _buildChatPanel({
    required bool mobile,
  }) {
    final BuyerConversationData?
        seller =
        _activeSeller;

    if (seller == null) {
      return _buildNoSelectedConversation();
    }

    return Container(
      color:
          _backgroundSoft,
      child:
          Column(
        children: [
          _buildChatHeader(
            seller,
            mobile:
                mobile,
          ),

          Expanded(
            child:
                _buildMessageStream(
              seller,
            ),
          ),

          _buildComposer(
            seller,
            mobile: mobile,
          ),
        ],
      ),
    );
  }

  Widget _buildChatHeader(
    BuyerConversationData seller, {
    required bool mobile,
  }) {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        8,
        9,
        12,
        9,
      ),
      decoration:
          const BoxDecoration(
        color:
            _surface,
        border:
            Border(
          bottom:
              BorderSide(
            color:
                _border,
          ),
        ),
      ),
      child:
          Row(
        children: [
          if (mobile)
            IconButton(
              tooltip:
                  'Back to conversations',
              onPressed:
                  () {
                setState(() {
                  _mobileShowingChat =
                      false;
                });
              },
              icon:
                  const Icon(
                Icons
                    .arrow_back_rounded,
                color:
                    _text,
              ),
            ),

          _SellerAvatar(
            seller:
                seller,
            size:
                43,
          ),

          const SizedBox(
            width:
                10,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  seller.name,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        _text,
                    fontSize:
                        15,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                if (seller.statusLabel
                        ?.trim()
                        .isNotEmpty ==
                    true) ...[
                  const SizedBox(
                    height:
                        3,
                  ),

                  _SellerStatus(
                    label:
                        seller.statusLabel!,
                    isOnline:
                        seller.isOnline,
                  ),
                ] else if (widget
                        .messageStreamBuilder !=
                    null) ...[
                  const SizedBox(
                    height:
                        3,
                  ),

                  Text(
                    _realtimeConnected
                        ? 'Live messages connected'
                        : 'Live messages reconnecting...',
                    maxLines:
                        1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color:
                          _muted,
                      fontSize:
                          11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(
            width:
                7,
          ),

          SizedBox(
            height:
                38,
            child:
                OutlinedButton.icon(
              onPressed:
                  widget.onViewStore ==
                          null
                      ? null
                      : () {
                          widget.onViewStore!(
                            seller,
                          );
                        },
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    _maroon,
                side:
                    const BorderSide(
                  color:
                      _tan,
                ),
                padding:
                    const EdgeInsets.symmetric(
                  horizontal:
                      10,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),
              icon:
                  const Icon(
                Icons
                    .storefront_outlined,
                size:
                    15,
              ),
              label:
                  Text(
                mobile
                    ? 'Store'
                    : 'View Store',
                style:
                    const TextStyle(
                  fontSize:
                      11.5,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageStream(
    BuyerConversationData seller,
  ) {
    if (_loadingMessages &&
        _messages.isEmpty) {
      return const Center(
        child:
            SizedBox(
          width:
              25,
          height:
              25,
          child:
              CircularProgressIndicator(
            strokeWidth:
                2,
            color:
                _maroon,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color:
          _maroon,
      onRefresh:
          _refreshChat,
      child:
          ListView(
        controller:
            _messageScrollController,
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          13,
          17,
          13,
          20,
        ),
        children: [
          Center(
            child:
                Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal:
                    11,
                vertical:
                    6,
              ),
              decoration:
                  BoxDecoration(
                color:
                    _surface,
                border:
                    Border.all(
                  color:
                      _border,
                ),
                borderRadius:
                    BorderRadius.circular(
                  100,
                ),
              ),
              child:
                  const Text(
                'Conversation',
                style:
                    TextStyle(
                  color:
                      _muted,
                  fontSize:
                      11,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),

          if (_activeProductReference !=
              null) ...[
            const SizedBox(
              height:
                  14,
            ),

            _ProductInquiryCard(
              product:
                  _activeProductReference!,
              onTap:
                  widget.onProductReferenceSelected ==
                          null
                      ? null
                      : () {
                          widget
                              .onProductReferenceSelected!(
                            _activeProductReference!,
                          );
                        },
            ),
          ],

          if (_messageError !=
              null) ...[
            const SizedBox(
              height:
                  14,
            ),

            Container(
              padding:
                  const EdgeInsets.all(
                12,
              ),
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFFCECE7,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                border:
                    Border.all(
                  color:
                      const Color(
                    0xFFEBC9C0,
                  ),
                ),
              ),
              child:
                  Row(
                children: [
                  const Icon(
                    Icons
                        .error_outline_rounded,
                    color:
                        _danger,
                    size:
                        18,
                  ),

                  const SizedBox(
                    width:
                        8,
                  ),

                  Expanded(
                    child:
                        Text(
                      _messageError!,
                      style:
                          const TextStyle(
                        color:
                            _danger,
                        fontSize:
                            12,
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed:
                        _refreshChat,
                    child:
                        const Text(
                      'Retry',
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_messages.isEmpty) ...[
            const SizedBox(
              height:
                  35,
            ),

            const Icon(
              Icons
                  .forum_outlined,
              size:
                  42,
              color:
                  _tan,
            ),

            const SizedBox(
              height:
                  11,
            ),

            const Text(
              'No messages yet',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    _text,
                fontSize:
                    17,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height:
                  5,
            ),

            Text(
              'Send the first message to ${seller.name}.',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    _muted,
                fontSize:
                    12,
              ),
            ),
          ] else ...[
            const SizedBox(
              height:
                  5,
            ),

            for (final BuyerMessageData message
                in _messages)
              _MessageBubble(
                message:
                    message,
                seller:
                    seller,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildComposer(
    BuyerConversationData seller, {
    required bool mobile,
  }) {
    return _buildMessageBox(
      hintText: 'Message ${seller.name}...',
      onSend: _sendMessage,
      mobile: mobile,
    );
  }

  Widget _buildMessageBox({
    required String hintText,
    required Future<void> Function() onSend,
    required bool mobile,
  }) {
    final XFile? attachment =
        _pendingAttachment;

    final bool keyboardOpen =
        MediaQuery.of(context).viewInsets.bottom > 0;

    // BuyerNavigation uses a floating bottom bar on mobile.
    // Keep only the composer above that bar without changing
    // the chat/header/message layout. When the keyboard opens,
    // the extra clearance is removed so the composer stays close
    // to the keyboard.
    final double navigationClearance =
        mobile && !keyboardOpen ? 74 : 0;

    return Container(
      padding:
          EdgeInsets.fromLTRB(
        11,
        8,
        11,
        10 + navigationClearance,
      ),
      decoration:
          const BoxDecoration(
        color:
            _surface,
        border:
            Border(
          top:
              BorderSide(
            color:
                _border,
          ),
        ),
      ),
      child:
          SafeArea(
        top:
            false,
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            if (attachment != null) ...[
              Container(
                width:
                    double.infinity,
                margin:
                    const EdgeInsets.only(
                  bottom:
                      8,
                ),
                padding:
                    const EdgeInsets.all(
                  8,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      _backgroundSoft,
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  border:
                      Border.all(
                    color:
                        _border,
                  ),
                ),
                child:
                    Row(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(
                        9,
                      ),
                      child:
                          Image.file(
                        File(attachment.path),
                        width:
                            48,
                        height:
                            48,
                        fit:
                            BoxFit.cover,
                        errorBuilder:
                            (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return Container(
                            width:
                                48,
                            height:
                                48,
                            color:
                                _surface,
                            alignment:
                                Alignment.center,
                            child:
                                const Icon(
                              Icons.image_outlined,
                              color:
                                  _muted2,
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(
                      width:
                          9,
                    ),

                    Expanded(
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Photo attachment',
                            style:
                                TextStyle(
                              color:
                                  _text,
                              fontSize:
                                  12,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                          const SizedBox(
                            height:
                                2,
                          ),
                          Text(
                            attachment.name,
                            maxLines:
                                1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                              color:
                                  _muted,
                              fontSize:
                                  11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      tooltip:
                          'Remove attachment',
                      onPressed:
                          _sendingMessage
                              ? null
                              : _removeAttachment,
                      icon:
                          const Icon(
                        Icons.close_rounded,
                        color:
                            _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width:
                      44,
                  height:
                      48,
                  child:
                      IconButton(
                    tooltip:
                        'Attach photo',
                    onPressed:
                        _sendingMessage ||
                                _pickingAttachment
                            ? null
                            : _pickAttachment,
                    style:
                        IconButton.styleFrom(
                      backgroundColor:
                          _backgroundSoft,
                      foregroundColor:
                          _maroon,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                        side:
                            const BorderSide(
                          color:
                              _border,
                        ),
                      ),
                    ),
                    icon:
                        _pickingAttachment
                            ? const SizedBox(
                                width:
                                    18,
                                height:
                                    18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                  color:
                                      _maroon,
                                ),
                              )
                            : const Icon(
                                Icons.attach_file_rounded,
                                size:
                                    20,
                              ),
                  ),
                ),

                const SizedBox(
                  width:
                      8,
                ),

                Expanded(
                  child:
                      TextField(
                    controller:
                        _messageController,
                    enabled:
                        !_sendingMessage,
                    textInputAction:
                        TextInputAction.send,
                    textCapitalization:
                        TextCapitalization.sentences,
                    minLines:
                        1,
                    maxLines:
                        4,
                    maxLength:
                        widget.maxMessageLength,
                    onSubmitted:
                        (_) {
                      if (!_sendingMessage) {
                        onSend();
                      }
                    },
                    decoration:
                        InputDecoration(
                      hintText:
                          hintText,
                      hintStyle:
                          const TextStyle(
                        color:
                            _muted2,
                        fontSize:
                            13,
                      ),
                      counterText:
                          '',
                      filled:
                          true,
                      fillColor:
                          _backgroundSoft,
                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal:
                            14,
                        vertical:
                            12,
                      ),
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              _border,
                        ),
                      ),
                      enabledBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              _border,
                        ),
                      ),
                      focusedBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              _tan,
                          width:
                              1.3,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                      8,
                ),

                SizedBox(
                  width:
                      48,
                  height:
                      48,
                  child:
                      ElevatedButton(
                    onPressed:
                        _sendingMessage
                            ? null
                            : onSend,
                    style:
                        ElevatedButton.styleFrom(
                      elevation:
                          0,
                      backgroundColor:
                          _maroon,
                      foregroundColor:
                          Colors.white,
                      disabledBackgroundColor:
                          const Color(0x73561C17),
                      padding:
                          EdgeInsets.zero,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                    child:
                        _sendingMessage
                            ? const SizedBox(
                                width:
                                    19,
                                height:
                                    19,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                size:
                                    19,
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
        widget.initialSeller ==
            null &&
        !_conversations.any(
          (
            BuyerConversationData seller,
          ) =>
              seller.slug ==
              widget.initialSellerSlug,
        );

    return Container(
      color:
          _backgroundSoft,
      child:
          Center(
        child:
            Padding(
          padding:
              const EdgeInsets.all(
            30,
          ),
          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons
                    .chat_bubble_outline_rounded,
                size:
                    55,
                color:
                    _tan,
              ),

              const SizedBox(
                height:
                    14,
              ),

              Text(
                requestedSellerMissing
                    ? 'Seller conversation unavailable'
                    : 'No conversation selected',
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      _text,
                  fontSize:
                      19,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height:
                    6,
              ),

              Text(
                requestedSellerMissing
                    ? 'Provide the seller information when starting a new conversation from Product Details.'
                    : 'Select a conversation to start chatting.',
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      _muted,
                  fontSize:
                      12.5,
                  height:
                      1.55,
                ),
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
  final String initials;
  final String lastMessage;
  final String time;
  final int unread;
  final String status;
  final List<_DemoMessage> messages;

  const _DemoConversation({
    required this.name,
    required this.initials,
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

class _DemoConversationTile
    extends StatelessWidget {
  final _DemoConversation conversation;
  final VoidCallback onTap;

  const _DemoConversationTile({
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          const Color(
        0xFFFFFDF9,
      ),
      child:
          InkWell(
        onTap:
            onTap,
        child:
            Padding(
          padding:
              const EdgeInsets.fromLTRB(
            14,
            12,
            14,
            12,
          ),
          child:
              Row(
            crossAxisAlignment:
                CrossAxisAlignment.center,
            children: [
              _DemoAvatar(
                initials:
                    conversation.initials,
                size:
                    50,
              ),

              const SizedBox(
                width:
                    12,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child:
                              Text(
                            conversation.name,
                            maxLines:
                                1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                TextStyle(
                              color:
                                  const Color(
                                0xFF3B211B,
                              ),
                              fontSize:
                                  14,
                              fontWeight:
                                  conversation.unread > 0
                                      ? FontWeight.w900
                                      : FontWeight.w800,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width:
                              8,
                        ),

                        Text(
                          conversation.time,
                          style:
                              const TextStyle(
                            color:
                                Color(
                              0xFFA99386,
                            ),
                            fontSize:
                                11,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height:
                          5,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child:
                              Text(
                            conversation.lastMessage,
                            maxLines:
                                1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                TextStyle(
                              color:
                                  const Color(
                                0xFF987865,
                              ),
                              fontSize:
                                  12.5,
                              fontWeight:
                                  conversation.unread > 0
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                            ),
                          ),
                        ),

                        if (conversation.unread >
                            0) ...[
                          const SizedBox(
                            width:
                                8,
                          ),

                          Container(
                            constraints:
                                const BoxConstraints(
                              minWidth:
                                  21,
                              minHeight:
                                  21,
                            ),
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal:
                                  6,
                            ),
                            alignment:
                                Alignment.center,
                            decoration:
                                const BoxDecoration(
                              color:
                                  Color(
                                0xFF561C17,
                              ),
                              shape:
                                  BoxShape.circle,
                            ),
                            child:
                                Text(
                              '${conversation.unread}',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontSize:
                                    10.5,
                                fontWeight:
                                    FontWeight.w900,
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

class _DemoMessageBubble
    extends StatelessWidget {
  final _DemoMessage message;
  final String sellerInitials;

  const _DemoMessageBubble({
    required this.message,
    required this.sellerInitials,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        top:
            12,
      ),
      child:
          Align(
        alignment:
            message.fromBuyer
                ? Alignment.centerRight
                : Alignment.centerLeft,
        child:
            Row(
          mainAxisSize:
              MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            if (!message.fromBuyer) ...[
              _DemoAvatar(
                initials:
                    sellerInitials,
                size:
                    30,
              ),
              const SizedBox(
                width:
                    7,
              ),
            ],

            Flexible(
              child:
                  Container(
                constraints:
                    const BoxConstraints(
                  maxWidth:
                      285,
                ),
                padding:
                    const EdgeInsets.fromLTRB(
                  13,
                  11,
                  13,
                  9,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      message.fromBuyer
                          ? const Color(
                              0xFF561C17,
                            )
                          : const Color(
                              0xFFFFFDF9,
                            ),
                  border:
                      Border.all(
                    color:
                        message.fromBuyer
                            ? const Color(
                                0xFF561C17,
                              )
                            : const Color(
                                0xFFEADCCC,
                              ),
                  ),
                  borderRadius:
                      BorderRadius.only(
                    topLeft:
                        Radius.circular(
                      message.fromBuyer
                          ? 17
                          : 5,
                    ),
                    topRight:
                        Radius.circular(
                      message.fromBuyer
                          ? 5
                          : 17,
                    ),
                    bottomLeft:
                        const Radius.circular(
                      17,
                    ),
                    bottomRight:
                        const Radius.circular(
                      17,
                    ),
                  ),
                ),
                child:
                    Column(
                  crossAxisAlignment:
                      message.fromBuyer
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                  children: [
                    if (message.attachmentPath != null) ...[
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                        child:
                            Image.file(
                          File(message.attachmentPath!),
                          width:
                              220,
                          height:
                              150,
                          fit:
                              BoxFit.cover,
                          errorBuilder:
                              (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) {
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      if (message.body.trim().isNotEmpty)
                        const SizedBox(
                          height:
                              8,
                        ),
                    ],
                    if (message.body.trim().isNotEmpty)
                    Text(
                      message.body,
                      style:
                          TextStyle(
                        color:
                            message.fromBuyer
                                ? Colors.white
                                : const Color(
                                    0xFF3B211B,
                                  ),
                        fontSize:
                            13,
                        height:
                            1.5,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),

                    const SizedBox(
                      height:
                          5,
                    ),

                    Text(
                      message.time,
                      style:
                          TextStyle(
                        color:
                            message.fromBuyer
                                ? const Color(
                                    0xFFE8C8B2,
                                  )
                                : const Color(
                                    0xFFA99386,
                                  ),
                        fontSize:
                            10.5,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoAvatar
    extends StatelessWidget {
  final String initials;
  final double size;

  const _DemoAvatar({
    required this.initials,
    required this.size,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          size,
      height:
          size,
      alignment:
          Alignment.center,
      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,
        color:
            const Color(
          0xFF561C17,
        ),
        border:
            Border.all(
          color:
              Colors.white,
          width:
              2,
        ),
        boxShadow:
            <BoxShadow>[
          BoxShadow(
            color:
                const Color(
              0xFF561C17,
            ).withValues(
              alpha:
                  0.12,
            ),
            blurRadius:
                10,
            offset:
                const Offset(
              0,
              4,
            ),
          ),
        ],
      ),
      child:
          Text(
        initials,
        style:
            TextStyle(
          color:
              Colors.white,
          fontSize:
              size >= 44
                  ? 14
                  : 10,
          fontWeight:
              FontWeight.w900,
        ),
      ),
    );
  }
}

class _ConversationTile
    extends StatelessWidget {
  final BuyerConversationData
      conversation;

  final bool selected;

  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          selected
              ? const Color(
                  0xFFF3E4DE,
                )
              : const Color(
                  0xFFFFFDF9,
                ),
      child:
          InkWell(
        onTap:
            onTap,
        child:
            Container(
          padding:
              const EdgeInsets.fromLTRB(
            14,
            13,
            14,
            13,
          ),
          decoration:
              BoxDecoration(
            border:
                selected
                    ? const Border(
                        left:
                            BorderSide(
                          color:
                              Color(
                            0xFF561C17,
                          ),
                          width:
                              4,
                        ),
                      )
                    : null,
          ),
          child:
              Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _SellerAvatar(
                seller:
                    conversation,
                size:
                    44,
              ),

              const SizedBox(
                width:
                    11,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child:
                              Text(
                            conversation.name,
                            maxLines:
                                1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                TextStyle(
                              color:
                                  const Color(
                                0xFF3B211B,
                              ),
                              fontSize:
                                  13.5,
                              fontWeight:
                                  conversation.unread >
                                          0
                                      ? FontWeight.w900
                                      : FontWeight.w800,
                            ),
                          ),
                        ),

                        if (conversation.time
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(
                            width:
                                6,
                          ),

                          Text(
                            conversation.time,
                            style:
                                const TextStyle(
                              color:
                                  Color(
                                0xFFA99386,
                              ),
                              fontSize:
                                  10.5,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(
                      height:
                          4,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child:
                              Text(
                            conversation.lastMessage
                                    .trim()
                                    .isEmpty
                                ? 'Start a conversation with this seller.'
                                : conversation.lastMessage,
                            maxLines:
                                1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                TextStyle(
                              color:
                                  const Color(
                                0xFF987865,
                              ),
                              fontSize:
                                  12,
                              fontWeight:
                                  conversation.unread >
                                          0
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                            ),
                          ),
                        ),

                        if (conversation.unread >
                            0) ...[
                          const SizedBox(
                            width:
                                7,
                          ),

                          Container(
                            constraints:
                                const BoxConstraints(
                              minWidth:
                                  20,
                              minHeight:
                                  20,
                            ),
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal:
                                  6,
                            ),
                            decoration:
                                const BoxDecoration(
                              color:
                                  Color(
                                0xFF561C17,
                              ),
                              shape:
                                  BoxShape.circle,
                            ),
                            alignment:
                                Alignment.center,
                            child:
                                Text(
                              conversation.unread >
                                      99
                                  ? '99+'
                                  : '${conversation.unread}',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontSize:
                                    10.5,
                                fontWeight:
                                    FontWeight.w900,
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

class _MessageBubble
    extends StatelessWidget {
  final BuyerMessageData message;

  final BuyerConversationData seller;

  const _MessageBubble({
    required this.message,
    required this.seller,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final double maxBubbleWidth =
            constraints.maxWidth *
                0.80;

        return Padding(
          padding:
              const EdgeInsets.only(
            top:
                12,
          ),
          child:
              Align(
            alignment:
                message.fromBuyer
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
            child:
                Row(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                if (!message
                    .fromBuyer) ...[
                  _SellerAvatar(
                    seller:
                        seller,
                    size:
                        30,
                  ),

                  const SizedBox(
                    width:
                        7,
                  ),
                ],

                Flexible(
                  child:
                      ConstrainedBox(
                    constraints:
                        BoxConstraints(
                      maxWidth:
                          maxBubbleWidth,
                    ),
                    child:
                        Container(
                      padding:
                          const EdgeInsets.fromLTRB(
                        13,
                        11,
                        13,
                        9,
                      ),
                      decoration:
                          BoxDecoration(
                        gradient:
                            message.fromBuyer
                                ? const LinearGradient(
                                    begin:
                                        Alignment.topLeft,
                                    end:
                                        Alignment.bottomRight,
                                    colors:
                                        <Color>[
                                      Color(
                                        0xFF561C17,
                                      ),
                                      Color(
                                        0xFF642920,
                                      ),
                                    ],
                                  )
                                : null,
                        color:
                            message.fromBuyer
                                ? null
                                : const Color(
                                    0xFFFFFDF9,
                                  ),
                        border:
                            Border.all(
                          color:
                              message.fromBuyer
                                  ? const Color(
                                      0xFF561C17,
                                    )
                                  : const Color(
                                      0xFFEADCCC,
                                    ),
                        ),
                        borderRadius:
                            BorderRadius.only(
                          topLeft:
                              Radius.circular(
                            message.fromBuyer
                                ? 17
                                : 5,
                          ),
                          topRight:
                              Radius.circular(
                            message.fromBuyer
                                ? 5
                                : 17,
                          ),
                          bottomLeft:
                              const Radius.circular(
                            17,
                          ),
                          bottomRight:
                              const Radius.circular(
                            17,
                          ),
                        ),
                        boxShadow:
                            <BoxShadow>[
                          BoxShadow(
                            color:
                                const Color(
                              0xFF561C17,
                            ).withValues(
                              alpha: 0.05,
                            ),
                            blurRadius:
                                16,
                            offset:
                                const Offset(
                              0,
                              5,
                            ),
                          ),
                        ],
                      ),
                      child:
                          Column(
                        crossAxisAlignment:
                            message.fromBuyer
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                        children: [
                          if (message.hasAttachment) ...[
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(
                                10,
                              ),
                              child:
                                  Image.network(
                                message.attachmentUrl!,
                                width:
                                    220,
                                height:
                                    150,
                                fit:
                                    BoxFit.cover,
                                errorBuilder:
                                    (
                                  BuildContext context,
                                  Object error,
                                  StackTrace? stackTrace,
                                ) {
                                  return Container(
                                    width:
                                        220,
                                    padding:
                                        const EdgeInsets.all(
                                      12,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          message.fromBuyer
                                              ? const Color(0x22FFFFFF)
                                              : const Color(0xFFF6EFE7),
                                      borderRadius:
                                          BorderRadius.circular(
                                        10,
                                      ),
                                    ),
                                    child:
                                        Row(
                                      children: [
                                        Icon(
                                          Icons.attachment_rounded,
                                          color:
                                              message.fromBuyer
                                                  ? Colors.white
                                                  : const Color(0xFF561C17),
                                        ),
                                        const SizedBox(
                                          width:
                                              8,
                                        ),
                                        Expanded(
                                          child:
                                              Text(
                                            message.attachmentName ??
                                                'Attachment',
                                            maxLines:
                                                1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style:
                                                TextStyle(
                                              color:
                                                  message.fromBuyer
                                                      ? Colors.white
                                                      : const Color(0xFF3B211B),
                                              fontSize:
                                                  12,
                                              fontWeight:
                                                  FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (message.body.trim().isNotEmpty)
                              const SizedBox(
                                height:
                                    8,
                              ),
                          ],
                          if (message.body.trim().isNotEmpty)
                          Text(
                            message.body,
                            style:
                                TextStyle(
                              color:
                                  message.fromBuyer
                                      ? Colors.white
                                      : const Color(
                                          0xFF3B211B,
                                        ),
                              fontSize:
                                  13,
                              height:
                                  1.55,
                            ),
                          ),

                          if (message.time
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(
                              height:
                                  5,
                            ),

                            Text(
                              message.time,
                              style:
                                  TextStyle(
                                color:
                                    message.fromBuyer
                                        ? const Color(
                                            0xFFE8C8B2,
                                          )
                                        : const Color(
                                            0xFFA99386,
                                          ),
                                fontSize:
                                    10.5,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductInquiryCard
    extends StatelessWidget {
  final MessageProductReference product;

  final VoidCallback? onTap;

  const _ProductInquiryCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Align(
      alignment:
          Alignment.centerRight,
      child:
          Material(
        color:
            Colors.transparent,
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        child:
            InkWell(
          onTap:
              onTap,
          borderRadius:
              BorderRadius.circular(
            17,
          ),
          child:
              Container(
            width:
                double.infinity,
            constraints:
                const BoxConstraints(
              maxWidth:
                  420,
            ),
            padding:
                const EdgeInsets.all(
              13,
            ),
            decoration:
                BoxDecoration(
              gradient:
                  const LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors:
                    <Color>[
                  Color(
                    0xFF561C17,
                  ),
                  Color(
                    0xFF642920,
                  ),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(
                17,
              ),
              boxShadow:
                  <BoxShadow>[
                BoxShadow(
                  color:
                      const Color(
                    0xFF561C17,
                  ).withValues(
                    alpha: 0.15,
                  ),
                  blurRadius:
                      20,
                  offset:
                      const Offset(
                    0,
                    8,
                  ),
                ),
              ],
            ),
            child:
                Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width:
                      48,
                  height:
                      48,
                  clipBehavior:
                      Clip.antiAlias,
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      11,
                    ),
                    border:
                        Border.all(
                      color:
                          Colors.white.withValues(
                        alpha: 0.16,
                      ),
                    ),
                  ),
                  child:
                      product.imageUrl
                                  ?.trim()
                                  .isNotEmpty ==
                              true
                          ? Image.network(
                              product.imageUrl!,
                              fit:
                                  BoxFit.cover,
                              errorBuilder:
                                  (
                                BuildContext context,
                                Object error,
                                StackTrace? stackTrace,
                              ) {
                                return const Icon(
                                  Icons
                                      .shopping_bag_outlined,
                                  color:
                                      Colors.white,
                                  size:
                                      20,
                                );
                              },
                            )
                          : const Icon(
                              Icons
                                  .shopping_bag_outlined,
                              color:
                                  Colors.white,
                              size:
                                  20,
                            ),
                ),

                const SizedBox(
                  width:
                      10,
                ),

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PRODUCT INQUIRY',
                        style:
                            TextStyle(
                          color:
                              Color(
                            0xFFE8C8B2,
                          ),
                          fontSize:
                              10.5,
                          letterSpacing:
                              1,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),

                      const SizedBox(
                        height:
                            4,
                      ),

                      Text(
                        product.name,
                        maxLines:
                            2,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              13,
                          height:
                              1.45,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),

                      if (product.price !=
                          null) ...[
                        const SizedBox(
                          height:
                              4,
                        ),

                        Text(
                          '₱${product.price!.toStringAsFixed(2)}',
                          style:
                              const TextStyle(
                            color:
                                Color(
                              0xFFFFE7D9,
                            ),
                            fontSize:
                                12,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (onTap !=
                    null) ...[
                  const SizedBox(
                    width:
                        6,
                  ),

                  const Icon(
                    Icons
                        .chevron_right_rounded,
                    color:
                        Colors.white,
                    size:
                        20,
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

class _SellerStatus
    extends StatelessWidget {
  final String label;

  final bool? isOnline;

  const _SellerStatus({
    required this.label,
    required this.isOnline,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final Color textColor =
        isOnline == true
            ? const Color(
                0xFF256F4A,
              )
            : const Color(
                0xFF987865,
              );

    return Row(
      children: [
        if (isOnline != null) ...[
          Container(
            width:
                7,
            height:
                7,
            decoration:
                BoxDecoration(
              color:
                  isOnline == true
                      ? const Color(
                          0xFF256F4A,
                        )
                      : const Color(
                          0xFFA99386,
                        ),
              shape:
                  BoxShape.circle,
            ),
          ),

          const SizedBox(
            width:
                5,
          ),
        ],

        Expanded(
          child:
              Text(
            label,
            maxLines:
                1,
            overflow:
                TextOverflow.ellipsis,
            style:
                TextStyle(
              color:
                  textColor,
              fontSize:
                  11.5,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SellerAvatar
    extends StatelessWidget {
  final BuyerConversationData seller;

  final double size;

  const _SellerAvatar({
    required this.seller,
    required this.size,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final String? url =
        seller.avatarUrl
            ?.trim();

    return Container(
      width:
          size,
      height:
          size,
      clipBehavior:
          Clip.antiAlias,
      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,
        color:
            const Color(
          0xFF561C17,
        ),
        border:
            Border.all(
          color:
              Colors.white,
          width:
              2,
        ),
        boxShadow:
            <BoxShadow>[
          BoxShadow(
            color:
                const Color(
              0xFF561C17,
            ).withValues(
              alpha: 0.12,
            ),
            blurRadius:
                12,
            offset:
                const Offset(
              0,
              5,
            ),
          ),
        ],
      ),
      child:
          url == null ||
                  url.isEmpty
              ? _InitialAvatar(
                  initials:
                      seller.initials,
                )
              : Image.network(
                  url,
                  fit:
                      BoxFit.cover,
                  loadingBuilder:
                      (
                    BuildContext context,
                    Widget child,
                    ImageChunkEvent? progress,
                  ) {
                    if (progress == null) {
                      return child;
                    }

                    return const Center(
                      child:
                          SizedBox(
                        width:
                            15,
                        height:
                            15,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              1.5,
                          color:
                              Colors.white,
                        ),
                      ),
                    );
                  },
                  errorBuilder:
                      (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) {
                    return _InitialAvatar(
                      initials:
                          seller.initials,
                    );
                  },
                ),
    );
  }
}

class _InitialAvatar
    extends StatelessWidget {
  final String initials;

  const _InitialAvatar({
    required this.initials,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      color:
          const Color(
        0xFF561C17,
      ),
      alignment:
          Alignment.center,
      child:
          Text(
        initials,
        style:
            const TextStyle(
          color:
              Colors.white,
          fontSize:
              13,
          fontWeight:
              FontWeight.w900,
        ),
      ),
    );
  }
}