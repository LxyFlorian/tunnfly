import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/conversations_provider.dart';
import 'chat_screen.dart';
import 'new_conversation_screen.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tunnfly'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Déconnexion',
            onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 64),
                  const SizedBox(height: 16),
                  Text('Aucune conversation', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Commencez une nouvelle conversation'),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final conv = conversations[index];
              final other = conv.otherParticipant;

              return ListTile(
                leading: CircleAvatar(child: Text(other?.username.substring(0, 1).toUpperCase() ?? '?')),
                title: Text(other?.username ?? 'Inconnu'),
                subtitle: const Text('Chiffré de bout en bout', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(conversationId: conv.id, otherUsername: other?.username ?? 'Inconnu'),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newConvId = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const NewConversationScreen()));
          if (newConvId != null && context.mounted) {
            ref.invalidate(conversationsProvider);
          }
        },
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }
}
