import 'dart:typed_data';

import '../models/models.dart';
import 'firestore_facade.dart';

abstract final class ChatService {
  static Future<String> getOrCreateRoom(String otherUserId) =>
      FS.getOrCreateRoom(otherUserId);
  static Future<void> sendMessage(
          {required String roomId,
          required String senderName,
          required String text,
          String? mediaUrl,
          String? replyToText,
          String? replyToSender}) =>
      FS.sendMessage(
          roomId: roomId,
          senderName: senderName,
          text: text,
          mediaUrl: mediaUrl,
          replyToText: replyToText,
          replyToSender: replyToSender);
  static Stream<List<MessageModel>> messagesStream(String roomId) =>
      FS.messagesStream(roomId);
  static Stream<List<ChatRoomPreview>> chatRoomsStream() => FS.chatRoomsStream();
  static Future<void> markMessagesRead(String roomId) =>
      FS.markMessagesRead(roomId);
  static Future<String?> uploadChatMedia(
          Uint8List bytes, String fileName, String roomId) =>
      FS.uploadChatMedia(bytes, fileName, roomId);
}
