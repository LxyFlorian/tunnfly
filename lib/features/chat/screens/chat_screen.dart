import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tunnfly/features/chat/models/message_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/messages_provider.dart';
import '../providers/bubble_color_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUsername;

  const ChatScreen({super.key, required this.conversationId, required this.otherUsername});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  late final MessagesNotifier _notifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifier = ref.read(messagesNotifierProvider.notifier);
    Future.microtask(() => _notifier.init(widget.conversationId));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;
    if (bottomInset > 0) _scrollToBottom();
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  Future<void> _editMessage(MessageModel msg) async {
    final controller = TextEditingController(text: msg.decryptedContent ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier'),
        content: TextField(controller: controller, autofocus: true, minLines: 1, maxLines: 4),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Enregistrer')),
        ],
      ),
    );
    final newText = controller.text.trim();

    if (confirmed != true) return;
    if (newText.isEmpty || newText == msg.decryptedContent) return;

    try {
      await _notifier.editMessage(msg.id, newText);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesNotifierProvider);
    final currentUser = ref.watch(currentUserProvider);
    final colorScheme = Theme.of(context).colorScheme;

    messagesAsync.whenData((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUsername),
            Row(
              children: [
                Icon(Icons.lock, size: 10, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 3),
                Text(
                  'Chiffré de bout en bout',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.palette_outlined, color: colorScheme.onSurfaceVariant),
            onPressed: () => _showColorPicker(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colorScheme.outlineVariant),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur: $e')),
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Text('Envoyez un premier message chiffré', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == currentUser?.id;
                      final bubbleColor = ref.watch(bubbleColorProvider(widget.conversationId));
                      return GestureDetector(
                        onLongPressStart: (details) => isMe ? _showMessageOptions(msg, details, isMe) : null,
                        child: _MessageBubble(
                          text: msg.decryptedContent ?? '[déchiffrement en cours...]',
                          isRead: msg.isRead,
                          isMe: isMe,
                          time: msg.createdAt,
                          bubbleColor: bubbleColor,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          _MessageInput(controller: _textController, onSend: _sendMessage),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    const colors = [
      null,
      Color(0xFF6750A4),
      Color(0xFF0061A4),
      Color(0xFF006E1C),
      Color(0xFF006A6A),
      Color(0xFFBA1A1A),
      Color(0xFFE65100),
      Color(0xFFAD1457),
      Color(0xFF4E6F3C),
      Color(0xFF37474F),
    ];

    final notifier = ref.read(bubbleColorProvider(widget.conversationId).notifier);
    final current = ref.read(bubbleColorProvider(widget.conversationId));

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Couleur des bulles', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: colors.map((color) {
                  final isDefault = color == null;
                  final displayColor = isDefault ? colorScheme.primary : color;
                  final isSelected = isDefault ? current == null : current == color;
                  return GestureDetector(
                    onTap: () {
                      if (isDefault) {
                        notifier.reset();
                      } else {
                        notifier.setColor(color);
                      }
                      Navigator.of(ctx).pop();
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: displayColor,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: colorScheme.onSurface, width: 2.5) : Border.all(color: Colors.transparent, width: 2.5),
                      ),
                      child: isDefault ? Icon(Icons.refresh, color: colorScheme.onPrimary, size: 18) : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message copié')));
          },
          onShare: msg.decryptedContent != null ? () => entry.remove() : null,
          onDelete: () {
            entry.remove();
            _deleteMessage(msg.id);
          },
          onEdit: () {
            entry.remove();
            _editMessage(msg);
          },
        );
      },
    );

    overlay.insert(entry);
  }
}

Color _contrastColor(Color bg) {
  return bg.computeLuminance() > 0.35 ? Colors.black87 : Colors.white;
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final DateTime time;
  final bool isRead;
  final Color? bubbleColor;

  const _MessageBubble({required this.text, required this.isMe, required this.time, required this.isRead, this.bubbleColor});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeStr = DateFormat('HH:mm').format(time.toLocal());
    final bubbleColor = isMe ? (this.bubbleColor ?? colorScheme.primary) : colorScheme.surfaceContainerHighest;
    final textColor = isMe ? (this.bubbleColor != null ? _contrastColor(this.bubbleColor!) : colorScheme.onPrimary) : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
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
                  Text(text, style: TextStyle(color: textColor, fontSize: 15, height: 1.4)),
                  const SizedBox(height: 3),
                  Text(timeStr, style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.55))),
                ],
              ),
            ),
          ),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 2),
              child: Container(
                height: 14,
                width: 14,
                decoration: BoxDecoration(
                  color: isRead ? bubbleColor : Colors.transparent,
                  border: Border.all(color: isRead ? bubbleColor : colorScheme.outline, width: 1.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, size: 9, color: isRead ? textColor : colorScheme.outline),
              ),
            ),
        ],
      ),
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
  final VoidCallback onEdit;

  const _MessageContextMenu({
    required this.tapPosition,
    required this.isMe,
    required this.onDismiss,
    required this.onCopy,
    this.onShare,
    required this.onDelete,
    required this.onEdit,
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
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
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
    const menuWidth = 190.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final colorScheme = Theme.of(context).colorScheme;

    double top = widget.tapPosition.dy + 10;
    double left = widget.isMe ? widget.tapPosition.dx - menuWidth + 16 : widget.tapPosition.dx - 16;
    left = left.clamp(8.0, screenWidth - menuWidth - 8);

    const estimatedHeight = 160.0;
    if (top + estimatedHeight > screenHeight - 24) {
      top = widget.tapPosition.dy - estimatedHeight - 10;
    }

    final alignment = widget.isMe ? Alignment.topRight : Alignment.topLeft;

    Widget buildItem(IconData icon, String label, VoidCallback onTap, {Color? color}) {
      final itemColor = color ?? colorScheme.onSurface;
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 18, color: itemColor.withValues(alpha: 0.8)),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontSize: 14, color: itemColor)),
            ],
          ),
        ),
      );
    }

    final divider = Divider(height: 1, color: colorScheme.outlineVariant);

    final children = <Widget>[
      buildItem(Icons.copy_rounded, 'Copier', widget.onCopy),
      divider,
      buildItem(Icons.edit_outlined, 'Modifier', widget.onEdit),
      if (widget.onShare != null) ...[divider, buildItem(Icons.share_rounded, 'Partager', widget.onShare!)],
      divider,
      buildItem(Icons.delete_outline, 'Supprimer', widget.onDelete, color: const Color(0xFFB00020)),
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
                    elevation: 8,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Message',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  fillColor: colorScheme.surfaceContainerHighest,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                child: Icon(Icons.arrow_upward_rounded, color: colorScheme.onPrimary, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
