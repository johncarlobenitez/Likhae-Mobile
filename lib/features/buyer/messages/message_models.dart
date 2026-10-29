class BuyerMessageData {
  final String id;
  final String conversationId;

  final String body;
  final String time;
  final DateTime? sentAt;

  final bool fromBuyer;

  /// Optional attachment returned by Laravel.
  /// Existing text-only messages can leave these null.
  final String? attachmentUrl;
  final String? attachmentName;

  /// True when the other conversation participant has read this message.
  /// Null means the API did not provide a read receipt.
  final bool? seenByRecipient;

  const BuyerMessageData({
    required this.id,
    required this.body,
    required this.time,
    this.sentAt,
    required this.fromBuyer,
    this.conversationId = '',
    this.attachmentUrl,
    this.attachmentName,
    this.seenByRecipient,
  });

  BuyerMessageData copyWith({bool? seenByRecipient}) => BuyerMessageData(
    id: id,
    conversationId: conversationId,
    body: body,
    time: time,
    sentAt: sentAt,
    fromBuyer: fromBuyer,
    attachmentUrl: attachmentUrl,
    attachmentName: attachmentName,
    seenByRecipient: seenByRecipient ?? this.seenByRecipient,
  );

  bool get hasAttachment => attachmentUrl?.trim().isNotEmpty == true;

  bool get isAttachmentPlaceholder {
    return RegExp(
      r'^\[(photo|image|attachment)\]$',
      caseSensitive: false,
    ).hasMatch(body.trim());
  }
}

class BuyerConversationPresenceData {
  final bool isOnline;
  final DateTime? recipientReadAt;

  const BuyerConversationPresenceData({
    required this.isOnline,
    this.recipientReadAt,
  });
}

class MessageOrderProduct {
  final String name;
  final String? imageUrl;
  final String? variant;
  final int quantity;

  const MessageOrderProduct({
    required this.name,
    required this.quantity,
    this.imageUrl,
    this.variant,
  });
}

class MessageOrderContext {
  final String orderReference;
  final String status;
  final String orderId;
  final String sellerOrderId;
  final List<MessageOrderProduct> products;

  const MessageOrderContext({
    required this.orderReference,
    required this.status,
    this.orderId = '',
    this.sellerOrderId = '',
    this.products = const <MessageOrderProduct>[],
  });
}
