import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/profile_model.dart';
import '../models/conversation_model.dart';

/// Fetches all conversations for the current user.
final conversationsProvider =
    FutureProvider<List<ConversationModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final client = ref.watch(supabaseClientProvider);

  final response = await client
      .from(SupabaseConstants.conversationsTable)
      .select('''
        id,
        participant_1,
        participant_2,
        created_at,
        participant_1_profile:profiles!conversations_participant_1_fkey(id, username, public_key, created_at),
        participant_2_profile:profiles!conversations_participant_2_fkey(id, username, public_key, created_at)
      ''')
      .or('participant_1.eq.${user.id},participant_2.eq.${user.id}')
      .order('created_at', ascending: false);

  return (response as List)
      .map(
        (json) => ConversationModel.fromJson(
          json as Map<String, dynamic>,
          currentUserId: user.id,
        ),
      )
      .toList();
});

/// Searches for users by username to start a new conversation.
final userSearchProvider =
    FutureProvider.family<List<ProfileModel>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];

  final user = ref.watch(currentUserProvider);
  final client = ref.watch(supabaseClientProvider);

  final response = await client
      .from(SupabaseConstants.profilesTable)
      .select()
      .ilike('username', '%$query%')
      .neq('id', user?.id ?? '')
      .limit(20);

  return (response as List)
      .map((json) => ProfileModel.fromJson(json as Map<String, dynamic>))
      .toList();
});

class ConversationsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Creates a new conversation between the current user and another user.
  /// Returns the conversation ID.
  Future<String> startConversation(String otherUserId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Not authenticated');

    final client = ref.read(supabaseClientProvider);

    // Check if a conversation already exists
    final existing = await client
        .from(SupabaseConstants.conversationsTable)
        .select('id')
        .or(
          'and(participant_1.eq.${user.id},participant_2.eq.$otherUserId),'
          'and(participant_1.eq.$otherUserId,participant_2.eq.${user.id})',
        )
        .maybeSingle();

    if (existing != null) {
      return existing['id'] as String;
    }

    // Ensure deterministic ordering so the unique constraint works
    final p1 = user.id.compareTo(otherUserId) < 0 ? user.id : otherUserId;
    final p2 = p1 == user.id ? otherUserId : user.id;

    final response = await client
        .from(SupabaseConstants.conversationsTable)
        .insert({'participant_1': p1, 'participant_2': p2})
        .select('id')
        .single();

    ref.invalidate(conversationsProvider);
    return response['id'] as String;
  }
}

final conversationsNotifierProvider =
    AsyncNotifierProvider<ConversationsNotifier, void>(
  ConversationsNotifier.new,
);
