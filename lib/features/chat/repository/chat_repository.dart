import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:whatsapp_ui/common/enums/message_enum.dart';
import 'package:whatsapp_ui/common/providers/message_reply_provider.dart';
import 'package:whatsapp_ui/common/repositories/common_firebase_storage_repository.dart';
import 'package:whatsapp_ui/common/utils/utils.dart';
import 'package:whatsapp_ui/models/message.dart';
import 'package:whatsapp_ui/models/user_model.dart';
import '../../../models/chat_contact.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository(
    fireStore: FirebaseFirestore.instance, auth: FirebaseAuth.instance));

class ChatRepository {
  final FirebaseFirestore fireStore;
  final FirebaseAuth auth;

  ChatRepository({required this.fireStore, required this.auth});

  Stream<List<ChatContact>> getChatContacts() {
    return fireStore
        .collection('users')
        .doc(auth.currentUser!.uid)
        .collection('chats')
        .snapshots()
        .asyncMap((event) async {
      List<ChatContact> contacts = [];
      for (var document in event.docs) {
        var chatContact = ChatContact.fromMap(document.data());
        var userData = await fireStore
            .collection('users')
            .doc(chatContact.contactId)
            .get();
        var user = UserModel.fromMap(userData.data()!);

        contacts.add(
          ChatContact(
            name: user.name,
            profilePic: user.profilePic,
            contactId: chatContact.contactId,
            timeSent: chatContact.timeSent,
            lastMessage: chatContact.lastMessage,
          ),
        );
      }
      return contacts;
    });
  }

  Stream<List<Message>> getChatStream(String receiverUserId) {
    return fireStore
        .collection('users')
        .doc(auth.currentUser!.uid)
        .collection('chats')
        .doc(receiverUserId)
        .collection('messages')
        .orderBy('timeSent')
        .snapshots()
        .map((event) {
      List<Message> messages = [];
      for (var document in event.docs) {
        messages.add(Message.fromMap(document.data()));
      }
      return messages;
    });
  }

  void _saveDataToContactsSubCollection(
      UserModel senderUserData,
      UserModel receiverUserData,
      String text,
      DateTime timeSent,
      String receiverUserId) async {
    var senderChatContact = ChatContact(
      name: receiverUserData.name,
      profilePic: receiverUserData.profilePic,
      contactId: receiverUserData.uid,
      timeSent: timeSent,
      lastMessage: text,
    );

    await fireStore
        .collection('users')
        .doc(auth.currentUser!.uid)
        .collection('chats')
        .doc(receiverUserId)
        .set(senderChatContact.toMap());

    var receiverChatContact = ChatContact(
      name: senderUserData.name,
      profilePic: senderUserData.profilePic,
      contactId: senderUserData.uid,
      timeSent: timeSent,
      lastMessage: text,
    );

    await fireStore
        .collection('users')
        .doc(receiverUserId)
        .collection('chats')
        .doc(auth.currentUser!.uid)
        .set(receiverChatContact.toMap());
  }

  void _saveMessageToMessageCollection({
    required String receiverUserId,
    required String text,
    required DateTime timeSent,
    required String messageId,
    required String username,
    required MessageEnum messageType,
    required MessageReply? messageReply,
    required String senderUsername,
    required String receiverUsername,
  }) async {
    final message = Message(
        senderId: auth.currentUser!.uid,
        recieverid: receiverUserId,
        text: text,
        type: messageType,
        timeSent: timeSent,
        messageId: messageId,
        isSeen: false,
        repliedMessage: messageReply == null ? '' : messageReply.message,
        repliedTo: messageReply == null
            ? ''
            : messageReply.isMe
                ? senderUsername
                : receiverUsername,
        repliedMessageType:
            messageReply == null ? MessageEnum.text : messageReply.messageEnum);

    await fireStore
        .collection('users')
        .doc(auth.currentUser!.uid)
        .collection('chats')
        .doc(receiverUserId)
        .collection('messages')
        .doc(messageId)
        .set(message.toMap());

    await fireStore
        .collection('users')
        .doc(receiverUserId)
        .collection('chats')
        .doc(auth.currentUser!.uid)
        .collection('messages')
        .doc(messageId)
        .set(message.toMap());
  }

  void sendTextMessage({
    required BuildContext context,
    required String text,
    required String receiverUserId,
    required UserModel senderUser,
    required MessageReply? messageReply,
  }) async {
    try {
      var timeSent = DateTime.now();
      UserModel receiverUserData;
      var userDataMap =
          await fireStore.collection('users').doc(receiverUserId).get();
      receiverUserData = UserModel.fromMap(userDataMap.data()!);

      var messageId = const Uuid().v1();

      _saveDataToContactsSubCollection(
          senderUser, receiverUserData, text, timeSent, receiverUserId);

      _saveMessageToMessageCollection(
        receiverUserId: receiverUserId,
        text: text,
        timeSent: timeSent,
        messageType: MessageEnum.text,
        messageId: messageId,
        receiverUsername: receiverUserData.name,
        username: senderUser.name,
        senderUsername: senderUser.name,
        messageReply: messageReply,
      );
    } catch (e) {
      showSnackBar(context: context, content: e.toString());
    }
  }

  void sendFileMessage(
      {required BuildContext context,
      required File file,
      required String receiverUserId,
      required UserModel senderUserData,
      required ProviderRef ref,
      required MessageEnum messageEnum,
      required MessageReply? messageReply}) async {
    try {
      var timeSent = DateTime.now();
      var messageId = const Uuid().v1();
      String imageUrl = await ref
          .read(commonFirebaseStorageRepositoryProvider)
          .storeFileToFirebase(
              'chat/${messageEnum.type}/${senderUserData.uid}/$receiverUserId/$messageId',
              file);

      UserModel receiverUserData;
      var userDataMap =
          await fireStore.collection('users').doc(receiverUserId).get();
      receiverUserData = UserModel.fromMap(userDataMap.data()!);

      String contactMsg;
      switch (messageEnum) {
        case MessageEnum.image:
          contactMsg = '📷 Photo';
          break;
        case MessageEnum.video:
          contactMsg = '📷 Video';
          break;
        case MessageEnum.audio:
          contactMsg = '🎵 Audio';
          break;
        case MessageEnum.gif:
          contactMsg = 'GIF';
          break;
        default:
          contactMsg = 'GIF';
      }
      _saveDataToContactsSubCollection(senderUserData, receiverUserData,
          contactMsg, timeSent, receiverUserId);
      _saveMessageToMessageCollection(
          receiverUserId: receiverUserId,
          text: imageUrl,
          timeSent: timeSent,
          messageId: messageId,
          username: senderUserData.name,
          receiverUsername: receiverUserData.name,
          senderUsername: senderUserData.name,
          messageReply: messageReply,
          messageType: messageEnum);
    } catch (e) {
      showSnackBar(context: context, content: e.toString());
    }
  }

  void sendGIFMessage({
    required BuildContext context,
    required String gifUrl,
    required String receiverUserId,
    required UserModel senderUser,
    required MessageReply? messageReply,
  }) async {
    try {
      var timeSent = DateTime.now();
      UserModel receiverUserData;
      var userDataMap =
          await fireStore.collection('users').doc(receiverUserId).get();
      receiverUserData = UserModel.fromMap(userDataMap.data()!);

      var messageId = const Uuid().v1();

      _saveDataToContactsSubCollection(
          senderUser, receiverUserData, 'GIF', timeSent, receiverUserId);

      _saveMessageToMessageCollection(
          receiverUserId: receiverUserId,
          text: gifUrl,
          timeSent: timeSent,
          messageType: MessageEnum.gif,
          messageId: messageId,
          receiverUsername: receiverUserData.name,
          username: senderUser.name,
          messageReply: messageReply,
          senderUsername: senderUser.name);
    } catch (e) {
      showSnackBar(context: context, content: e.toString());
    }
  }

  void setChatMessageSeen(
      BuildContext context, String receiverUserId, String messageId) async {
    try {
      await fireStore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('chats')
          .doc(receiverUserId)
          .collection('messages')
          .doc(messageId)
          .set({'isSeen': true});

      await fireStore
          .collection('users')
          .doc(receiverUserId)
          .collection('chats')
          .doc(auth.currentUser!.uid)
          .collection('messages')
          .doc(messageId)
          .set({'isSeen': true});
    } catch (e) {
      showSnackBar(context: context, content: e.toString());
    }
  }
}
