class FcmPromotionMessage {
  const FcmPromotionMessage({
    required this.eventId,
    required this.promotionId,
    required this.establishmentId,
    required this.title,
    required this.body,
  });

  final String eventId;
  final String promotionId;
  final String establishmentId;
  final String title;
  final String body;

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  static bool isUuid(String value) => _uuid.hasMatch(value);

  static FcmPromotionMessage? parse(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    final eventId = data['event_id'];
    final promotionId = data['promotion_id'];
    final establishmentId = data['establishment_id'];
    if (data['type'] != 'promotion' ||
        eventId is! String ||
        promotionId is! String ||
        establishmentId is! String ||
        !_uuid.hasMatch(eventId) ||
        !_uuid.hasMatch(promotionId) ||
        !_uuid.hasMatch(establishmentId)) {
      return null;
    }
    return FcmPromotionMessage(
      eventId: eventId.toLowerCase(),
      promotionId: promotionId.toLowerCase(),
      establishmentId: establishmentId.toLowerCase(),
      title: _bounded(title ?? data['title'], 120) ?? 'Promoción cercana',
      body: _bounded(body ?? data['body'], 240) ?? '',
    );
  }

  static String? _bounded(Object? value, int maxLength) {
    if (value is! String) return null;
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return normalized.length <= maxLength
        ? normalized
        : normalized.substring(0, maxLength);
  }
}
