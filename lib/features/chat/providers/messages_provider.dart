import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/profile_model.dart';
import '../models/message_model.dart';

final cryptoServiceProvider = Provider<CryptoService>((ref) => CryptoService());

/// Provides the other participant's profile for a conversation.
final otherParticipantProvider = FutureProvider.family<ProfileModel?, String>((ref, conversationId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final client = ref.watch(supabaseClientProvider);

  final conv = await client
      .from(SupabaseConstants.conversationsTable)
      .select('''
        participant_1,
        participant_2,
        p1:profiles!conversations_participant_1_fkey(id, username, public_key, created_at),
        p2:profiles!conversations_participant_2_fkey(id, username, public_key, created_at)
      ''')
      .eq('id', conversationId)
      .single();

  final isP1 = conv['participant_1'] == user.id;
  final otherJson = isP1 ? conv['p2'] : conv['p1'];
  if (otherJson == null) return null;
  return ProfileModel.fromJson(otherJson as Map<String, dynamic>);
});

/// Computes the shared secret with the other participant.
final sharedSecretProvider = FutureProvider.family<Uint8List?, String>((ref, conversationId) async {
  final keyManager = ref.watch(keyManagerProvider);
  final otherProfile = await ref.watch(otherParticipantProvider(conversationId).future);
  if (otherProfile == null) return null;

  final keyPair = await keyManager.loadKeyPair();
  if (keyPair == null) return null;

  final cryptoService = ref.watch(cryptoServiceProvider);
  return cryptoService.deriveSharedSecret(ourKeyPair: keyPair, theirPublicKeyBase64: otherProfile.publicKey);
});

/// Fetches and decrypts all messages for a conversation.
class MessagesNotifier extends AsyncNotifier<List<MessageModel>> {
  late String _conversationId;
  RealtimeChannel? _channel;

  @override
  Future<List<MessageModel>> build() async {
    ref.onDispose(() => _channel?.unsubscribe());
    return [];
  }

  void init(String conversationId) {
    _conversationId = conversationId;
    unawaited(_loadMessages());
    _subscribeToRealtime();
  }

  Future<void> _loadMessages() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(supabaseClientProvider);
      final response = await client
          .from(SupabaseConstants.messagesTable)
          .select()
          .eq('conversation_id', _conversationId)
          .order('created_at', ascending: true);

      final messages = (response as List).map((json) => MessageModel.fromJson(json as Map<String, dynamic>)).toList();
      final decrypted = await _decryptAll(messages);

      // Marquer tous les messages non lus de l'autre utilisateur comme lus
      final user = ref.read(currentUserProvider);
      if (user != null) {
        final unreadIds = decrypted.where((m) => m.senderId != user.id && !m.isRead).map((m) => m.id).toList();
        if (unreadIds.isNotEmpty) {
          await client.from(SupabaseConstants.messagesTable).update({'is_read': true}).inFilter('id', unreadIds);
          return decrypted.map((m) => unreadIds.contains(m.id) ? (m.copyWith(isRead: true) as MessageModel) : m).toList();
        }
      }

      return decrypted;
    });
  }

  Future<List<MessageModel>> _decryptAll(List<MessageModel> messages) async {
    final sharedSecret = await ref.read(sharedSecretProvider(_conversationId).future);

    if (sharedSecret == null) return messages;

    final cryptoService = ref.read(cryptoServiceProvider);

    for (final msg in messages) {
      msg.decryptedContent =
          await cryptoService.decryptMessage(ciphertextBase64: msg.encryptedContent, ivBase64: msg.iv, sharedSecret: sharedSecret) ??
          '[chiffrement invalide]';
    }

    return messages;
  }

  void _subscribeToRealtime() {
    final client = ref.read(supabaseClientProvider);

    _channel = client
        .channel('messages:$_conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConstants.messagesTable,
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: _conversationId),
          callback: (payload) async {
            final newMsg = MessageModel.fromJson(payload.newRecord);
            final sharedSecret = await ref.read(sharedSecretProvider(_conversationId).future);

            if (sharedSecret != null) {
              final cryptoService = ref.read(cryptoServiceProvider);
              newMsg.decryptedContent =
                  await cryptoService.decryptMessage(ciphertextBase64: newMsg.encryptedContent, ivBase64: newMsg.iv, sharedSecret: sharedSecret) ??
                  '[chiffrement invalide]';
            }

            final current = state.value ?? [];
            final user = ref.read(currentUserProvider);

            // Marquer immédiatement comme lu si c'est un message reçu
            if (user != null && newMsg.senderId != user.id && !newMsg.isRead) {
              await client.from(SupabaseConstants.messagesTable).update({'is_read': true}).eq('id', newMsg.id);
              final read = newMsg.copyWith(isRead: true) as MessageModel;
              read.decryptedContent = newMsg.decryptedContent;
              state = AsyncData([...current, read]);
            } else {
              state = AsyncData([...current, newMsg]);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConstants.messagesTable,
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: _conversationId),
          callback: (payload) {
            final updatedId = payload.newRecord['id'] as String;
            final isRead = payload.newRecord['is_read'] as bool? ?? false;
            final current = state.value ?? [];
            state = AsyncData(current.map((m) => m.id == updatedId ? (m.copyWith(isRead: isRead) as MessageModel) : m).toList());
          },
        )
        .subscribe();
  }

  Future<void> sendMessage(String plaintext) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final sharedSecret = await ref.read(sharedSecretProvider(_conversationId).future);
    if (sharedSecret == null) throw Exception('Clé partagée introuvable');

    final cryptoService = ref.read(cryptoServiceProvider);
    final (:ciphertext, :iv) = await cryptoService.encryptMessage(plaintext: plaintext, sharedSecret: sharedSecret);

    final client = ref.read(supabaseClientProvider);
    await client.from(SupabaseConstants.messagesTable).insert({
      'conversation_id': _conversationId,
      'sender_id': user.id,
      'encrypted_content': ciphertext,
      'iv': iv,
    });
  }

  Future<void> deleteMessage(String messageId) async {
    final client = ref.read(supabaseClientProvider);
    await client.from(SupabaseConstants.messagesTable).delete().eq('id', messageId);
    //refresh current state
    final current = state.value ?? [];
    state = AsyncData(current.where((m) => m.id != messageId).toList());
  }

  Future<void> markAsRead(String messageId) async {
    final client = ref.read(supabaseClientProvider);
    await client.from(SupabaseConstants.messagesTable).update({'is_read': true}).eq('id', messageId);
    //update current state
    final current = state.value ?? [];
    state = AsyncData(current.map((m) => m.id == messageId ? (m.copyWith(isRead: true) as MessageModel) : m).toList());
  }
}

final messagesNotifierProvider = AsyncNotifierProvider<MessagesNotifier, List<MessageModel>>(MessagesNotifier.new);
