class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String encryptedContent;
  final String iv;
  final DateTime createdAt;
  // Set after decryption on the client
  String? decryptedContent;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.encryptedContent,
    required this.iv,
    required this.createdAt,
    this.decryptedContent,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      encryptedContent: json['encrypted_content'] as String,
      iv: json['iv'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'encrypted_content': encryptedContent,
        'iv': iv,
      };
}
