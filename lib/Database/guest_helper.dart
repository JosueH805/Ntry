import 'package:cloud_firestore/cloud_firestore.dart';

class GuestHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream the guests subcollection for [lockId] in real time.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> streamGuests(
    String lockId,
  ) {
    return _firestore
        .collection('passkeys')
        .where('lockId', isEqualTo: lockId)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();

          return snapshot.docs.where((doc) {
            final data = doc.data();

            final bool revoked = data['revoked'] ?? false;
            final Timestamp? expTimestamp = data['expTime'] as Timestamp?;
            final DateTime? expTime = expTimestamp?.toDate();

            return !revoked && expTime != null && now.isBefore(expTime);
          }).toList();
        });
  }

  Future<void> revokeGuestPass(String passId) async {
    await _firestore
      .collection('passkeys')
      .doc(passId)
      .update({
        'revoked': true,
      });
  }

  /// Create a new guest pass under the given lock.
  Future<void> createGuest({
    required String lockId,
    required String name,
    required String initTime,
    required String passkey,
    required int duration,
    required DateTime expiresAt

  }) async {
    try {
      await _firestore.collection('passkeys').doc().set({
        'name': name,
        'lockId': lockId,
        'passkey': passkey,
        'initTime': FieldValue.serverTimestamp(),
        'expTime': Timestamp.fromDate(expiresAt),
        'revoked': false,
        'duration': duration,
        'expiresAt': Timestamp.fromDate(expiresAt),
      });
    } catch (e) {
      // print("Error creating guest: $e");
    }
  }

  /// Delete a specific guest document.
  Future<void> deleteGuest(String lockId, String guestId) => _firestore
      .collection('locks')
      .doc(lockId)
      .collection('guests')
      .doc(guestId)
      .delete();
}
