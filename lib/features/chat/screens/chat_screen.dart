import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tunnfly/features/chat/models/message_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/messages_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUsername;

  const ChatScreen({super.key, required this.conversationId, required this.otherUsername});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  late final MessagesNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(messagesNotifierProvider.notifier);
    Future.microtask(() => _notifier.init(widget.conversationId));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();

    try {
      await _notifier.sendMessage(text);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await _notifier.deleteMessage(messageId);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesNotifierProvider);
    final currentUser = ref.watch(currentUserProvider);

    // Scroll when new messages arrive
    messagesAsync.whenData((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUsername),
            const Row(
              children: [
                Icon(Icons.lock, size: 12),
                SizedBox(width: 4),
                Text('Chiffré de bout en bout', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('Envoyez un premier message chiffré'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUser?.id;
                    return GestureDetector(
                      onLongPressStart: (details) => isMe ? _showMessageOptions(msg, details, isMe) : null,
                      child: _MessageBubble(
                        text: msg.decryptedContent ?? '[déchiffrement en cours...]',
                        isRead: msg.isRead,
                        isMe: isMe,
                        time: msg.createdAt,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _MessageInput(controller: _textController, onSend: _sendMessage),
        ],
      ),
    );
  }

  void _showMessageOptions(MessageModel msg, LongPressStartDetails details, bool isMe) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) {
        return _MessageContextMenu(
          tapPosition: details.globalPosition,
          isMe: isMe,
          onDismiss: () => entry.remove(),
          onCopy: () {
            entry.remove();
            Clipboard.setData(ClipboardData(text: msg.decryptedContent ?? ''));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message copié dans le presse-papiers')));
          },
          onShare: msg.decryptedContent != null ? () => entry.remove() : null,
          onDelete: () {
            entry.remove();
            _deleteMessage(msg.id);
          },
        );
      },
    );

    overlay.insert(entry);
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final DateTime time;
  final bool isRead;

  const _MessageBubble({required this.text, required this.isMe, required this.time, required this.isRead});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeStr = DateFormat('HH:mm').format(time.toLocal());

    return Column(
      children: [
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? colorScheme.primary : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(text, style: TextStyle(color: isMe ? colorScheme.onPrimary : colorScheme.onSurface)),
                const SizedBox(height: 4),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? colorScheme.onPrimary.withValues(alpha: 0.7) : colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        Visibility(
          visible: isMe,
          child: Align(
            alignment: AlignmentGeometry.centerRight,
            child: Container(
              height: 15,
              width: 15,
              decoration: BoxDecoration(
                color: isRead ? colorScheme.primary : Colors.transparent,
                border: Border.all(color: isRead ? colorScheme.primary : colorScheme.outline),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, size: 10, color: isRead ? colorScheme.onPrimary : colorScheme.outline),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageContextMenu extends StatefulWidget {
  final Offset tapPosition;
  final bool isMe;
  final VoidCallback onDismiss;
  final VoidCallback onCopy;
  final VoidCallback? onShare;
  final VoidCallback onDelete;

  const _MessageContextMenu({
    required this.tapPosition,
    required this.isMe,
    required this.onDismiss,
    required this.onCopy,
    this.onShare,
    required this.onDelete,
  });

  @override
  State<_MessageContextMenu> createState() => _MessageContextMenuState();
}

class _MessageContextMenuState extends State<_MessageContextMenu> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const menuWidth = 200.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final colorScheme = Theme.of(context).colorScheme;

    double top = widget.tapPosition.dy + 10;
    double left;
    if (widget.isMe) {
      left = widget.tapPosition.dx - menuWidth + 16;
    } else {
      left = widget.tapPosition.dx - 16;
    }
    left = left.clamp(8.0, screenWidth - menuWidth - 8);

    // Estimate menu height (3 items max ≈ 48 * 3 + dividers)
    const estimatedHeight = 160.0;
    if (top + estimatedHeight > screenHeight - 24) {
      top = widget.tapPosition.dy - estimatedHeight - 10;
    }

    final alignment = widget.isMe ? Alignment.topRight : Alignment.topLeft;

    Widget buildItem(IconData icon, String label, VoidCallback onTap, {Color? color}) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color ?? colorScheme.onSurface),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontSize: 15, color: color ?? colorScheme.onSurface)),
            ],
          ),
        ),
      );
    }

    final divider = Divider(height: 1, color: colorScheme.outlineVariant);

    final children = <Widget>[
      buildItem(Icons.copy_rounded, 'Copier', widget.onCopy),
      if (widget.onShare != null) ...[divider, buildItem(Icons.share_rounded, 'Partager', widget.onShare!)],
      divider,
      buildItem(Icons.delete_outline, 'Supprimer', widget.onDelete, color: Colors.red),
    ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDismiss,
      child: Stack(
        children: [
          Positioned(
            top: top,
            left: left,
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                alignment: alignment,
                child: GestureDetector(
                  onTap: () {},
                  child: Material(
                    elevation: 12,
                    shadowColor: Colors.black38,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    color: colorScheme.surface,
                    child: SizedBox(
                      width: menuWidth,
                      child: Column(mainAxisSize: MainAxisSize.min, children: children),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageInput({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Message chiffré...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: onSend, icon: const Icon(Icons.send_rounded)),
          ],
        ),
      ),
    );
  }
}
