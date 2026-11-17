/// Per-user limits configured by the administrator.
class UserPermissions {
  const UserPermissions({
    required this.id,
    required this.userId,
    required this.canScan,
    required this.maxProducts,
    required this.subscriptionStart,
    required this.subscriptionEnd,
  });

  final int id;
  final int userId;
  final bool canScan;
  final int maxProducts;
  final DateTime subscriptionStart;

  /// `null` means the subscription never expires.
  final DateTime? subscriptionEnd;

  bool isExpiredAt(DateTime now) =>
      subscriptionEnd != null && now.isAfter(subscriptionEnd!);

  UserPermissions copyWith({
    bool? canScan,
    int? maxProducts,
    DateTime? subscriptionStart,
    DateTime? subscriptionEnd,
    bool clearSubscriptionEnd = false,
  }) =>
      UserPermissions(
        id: id,
        userId: userId,
        canScan: canScan ?? this.canScan,
        maxProducts: maxProducts ?? this.maxProducts,
        subscriptionStart: subscriptionStart ?? this.subscriptionStart,
        subscriptionEnd: clearSubscriptionEnd
            ? null
            : (subscriptionEnd ?? this.subscriptionEnd),
      );

  factory UserPermissions.fromMap(Map<String, Object?> map) {
    final end = map['subscription_end'] as String?;
    return UserPermissions(
      id: map['id']! as int,
      userId: map['user_id']! as int,
      canScan: (map['can_scan']! as int) == 1,
      maxProducts: map['max_products']! as int,
      subscriptionStart: DateTime.parse(map['subscription_start']! as String),
      subscriptionEnd: end == null ? null : DateTime.parse(end),
    );
  }
}
