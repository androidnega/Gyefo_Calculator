import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class MessageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send message to a specific worker
  static Future<void> sendMessage({
    required String receiverId,
    required String message,
    required String senderName,
  }) async {
    try {
      final senderId = _auth.currentUser?.uid;
      if (senderId == null) throw Exception('User not authenticated');

      final messageData = {
        'senderId': senderId,
        'senderName': senderName,
        'receiverId': receiverId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'archived': false,
      };

      // Store message in receiver's messages collection
      await _firestore
          .collection('users')
          .doc(receiverId)
          .collection('messages')
          .add(messageData);

      // Store message in sender's sent messages collection
      messageData['receiverId'] = receiverId;
      await _firestore
          .collection('users')
          .doc(senderId)
          .collection('sentMessages')
          .add(messageData);

      // Send push notification
      await _sendPushNotification(receiverId, senderName, message);
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Send bulk message to multiple workers
  static Future<void> sendBulkMessage({
    required List<String> receiverIds,
    required String message,
    required String senderName,
  }) async {
    try {
      final senderId = _auth.currentUser?.uid;
      if (senderId == null) throw Exception('User not authenticated');

      final batch = _firestore.batch();

      for (String receiverId in receiverIds) {
        final messageData = {
          'senderId': senderId,
          'senderName': senderName,
          'receiverId': receiverId,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'archived': false,
        };

        // Add to receiver's messages
        final receiverMessageRef = _firestore
            .collection('users')
            .doc(receiverId)
            .collection('messages')
            .doc();
        batch.set(receiverMessageRef, messageData);

        // Add to sender's sent messages
        final senderMessageRef = _firestore
            .collection('users')
            .doc(senderId)
            .collection('sentMessages')
            .doc();
        batch.set(senderMessageRef, messageData);
      }

      await batch.commit();

      // Send push notifications
      for (String receiverId in receiverIds) {
        await _sendPushNotification(receiverId, senderName, message);
      }
    } catch (e) {
      throw Exception('Failed to send bulk message: $e');
    }
  }

  // Mark message as read
  static Future<void> markAsRead(String messageId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('messages')
          .doc(messageId)
          .update({'read': true});
    } catch (e) {
      throw Exception('Failed to mark message as read: $e');
    }
  }

  // Archive message
  static Future<void> archiveMessage(String messageId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('messages')
          .doc(messageId)
          .update({'archived': true});
    } catch (e) {
      throw Exception('Failed to archive message: $e');
    }
  }

  // Soft delete message
  static Future<void> deleteMessage(String messageId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('messages')
          .doc(messageId)
          .update({'deleted': true});
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  // Get messages for current user
  static Stream<QuerySnapshot> getMessages() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('messages')
        .where('deleted', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get sent messages for managers
  static Stream<QuerySnapshot> getSentMessages() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('sentMessages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get all messages for admin (profile log)
  static Stream<QuerySnapshot> getAllUserMessages(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Send push notification
  static Future<void> _sendPushNotification(
      String receiverId, String senderName, String message) async {
    try {
      // Get receiver's FCM token from user document
      final userDoc = await _firestore.collection('users').doc(receiverId).get();
      final fcmToken = userDoc.data()?['fcmToken'];      if (fcmToken != null) {
        // In a real implementation, you would use Firebase Cloud Functions
        // to send the notification. For now, we'll skip this part.
        // The notification logic would be implemented server-side.
        debugPrint('Would send notification to token: $fcmToken');
        debugPrint('From: $senderName, Message: $message');
      }
    } catch (e) {
      debugPrint('Failed to send push notification: $e');
    }
  }

  // Get unread message count
  static Stream<int> getUnreadMessageCount() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(0);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('messages')
        .where('read', isEqualTo: false)
        .where('deleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
