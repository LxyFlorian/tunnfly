import '../../auth/models/profile_model.dart';

class ConversationModel {
  final String id;
  final String participant1Id;
  final String participant2Id;
  final DateTime createdAt;
  // Populated by join query
  final ProfileModel? otherParticipant;
  final MessagePreview? lastMessage;

  const ConversationModel({
    required this.id,
    required this.participant1Id,
    required this.participant2Id,
    required this.createdAt,
    this.otherParticipant,
    this.lastMessage,
  });

  factory ConversationModel.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    ProfileModel? otherParticipant;

    if (currentUserId != null) {
      final p1 = json['participant_1_profile'];
      final p2 = json['participant_2_profile'];
      if (p1 != null && p1['id'] != currentUserId) {
        otherParticipant = ProfileModel.fromJson(p1 as Map<String, dynamic>);
      } else if (p2 != null) {
        otherParticipant = ProfileModel.fromJson(p2 as Map<String, dynamic>);
      }
    }

    return ConversationModel(
      id: json['id'] as String,
      participant1Id: json['participant_1'] as String,
      participant2Id: json['participant_2'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      otherParticipant: otherParticipant,
    );
  }
}

class MessagePreview {
  final String decryptedText;
  final DateTime sentAt;

  const MessagePreview({required this.decryptedText, required this.sentAt});
}
