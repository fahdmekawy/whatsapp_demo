import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:whatsapp_ui/common/enums/message_enum.dart';
import 'package:whatsapp_ui/common/providers/message_reply_provider.dart';
import 'package:whatsapp_ui/common/widgets/loader.dart';
import 'package:whatsapp_ui/features/chat/controller/chat_controller.dart';
import 'package:whatsapp_ui/features/chat/widgets/my_message_card.dart';
import 'package:whatsapp_ui/features/chat/widgets/sender_message_card.dart';
import 'package:whatsapp_ui/models/message.dart';

class ChatList extends ConsumerStatefulWidget {
  final String receiverUserId;

  const ChatList(this.receiverUserId, {Key? key}) : super(key: key);

  @override
  ConsumerState<ChatList> createState() => _ChatListState();
}

class _ChatListState extends ConsumerState<ChatList> {
  final ScrollController _messageController = ScrollController();

  @override
  void dispose() {
    super.dispose();
    _messageController.dispose();
  }

  void onMessageSwipe(String message, bool isMe, MessageEnum messageEnum) {
    ref
        .read(messageReplyProvider.notifier)
        .update((state) => MessageReply(message, isMe, messageEnum));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Message>>(
        stream:
            ref.read(chatControllerProvider).chatStream(widget.receiverUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Loader();
          }

          SchedulerBinding.instance.addPostFrameCallback((_) {
            _messageController
                .jumpTo(_messageController.position.maxScrollExtent);
          });

          return ListView.builder(
              itemCount: snapshot.data!.length,
              controller: _messageController,
              itemBuilder: (context, index) {
                final messageData = snapshot.data![index];
                var timeSent = DateFormat.Hm().format(messageData.timeSent);
                if (messageData.isSeen &&
                    messageData.recieverid ==
                        FirebaseAuth.instance.currentUser!.uid) {
                  ref.read(chatControllerProvider).setChatMessageSeen(
                      context, widget.receiverUserId, messageData.messageId);
                }
                if (messageData.senderId ==
                    FirebaseAuth.instance.currentUser!.uid) {
                  return MyMessageCard(
                    message: messageData.text,
                    date: timeSent,
                    messageEnum: messageData.type,
                    repliedText: messageData.repliedMessage,
                    username: messageData.repliedTo,
                    repliedMessageType: messageData.repliedMessageType,
                    onLeftSwipe: () => onMessageSwipe(
                      messageData.text,
                      true,
                      messageData.type,
                    ),
                    isSeen: messageData.isSeen,
                  );
                }
                return SenderMessageCard(
                  message: messageData.text,
                  date: timeSent,
                  messageEnum: messageData.type,
                  repliedText: messageData.repliedMessage,
                  username: messageData.repliedTo,
                  repliedMessageType: messageData.repliedMessageType,
                  onRightSwipe: () =>
                      onMessageSwipe(messageData.text, false, messageData.type),
                );
              });
        });
  }
}
