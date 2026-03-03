import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/telegram_bot_service.dart';
import '../widgets/message_bubble.dart';

class ChatLogScreen extends StatefulWidget {
  final TelegramBotService botService;

  const ChatLogScreen({
    super.key,
    required this.botService,
  });

  @override
  State<ChatLogScreen> createState() => _ChatLogScreenState();
}

class _ChatLogScreenState extends State<ChatLogScreen> {
  final _scrollController = ScrollController();
  DateTime? _filterDate;

  @override
  void initState() {
    super.initState();
    widget.botService.addListener(_onMessagesChanged);
  }

  @override
  void dispose() {
    widget.botService.removeListener(_onMessagesChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onMessagesChanged() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.botService,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chat Log',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Messages: ${widget.botService.messageCount}',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.clear_all),
                        onPressed: () {
                          // Clear messages functionality could be added here
                        },
                        tooltip: 'Clear',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: widget.botService.messageCount == 0
                      ? const Center(
                          child: Text(
                            'No messages yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: 1, // Placeholder - in real app would be messages list
                          itemBuilder: (context, index) {
                            return MessageBubble(
                              message: 'Bot is ready. Messages will appear here.',
                              isUser: false,
                              timestamp: DateTime.now(),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
