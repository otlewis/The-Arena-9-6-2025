/// Model for real money tips sent via Stripe
class MoneyTip {
  final String id;
  final String senderId;
  final String recipientId;
  final double amount; // in USD
  final String currency;
  final String? message;
  final DateTime createdAt;
  final TipStatus status;
  final String? stripePaymentIntentId;
  final String? roomId;
  final RoomType? roomType;

  const MoneyTip({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.amount,
    this.currency = 'usd',
    this.message,
    required this.createdAt,
    required this.status,
    this.stripePaymentIntentId,
    this.roomId,
    this.roomType,
  });

  factory MoneyTip.fromMap(Map<String, dynamic> map) {
    return MoneyTip(
      id: map['id'] ?? map['\$id'] ?? '',
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'usd',
      message: map['message'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      status: TipStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => TipStatus.pending,
      ),
      stripePaymentIntentId: map['stripePaymentIntentId'],
      roomId: map['roomId'],
      roomType: map['roomType'] != null
          ? RoomType.values.firstWhere(
              (t) => t.name == map['roomType'],
              orElse: () => RoomType.discussion,
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'recipientId': recipientId,
      'amount': amount,
      'currency': currency,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'stripePaymentIntentId': stripePaymentIntentId,
      'roomId': roomId,
      'roomType': roomType?.name,
    };
  }
}

enum TipStatus {
  pending,
  processing,
  succeeded,
  failed,
  refunded,
}

enum RoomType {
  arena,
  debate,
  discussion,
  take,
}
