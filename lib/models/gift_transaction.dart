class GiftTransaction {
  final String id;
  final String giftId;
  final String senderId;
  final String recipientId;
  final String roomId;
  final int cost;
  final DateTime sentAt;
  final String? message; // Optional message with gift

  const GiftTransaction({
    required this.id,
    required this.giftId,
    required this.senderId,
    required this.recipientId,
    required this.roomId,
    required this.cost,
    required this.sentAt,
    this.message,
  });

  factory GiftTransaction.fromMap(Map<String, dynamic> map) {
    return GiftTransaction(
      id: map['id'] ?? map['\$id'] ?? '',
      giftId: map['giftId'] ?? '',
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'] ?? '',
      roomId: map['roomId'] ?? '',
      cost: map['cost'] ?? 0,
      sentAt: DateTime.parse(
        map['sentAt'] ?? map['\$createdAt'] ?? DateTime.now().toIso8601String()
      ),
      message: map['message'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'giftId': giftId,
      'senderId': senderId,
      'recipientId': recipientId,
      'roomId': roomId,
      'cost': cost,
      'sentAt': sentAt.toIso8601String(),
      'message': message,
    };
  }
} 