enum MessageStatus { processing, sent, error }

class ChatMessage {
  final String id;
  final String senderName;
  final int senderTelegramId;
  final String query;
  String response;
  final DateTime timestamp;
  MessageStatus status;

  ChatMessage({
    required this.id,
    required this.senderName,
    required this.senderTelegramId,
    required this.query,
    this.response = '',
    required this.timestamp,
    this.status = MessageStatus.processing,
  });

  Duration get processingDuration {
    if (status == MessageStatus.processing) {
      return DateTime.now().difference(timestamp);
    }
    return Duration.zero;
  }
}
